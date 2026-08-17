import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { ClinicalReport } from '../entities/clinical_report.entity';
import { ClinicalMarker } from '../entities/clinical_marker.entity';
import {
  ClinicalMarkerInputDto,
  CreateClinicalReportDto,
} from '../dto/create-clinical-report.dto';
import { CreateClinicalMarkersDto } from '../dto/create-clinical-markers.dto';

/// Número de informes que se le pasan a la IA como contexto. Más que esto no
/// aporta (una analítica de hace 3 años no cambia la rutina de hoy) y sí gasta
/// presupuesto de tokens, que en Groq es el cuello de botella real.
const INFORMES_EN_CONTEXTO = 3;

@Injectable()
export class ClinicalReportService {
  constructor(
    @InjectRepository(ClinicalReport)
    private readonly reportRepository: Repository<ClinicalReport>,
    @InjectRepository(ClinicalMarker)
    private readonly markerRepository: Repository<ClinicalMarker>,
    private readonly dataSource: DataSource,
  ) {}

  private toDate(value?: string | null): Date | null {
    if (!value) return null;
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  private buildMarker(
    userId: string,
    dto: ClinicalMarkerInputDto,
    fechaPorDefecto: Date,
    origen: string,
    reportId: string | null,
  ): ClinicalMarker {
    return this.markerRepository.create({
      userId,
      reportId,
      fecha: this.toDate(dto.fecha) ?? fechaPorDefecto,
      codigo: dto.codigo,
      nombre: dto.nombre,
      valor: dto.valor,
      unidad: dto.unidad ?? null,
      rango_min: dto.rango_min ?? null,
      rango_max: dto.rango_max ?? null,
      estado: dto.estado ?? 'desconocido',
      relevancia_fisico: dto.relevancia_fisico ?? null,
      origen,
    });
  }

  /// Informe + sus marcadores en una transacción: un informe cuyos marcadores
  /// fallaron a medias dejaría un resumen hablando de valores que no están en
  /// la tabla de tendencias.
  async createWithMarkers(dto: CreateClinicalReportDto) {
    const fechaInforme = this.toDate(dto.fecha_informe);
    const fechaMarcadores = fechaInforme ?? new Date();

    return this.dataSource.transaction(async (manager) => {
      const report = manager.create(ClinicalReport, {
        userId: dto.userId,
        fecha_informe: fechaInforme,
        tipo_documento: dto.tipo_documento ?? 'analitica',
        nombre_archivo: dto.nombre_archivo ?? null,
        resumen_ia: dto.resumen_ia,
        hallazgos_clave: dto.hallazgos_clave ?? null,
        implicaciones_entrenamiento: dto.implicaciones_entrenamiento ?? null,
        implicaciones_nutricion: dto.implicaciones_nutricion ?? null,
        banderas_rojas: dto.banderas_rojas ?? null,
        fuentes_consultadas: dto.fuentes_consultadas ?? null,
        confianza_extraccion: dto.confianza_extraccion ?? null,
      });
      const saved = await manager.save(report);

      const marcadores = (dto.marcadores ?? []).map((m) =>
        this.buildMarker(dto.userId, m, fechaMarcadores, 'documento_ia', saved.id),
      );
      if (marcadores.length) {
        await manager.save(ClinicalMarker, marcadores);
      }

      return { ...saved, marcadores };
    });
  }

  /// Alta manual: sin informe, pero con la misma forma de datos, para que la
  /// serie temporal de un marcador mezcle indistintamente lo tecleado a mano y
  /// lo extraído de un PDF.
  async createManualMarkers(dto: CreateClinicalMarkersDto) {
    const fecha = this.toDate(dto.fecha) ?? new Date();
    const entities = dto.marcadores.map((m) =>
      this.buildMarker(dto.userId, m, fecha, 'manual', null),
    );
    return this.markerRepository.save(entities);
  }

  async findReportsByUser(userId: string) {
    return this.reportRepository.find({
      where: { userId },
      order: { fecha_subida: 'DESC' },
    });
  }

  async findReport(id: string, userId: string) {
    const report = await this.reportRepository.findOne({
      where: { id },
      relations: { marcadores: true },
    });
    if (!report) {
      throw new NotFoundException('Informe clínico no encontrado.');
    }
    if (report.userId !== userId) {
      throw new ForbiddenException('Este informe clínico no pertenece al usuario.');
    }
    return report;
  }

  async removeReport(id: string, userId: string) {
    const report = await this.findReport(id, userId);
    await this.reportRepository.remove(report);
    return { message: 'Informe clínico eliminado correctamente.' };
  }

  async findMarkersByUser(userId: string, codigo?: string) {
    return this.markerRepository.find({
      where: codigo ? { userId, codigo } : { userId },
      order: { fecha: 'DESC' },
    });
  }

  /// Último valor de cada biomarcador. `DISTINCT ON` de Postgres en vez de
  /// traer el historial entero y filtrarlo en Node: la tabla crece una fila por
  /// marcador y analítica, y esto se llama en cada turno de chat.
  async findLatestMarkers(userId: string): Promise<ClinicalMarker[]> {
    return this.markerRepository
      .createQueryBuilder('m')
      .distinctOn(['m.codigo'])
      .where('m.user_id = :userId', { userId })
      .orderBy('m.codigo', 'ASC')
      .addOrderBy('m.fecha', 'DESC')
      .getMany();
  }

  async removeMarker(id: string, userId: string) {
    const marker = await this.markerRepository.findOne({ where: { id } });
    if (!marker) {
      throw new NotFoundException('Biomarcador no encontrado.');
    }
    if (marker.userId !== userId) {
      throw new ForbiddenException('Este biomarcador no pertenece al usuario.');
    }
    await this.markerRepository.remove(marker);
    return { message: 'Biomarcador eliminado correctamente.' };
  }

  /// Vista compacta para el prompt de la IA: solo lo fuera de rango, más el
  /// resumen de los últimos informes. Ver INFORMES_EN_CONTEXTO.
  async buildAiSummary(userId: string) {
    const [informes, marcadores] = await Promise.all([
      this.reportRepository.find({
        where: { userId },
        order: { fecha_subida: 'DESC' },
        take: INFORMES_EN_CONTEXTO,
      }),
      this.findLatestMarkers(userId),
    ]);

    const fueraDeRango = marcadores.filter(
      (m) => m.estado === 'alto' || m.estado === 'bajo',
    );

    return {
      tiene_datos: informes.length > 0 || marcadores.length > 0,
      num_marcadores: marcadores.length,
      fecha_ultimo_informe: informes[0]?.fecha_subida ?? null,
      informes: informes.map((r) => ({
        fecha: r.fecha_informe ?? r.fecha_subida,
        tipo: r.tipo_documento,
        resumen: r.resumen_ia,
        hallazgos_clave: r.hallazgos_clave ?? [],
        implicaciones_entrenamiento: r.implicaciones_entrenamiento,
        implicaciones_nutricion: r.implicaciones_nutricion,
        banderas_rojas: r.banderas_rojas ?? [],
      })),
      marcadores_fuera_de_rango: fueraDeRango.map((m) => ({
        codigo: m.codigo,
        nombre: m.nombre,
        valor: Number(m.valor),
        unidad: m.unidad,
        estado: m.estado,
        rango: [
          m.rango_min !== null ? Number(m.rango_min) : null,
          m.rango_max !== null ? Number(m.rango_max) : null,
        ],
        relevancia_fisico: m.relevancia_fisico,
        fecha: m.fecha,
      })),
      marcadores_en_rango: marcadores
        .filter((m) => m.estado === 'normal')
        .map((m) => m.codigo),
    };
  }
}
