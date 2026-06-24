import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThanOrEqual, LessThan } from 'typeorm';
import { BodyAnalysisRecord } from '../entities/body_analysis_record.entity';
import { CreateBodyAnalysisRecordDto } from '../dto/create-body-analysis-record.dto';
import { UpdateBodyAnalysisRecordDto } from '../dto/update-body-analysis-record.dto';

@Injectable()
export class BodyAnalysisService {
  constructor(
    @InjectRepository(BodyAnalysisRecord)
    private readonly bodyAnalysisRepository: Repository<BodyAnalysisRecord>,
  ) {}

  async create(dto: CreateBodyAnalysisRecordDto) {
    const entity = this.bodyAnalysisRepository.create({
      ...dto,
      fecha_analisis: dto.fecha_analisis ? new Date(dto.fecha_analisis) : new Date(),
    });
    return this.bodyAnalysisRepository.save(entity);
  }

  async findByUser(userId: string) {
    return this.bodyAnalysisRepository.find({
      where: { userId },
      order: { fecha_analisis: 'DESC' },
    });
  }

  async findLatestByUser(userId: string) {
    return this.bodyAnalysisRepository.findOne({
      where: { userId },
      order: { fecha_analisis: 'DESC' },
    });
  }

  async shouldCreateNewRecord(userId: string): Promise<boolean> {
    const latest = await this.findLatestByUser(userId);
    if (!latest) {
      return true;
    }

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    return latest.fecha_analisis < thirtyDaysAgo;
  }

  async findHistoryForAiContext(userId: string, limit: number = 6) {
    return this.bodyAnalysisRepository.find({
      where: { userId },
      order: { fecha_analisis: 'DESC' },
      take: limit,
    });
  }

  async findOne(id: string) {
    const record = await this.bodyAnalysisRepository.findOne({ where: { id } });
    if (!record) {
      throw new NotFoundException('Registro de análisis físico no encontrado.');
    }
    return record;
  }

  async update(id: string, dto: UpdateBodyAnalysisRecordDto) {
    const record = await this.findOne(id);

    if (dto.userId !== undefined) {
      record.userId = dto.userId;
    }
    if (dto.fecha_analisis !== undefined) {
      record.fecha_analisis = new Date(dto.fecha_analisis);
    }
    if (dto.analisis_general !== undefined) {
      record.analisis_general = dto.analisis_general;
    }
    if (dto.peso_estimado_kg !== undefined) {
      record.peso_estimado_kg = dto.peso_estimado_kg;
    }
    if (dto.porcentaje_grasa_estimado !== undefined) {
      record.porcentaje_grasa_estimado = dto.porcentaje_grasa_estimado;
    }
    if (dto.masa_muscular_estimada_kg !== undefined) {
      record.masa_muscular_estimada_kg = dto.masa_muscular_estimada_kg;
    }
    if (dto.somatotipo_estimado !== undefined) {
      record.somatotipo_estimado = dto.somatotipo_estimado;
    }
    if (dto.nivel_fitness_estimado !== undefined) {
      record.nivel_fitness_estimado = dto.nivel_fitness_estimado;
    }
    if (dto.puntos_fuertes_fisicos !== undefined) {
      record.puntos_fuertes_fisicos = dto.puntos_fuertes_fisicos;
    }
    if (dto.areas_mejora_fisicas !== undefined) {
      record.areas_mejora_fisicas = dto.areas_mejora_fisicas;
    }
    if (dto.recomendaciones !== undefined) {
      record.recomendaciones = dto.recomendaciones;
    }
    if (dto.metricas_adicionales !== undefined) {
      record.metricas_adicionales = dto.metricas_adicionales;
    }
    if (dto.notas_adicionales !== undefined) {
      record.notas_adicionales = dto.notas_adicionales;
    }
    if (dto.comparacion_progreso !== undefined) {
      record.comparacion_progreso = dto.comparacion_progreso;
    }

    return this.bodyAnalysisRepository.save(record);
  }

  async remove(id: string) {
    const record = await this.findOne(id);
    await this.bodyAnalysisRepository.remove(record);
    return { message: 'Registro de análisis físico eliminado correctamente.' };
  }
}
