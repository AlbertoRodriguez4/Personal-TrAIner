import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { BodyAnalysisRecord } from '../entities/body_analysis_record.entity';
import { PhysiquePhoto } from '../entities/physique_photo.entity';
import { CreatePhysiqueAnalysisDto } from '../dto/create-physique-analysis.dto';

/// Cuántos análisis físicos entran en el contexto de la IA. Con 4 alcanza para
/// que el modelo vea la tendencia (¿mejoró el punto débil de hace 3 meses?) sin
/// inflar el prompt.
const ANALISIS_EN_CONTEXTO = 4;

@Injectable()
export class PhysiquePhotoService {
  constructor(
    @InjectRepository(BodyAnalysisRecord)
    private readonly recordRepository: Repository<BodyAnalysisRecord>,
    @InjectRepository(PhysiquePhoto)
    private readonly photoRepository: Repository<PhysiquePhoto>,
    private readonly dataSource: DataSource,
  ) {}

  /// Registro + fotos en una transacción. Las fotos son inútiles sin el
  /// registro que las interpreta, y el registro sin fotos deja el historial
  /// visual con huecos.
  async createWithPhotos(dto: CreatePhysiqueAnalysisDto) {
    const { fotos = [], fecha_analisis, ...campos } = dto;

    return this.dataSource.transaction(async (manager) => {
      const record = manager.create(BodyAnalysisRecord, {
        ...campos,
        fecha_analisis: fecha_analisis ? new Date(fecha_analisis) : new Date(),
        origen: dto.origen ?? 'seguimiento_fotos',
        num_fotos: fotos.length,
        angulos_fotos: dto.angulos_fotos ?? fotos.map((f) => f.angulo ?? 'otro'),
      });
      const saved = await manager.save(record);

      if (fotos.length) {
        const entities = fotos.map((f) =>
          manager.create(PhysiquePhoto, {
            userId: dto.userId,
            recordId: saved.id,
            angulo: f.angulo ?? 'otro',
            mime_type: f.mime_type ?? 'image/jpeg',
            imagen: Buffer.from(f.data, 'base64'),
          }),
        );
        await manager.save(PhysiquePhoto, entities);
      }

      return saved;
    });
  }

  /// Metadatos de las fotos, sin los bytes: la lista del historial solo necesita
  /// saber qué fotos hay para pintar las miniaturas bajo demanda.
  async findPhotoMetaByRecord(recordId: string, userId: string) {
    const record = await this.recordRepository.findOne({ where: { id: recordId } });
    if (!record) {
      throw new NotFoundException('Análisis físico no encontrado.');
    }
    if (record.userId !== userId) {
      throw new ForbiddenException('Este análisis físico no pertenece al usuario.');
    }
    return this.photoRepository.find({
      where: { recordId },
      select: { id: true, angulo: true, mime_type: true, created_at: true },
      order: { created_at: 'ASC' },
    });
  }

  async findPhotoBytes(photoId: string, userId: string) {
    const foto = await this.photoRepository.findOne({ where: { id: photoId } });
    if (!foto) {
      throw new NotFoundException('Foto no encontrada.');
    }
    if (foto.userId !== userId) {
      throw new ForbiddenException('Esta foto no pertenece al usuario.');
    }
    return foto;
  }

  /// Vista compacta para el prompt de la IA: el último análisis completo más la
  /// evolución de los puntos débiles. No manda las fotos, solo lo que se
  /// extrajo de ellas.
  async buildAiSummary(userId: string) {
    const historial = await this.recordRepository.find({
      where: { userId },
      order: { fecha_analisis: 'DESC' },
      take: ANALISIS_EN_CONTEXTO,
    });

    if (!historial.length) {
      return { tiene_datos: false, num_analisis: 0, ultimo: null, evolucion: [] };
    }

    const [ultimo, ...previos] = historial;
    const num = (v: unknown) => (v === null || v === undefined ? null : Number(v));

    return {
      tiene_datos: true,
      num_analisis: historial.length,
      ultimo: {
        fecha: ultimo.fecha_analisis,
        resumen: ultimo.analisis_general,
        peso_estimado_kg: num(ultimo.peso_estimado_kg),
        porcentaje_grasa_estimado: num(ultimo.porcentaje_grasa_estimado),
        masa_muscular_estimada_kg: num(ultimo.masa_muscular_estimada_kg),
        somatotipo: ultimo.somatotipo_estimado,
        nivel_fitness: ultimo.nivel_fitness_estimado,
        grupos_retrasados: ultimo.grupos_musculares_retrasados ?? [],
        grupos_dominantes: ultimo.grupos_musculares_dominantes ?? [],
        puntos_fuertes: ultimo.puntos_fuertes_fisicos ?? [],
        areas_mejora: ultimo.areas_mejora_fisicas ?? [],
        postura: ultimo.postura_observaciones,
        prioridad_entrenamiento: ultimo.prioridad_entrenamiento,
      },
      evolucion: previos.map((r) => ({
        fecha: r.fecha_analisis,
        porcentaje_grasa_estimado: num(r.porcentaje_grasa_estimado),
        grupos_retrasados: r.grupos_musculares_retrasados ?? [],
      })),
    };
  }
}
