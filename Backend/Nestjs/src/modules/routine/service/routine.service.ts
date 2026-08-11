import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Routine } from '../entities/routine.entity';
import { RoutineDay } from '../entities/routine_day.entity';
import { Exercise } from '../entities/exercise.entity';
import { CreateRoutineDto } from '../dto/create-routine.dto';
import { UpdateRoutineDto } from '../dto/update-routine.dto';
import { CreateRoutineFromAiDto } from '../dto/create-routine-from-ai.dto';

@Injectable()
export class RoutineService {
  constructor(
    @InjectRepository(Routine)
    private readonly routineRepository: Repository<Routine>,
    @InjectRepository(RoutineDay)
    private readonly dayRepository: Repository<RoutineDay>,
    @InjectRepository(Exercise)
    private readonly exerciseRepository: Repository<Exercise>,
  ) {}

  async findAll(userId?: string) {
    const whereCondition = userId ? { userId } : {};
    return this.routineRepository.find({
      where: whereCondition,
      relations: ['days', 'days.exercises'],
      order: { updated_at: 'DESC' },
    });
  }

  async create(dto: CreateRoutineDto) {
    const routine = this.routineRepository.create({
      userId: dto.userId, // Esperamos que se pase en el DTO temporalmente o manualmente
      name: dto.name,
      activity_type: dto.activity_type,
      description: dto.description,
      activa: true,
      days: dto.days.map((day) =>
        this.dayRepository.create({
          day_of_week: day.day_of_week,
          focus: day.focus,
          exercises:
            day.exercises?.map((ex) =>
              this.exerciseRepository.create(ex),
            ) ?? [],
        }),
      ),
    });

    if (dto.userId) {
      await this.routineRepository.update(
        { userId: dto.userId },
        { activa: false },
      );
    }

    return this.routineRepository.save(routine);
  }

  async createFromAiPayload(dto: CreateRoutineFromAiDto) {
    if (dto.userId) {
      await this.routineRepository.update(
        { userId: dto.userId },
        { activa: false },
      );
    }

    const days = (dto.dias_entrenamiento ?? []).map((day) =>
      this.dayRepository.create({
        day_of_week: `Día ${day.numero_dia}`,
        focus: `${day.nombre_dia} — ${day.grupo_muscular}`,
        exercises: (day.ejercicios ?? []).map((ex) =>
          this.exerciseRepository.create({
            name: ex.nombre,
            sets: ex.series,
            reps: String(ex.repeticiones),
            rest_seconds: ex.descanso_segundos,
            notes: ex.notas,
          }),
        ),
      }),
    );

    const routine = this.routineRepository.create({
      userId: dto.userId,
      name: dto.nombre_rutina,
      activity_type: dto.tipo_entrenamiento,
      description: dto.notas_adicionales,
      activa: true,
      days,
    });

    return this.routineRepository.save(routine);
  }

  async findOne(id: string) {
    const routine = await this.routineRepository.findOne({
      where: { id },
      relations: ['days', 'days.exercises'],
    });
    if (!routine) {
      throw new NotFoundException('Rutina no encontrada');
    }
    return routine;
  }

  async findOneForUser(id: string, userId: string) {
    const routine = await this.findOne(id);
    if (routine.userId !== userId) {
      throw new NotFoundException('Rutina no encontrada');
    }
    return routine;
  }

  async findActiveByUser(userId: string) {
    return this.routineRepository.findOne({
      where: { userId, activa: true },
      relations: ['days', 'days.exercises'],
    });
  }

  async setAsActive(id: string, userId: string) {
    const routine = await this.findOneForUser(id, userId);
    await this.routineRepository.update(
      { userId },
      { activa: false },
    );
    routine.activa = true;
    return this.routineRepository.save(routine);
  }

  async update(id: string, userId: string, dto: UpdateRoutineDto) {
    const routine = await this.findOneForUser(id, userId);

    if (dto.name !== undefined) {
      routine.name = dto.name;
    }
    if (dto.activity_type !== undefined) {
      routine.activity_type = dto.activity_type;
    }
    if (dto.description !== undefined) {
      routine.description = dto.description;
    }

    if (dto.days) {
      if (routine.days && routine.days.length > 0) {
        await this.dayRepository.remove(routine.days);
      }

      routine.days = dto.days.map((day) =>
        this.dayRepository.create({
          day_of_week: day.day_of_week,
          focus: day.focus,
          exercises:
            day.exercises?.map((ex) =>
              this.exerciseRepository.create(ex),
            ) ?? [],
        }),
      );
    }

    return this.routineRepository.save(routine);
  }

  async updateFromAiPayload(id: string, userId: string, dias_entrenamiento: any[]) {
    const routine = await this.findOneForUser(id, userId);

    if (routine.days && routine.days.length > 0) {
      await this.dayRepository.remove(routine.days);
    }

    routine.days = (dias_entrenamiento ?? []).map((day) =>
      this.dayRepository.create({
        day_of_week: `Día ${day.numero_dia}`,
        focus: `${day.nombre_dia} — ${day.grupo_muscular}`,
        exercises: (day.ejercicios ?? []).map((ex: any) =>
          this.exerciseRepository.create({
            name: ex.nombre,
            sets: ex.series,
            reps: String(ex.repeticiones),
            rest_seconds: ex.descanso_segundos,
            notes: ex.notas,
          }),
        ),
      }),
    );

    return this.routineRepository.save(routine);
  }

  async remove(id: string, userId: string) {
    const routine = await this.findOneForUser(id, userId);
    await this.routineRepository.remove(routine);
    return { message: 'Rutina eliminada correctamente' };
  }
}
