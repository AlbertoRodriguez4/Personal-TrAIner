import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, LessThanOrEqual, MoreThanOrEqual, Repository } from 'typeorm';
import { NutritionLog } from '../entities/nutrition_log.entity';
import { CreateNutritionLogDto } from '../dto/create-nutrition-log.dto';
import { UpdateNutritionLogDto } from '../dto/update-nutrition-log.dto';

@Injectable()
export class NutritionLogService {
  constructor(
    @InjectRepository(NutritionLog)
    private readonly nutritionLogRepository: Repository<NutritionLog>,
  ) {}

  async create(dto: CreateNutritionLogDto) {
    const entity = this.nutritionLogRepository.create({
      ...dto,
      fecha_registro: new Date(dto.fecha_registro),
    });
    return this.nutritionLogRepository.save(entity);
  }

  async findByUser(userId: string, startDate?: string, endDate?: string) {
    if (startDate && endDate) {
      return this.nutritionLogRepository.find({
        where: {
          userId,
          fecha_registro: Between(new Date(startDate), new Date(endDate)),
        },
        order: { fecha_registro: 'DESC' },
      });
    }

    if (startDate) {
      return this.nutritionLogRepository.find({
        where: {
          userId,
          fecha_registro: MoreThanOrEqual(new Date(startDate)),
        },
        order: { fecha_registro: 'DESC' },
      });
    }

    if (endDate) {
      return this.nutritionLogRepository.find({
        where: {
          userId,
          fecha_registro: LessThanOrEqual(new Date(endDate)),
        },
        order: { fecha_registro: 'DESC' },
      });
    }

    return this.nutritionLogRepository.find({
      where: { userId },
      order: { fecha_registro: 'DESC' },
    });
  }

  async findTodayByUser(userId: string) {
    const start = new Date();
    start.setHours(0, 0, 0, 0);

    const end = new Date(start);
    end.setDate(end.getDate() + 1);

    return this.nutritionLogRepository.findOne({
      where: {
        userId,
        fecha_registro: Between(start, end),
      },
      order: { fecha_registro: 'DESC' },
    });
  }

  async findOne(id: string) {
    const nutritionLog = await this.nutritionLogRepository.findOne({ where: { id } });
    if (!nutritionLog) {
      throw new NotFoundException('Registro nutricional no encontrado.');
    }
    return nutritionLog;
  }

  async update(id: string, dto: UpdateNutritionLogDto) {
    await this.findOne(id);
    await this.nutritionLogRepository.update(id, {
      ...dto,
      fecha_registro: dto.fecha_registro ? new Date(dto.fecha_registro) : undefined,
    });
    return this.findOne(id);
  }

  async remove(id: string) {
    const nutritionLog = await this.findOne(id);
    await this.nutritionLogRepository.remove(nutritionLog);
    return { message: 'Registro nutricional eliminado correctamente.' };
  }
}
