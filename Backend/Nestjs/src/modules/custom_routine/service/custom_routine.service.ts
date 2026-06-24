import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CustomRoutine } from '../entities/custom_routine.entity';
import { CreateCustomRoutineDto } from '../dto/create-custom-routine.dto';
import { UpdateCustomRoutineDto } from '../dto/update-custom-routine.dto';

@Injectable()
export class CustomRoutineService {
  constructor(
    @InjectRepository(CustomRoutine)
    private readonly customRoutineRepository: Repository<CustomRoutine>,
  ) {}

  async create(dto: CreateCustomRoutineDto) {
    const entity = this.customRoutineRepository.create({
      ...dto,
      activa: dto.activa ?? true,
    });
    return this.customRoutineRepository.save(entity);
  }

  async findByUser(userId: string) {
    return this.customRoutineRepository.find({
      where: { userId },
      order: { fecha_creacion: 'DESC' },
    });
  }

  async findActiveByUser(userId: string) {
    return this.customRoutineRepository.findOne({
      where: { userId, activa: true },
    });
  }

  async findOne(id: string) {
    const routine = await this.customRoutineRepository.findOne({ where: { id } });
    if (!routine) {
      throw new NotFoundException('Rutina personalizada no encontrada.');
    }
    return routine;
  }

  async update(id: string, dto: UpdateCustomRoutineDto) {
    const routine = await this.findOne(id);

    if (dto.userId !== undefined) {
      routine.userId = dto.userId;
    }
    if (dto.nombre_rutina !== undefined) {
      routine.nombre_rutina = dto.nombre_rutina;
    }
    if (dto.tipo_entrenamiento !== undefined) {
      routine.tipo_entrenamiento = dto.tipo_entrenamiento;
    }
    if (dto.numero_dias !== undefined) {
      routine.numero_dias = dto.numero_dias;
    }
    if (dto.dias_entrenamiento !== undefined) {
      routine.dias_entrenamiento = dto.dias_entrenamiento as any;
    }
    if (dto.notas_adicionales !== undefined) {
      routine.notas_adicionales = dto.notas_adicionales;
    }
    if (dto.activa !== undefined) {
      routine.activa = dto.activa;
    }

    return this.customRoutineRepository.save(routine);
  }

  async setAsActive(id: string, userId: string) {
    await this.customRoutineRepository.update(
      { userId },
      { activa: false },
    );
    const routine = await this.findOne(id);
    routine.activa = true;
    return this.customRoutineRepository.save(routine);
  }

  async remove(id: string) {
    const routine = await this.findOne(id);
    await this.customRoutineRepository.remove(routine);
    return { message: 'Rutina personalizada eliminada correctamente.' };
  }
}
