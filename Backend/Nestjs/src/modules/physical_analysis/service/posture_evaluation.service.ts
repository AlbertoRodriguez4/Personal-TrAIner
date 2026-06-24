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

  async findOne(id: string) {
    const evaluation = await this.postureEvaluationRepository.findOne({ where: { id } });
    if (!evaluation) {
      throw new NotFoundException('Evaluación postural no encontrada.');
    }
    return evaluation;
  }

  async update(id: string, dto: UpdatePostureEvaluationDto) {
    await this.findOne(id);
    await this.postureEvaluationRepository.update(id, {
      ...dto,
      fecha_evaluacion: dto.fecha_evaluacion ? new Date(dto.fecha_evaluacion) : undefined,
      analisis_ia: dto.analisis_ia ? this.normalizeAnalysis(dto.analisis_ia) : undefined,
    });
    return this.findOne(id);
  }

  async remove(id: string) {
    const evaluation = await this.findOne(id);
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
