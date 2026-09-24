import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PostureEvaluation } from '../entities/posture_evaluation.entity';
import { CreatePostureEvaluationDto } from '../dto/create-posture-evaluation.dto';
import { UpdatePostureEvaluationDto } from '../dto/update-posture-evaluation.dto';

@Injectable()
export class PostureEvaluationService {
  constructor(
    @InjectRepository(PostureEvaluation)
    private readonly postureEvaluationRepository: Repository<PostureEvaluation>,
  ) {}

  async create(dto: CreatePostureEvaluationDto) {
    const entity = this.postureEvaluationRepository.create({
      ...dto,
      fecha_evaluacion: new Date(dto.fecha_evaluacion),
      analisis_ia: this.normalizeAnalysis(dto.analisis_ia),
    });
    return this.postureEvaluationRepository.save(entity);
  }

  async findByUser(userId: string) {
    return this.postureEvaluationRepository.find({
      where: { userId },
      order: { fecha_evaluacion: 'DESC' },
    });
  }

  /// Filtra por dueño en la propia consulta: una evaluación de otro usuario
  /// responde igual que una que no existe.
  async findOne(id: string, userId: string) {
    const evaluation = await this.postureEvaluationRepository.findOne({
      where: { id, userId },
    });
    if (!evaluation) {
      throw new NotFoundException('Evaluación postural no encontrada.');
    }
    return evaluation;
  }

  async update(id: string, userId: string, dto: UpdatePostureEvaluationDto) {
    await this.findOne(id, userId);
    // `userId` fuera: la fila no cambia de dueño por editarla.
    const { userId: _dueno, ...cambios } = dto;
    await this.postureEvaluationRepository.update(id, {
      ...cambios,
      fecha_evaluacion: dto.fecha_evaluacion ? new Date(dto.fecha_evaluacion) : undefined,
      analisis_ia: dto.analisis_ia ? this.normalizeAnalysis(dto.analisis_ia) : undefined,
    });
    return this.findOne(id, userId);
  }

  async remove(id: string, userId: string) {
    const evaluation = await this.findOne(id, userId);
    await this.postureEvaluationRepository.remove(evaluation);
    return { message: 'Evaluación postural eliminada correctamente.' };
  }

  private normalizeAnalysis(analysis: string | Record<string, unknown> | undefined) {
    if (!analysis) {
      return '';
    }
    return typeof analysis === 'string' ? analysis : JSON.stringify(analysis);
  }
}
