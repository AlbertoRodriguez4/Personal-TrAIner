import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TrainingSession } from '../entities/training_session.entity';
import { CreateTrainingSessionDto } from '../dto/create-training-session.dto';
import { UpdateTrainingSessionDto } from '../dto/update-training-session.dto';

@Injectable()
export class TrainingSessionService {
  constructor(
    @InjectRepository(TrainingSession)
    private readonly trainingSessionRepository: Repository<TrainingSession>,
  ) {}

  async create(dto: CreateTrainingSessionDto) {
    const entity = this.trainingSessionRepository.create({
      ...dto,
      fecha_programada: new Date(dto.fecha_programada),
      estado: dto.estado ?? 'pendiente',
    });
    return this.trainingSessionRepository.save(entity);
  }

  async findByUser(userId: string) {
    return this.trainingSessionRepository.find({
      where: { userId },
      order: { fecha_programada: 'DESC' },
    });
  }

  async findOne(id: string) {
    const trainingSession = await this.trainingSessionRepository.findOne({ where: { id } });
    if (!trainingSession) {
      throw new NotFoundException('Sesión de entrenamiento no encontrada.');
    }
    return trainingSession;
  }

  async markAsCompleted(id: string) {
    await this.findOne(id);
    await this.trainingSessionRepository.update(id, {
      estado: 'completado',
      fecha_finalizacion: new Date(),
    });
    return this.findOne(id);
  }

  async update(id: string, dto: UpdateTrainingSessionDto) {
    const trainingSession = await this.findOne(id);

    if (dto.userId !== undefined) {
      trainingSession.userId = dto.userId;
    }
    if (dto.fecha_programada !== undefined) {
      trainingSession.fecha_programada = new Date(dto.fecha_programada);
    }
    if (dto.tipo_entrenamiento !== undefined) {
      trainingSession.tipo_entrenamiento = dto.tipo_entrenamiento;
    }
    if (dto.ejercicios !== undefined) {
      trainingSession.ejercicios = dto.ejercicios;
    }
    if (dto.estado !== undefined) {
      trainingSession.estado = dto.estado;
    }

    return this.trainingSessionRepository.save(trainingSession);
  }

  async remove(id: string) {
    const trainingSession = await this.findOne(id);
    await this.trainingSessionRepository.remove(trainingSession);
    return { message: 'Sesión de entrenamiento eliminada correctamente.' };
  }
}
