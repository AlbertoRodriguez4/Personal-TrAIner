import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Supplement } from '../entities/supplement.entity';
import { SupplementLog } from '../entities/supplement_log.entity';
import { CreateSupplementDto } from '../dto/create-supplement.dto';
import { UpdateSupplementDto } from '../dto/update-supplement.dto';

function todayDateOnly(): Date {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

@Injectable()
export class SupplementService {
  constructor(
    @InjectRepository(Supplement)
    private readonly supplementRepository: Repository<Supplement>,
    @InjectRepository(SupplementLog)
    private readonly logRepository: Repository<SupplementLog>,
  ) {}

  async create(dto: CreateSupplementDto) {
    const supplement = this.supplementRepository.create(dto);
    return this.supplementRepository.save(supplement);
  }

  async findByUser(userId: string) {
    return this.supplementRepository.find({
      where: { userId, activo: true },
      order: { created_at: 'ASC' },
    });
  }

  async findTodayByUser(userId: string) {
    const supplements = await this.findByUser(userId);
    const today = todayDateOnly();
    const todayLogs = await this.logRepository.find({
      where: { userId, fecha: today },
    });
    const takenIds = new Set(todayLogs.map((log) => log.supplementId));

    return supplements.map((s) => ({
      ...s,
      tomadoHoy: takenIds.has(s.id),
    }));
  }

  async findOne(id: string) {
    const supplement = await this.supplementRepository.findOne({ where: { id } });
    if (!supplement) {
      throw new NotFoundException('Suplemento no encontrado');
    }
    return supplement;
  }

  async findOneForUser(id: string, userId: string) {
    const supplement = await this.findOne(id);
    if (supplement.userId !== userId) {
      throw new NotFoundException('Suplemento no encontrado');
    }
    return supplement;
  }

  async update(id: string, userId: string, dto: UpdateSupplementDto) {
    const supplement = await this.findOneForUser(id, userId);
    Object.assign(supplement, dto);
    return this.supplementRepository.save(supplement);
  }

  async remove(id: string, userId: string) {
    const supplement = await this.findOneForUser(id, userId);
    await this.supplementRepository.remove(supplement);
    return { message: 'Suplemento eliminado correctamente' };
  }

  async toggleToday(id: string, userId: string, fecha?: string) {
    await this.findOneForUser(id, userId);
    const date = fecha ? new Date(fecha) : todayDateOnly();
    date.setHours(0, 0, 0, 0);

    const existing = await this.logRepository.findOne({
      where: { userId, supplementId: id, fecha: date },
    });

    if (existing) {
      await this.logRepository.remove(existing);
      return { tomado: false };
    }

    const log = this.logRepository.create({ userId, supplementId: id, fecha: date });
    await this.logRepository.save(log);
    return { tomado: true };
  }
}
