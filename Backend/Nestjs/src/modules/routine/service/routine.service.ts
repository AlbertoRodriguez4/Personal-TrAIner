import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Routine } from '../entities/routine.entity';
import { RoutineDay } from '../entities/routine_day.entity';
import { Exercise } from '../entities/exercise.entity';
import { CreateRoutineDto } from '../dto/create-routine.dto';
import { UpdateRoutineDto } from '../dto/update-routine.dto';

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

  async findAll() {
    return this.routineRepository.find({
      relations: ['days', 'days.exercises'],
      order: { updated_at: 'DESC' },
    });
  }

  async create(dto: CreateRoutineDto) {
    const routine = this.routineRepository.create({
      name: dto.name,
      activity_type: dto.activity_type,
      description: dto.description,
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

  async update(id: string, dto: UpdateRoutineDto) {
    const routine = await this.findOne(id);

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

  async remove(id: string) {
    const routine = await this.findOne(id);
    await this.routineRepository.remove(routine);
    return { message: 'Rutina eliminada correctamente' };
  }
}
