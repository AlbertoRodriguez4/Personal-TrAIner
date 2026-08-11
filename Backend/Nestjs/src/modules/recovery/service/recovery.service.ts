import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { RecoveryLog } from '../entities/recovery_log.entity';
import { CreateRecoveryLogDto } from '../dto/create-recovery-log.dto';

@Injectable()
export class RecoveryService {
  constructor(
    @InjectRepository(RecoveryLog)
    private readonly repo: Repository<RecoveryLog>,
  ) {}

  async create(dto: CreateRecoveryLogDto): Promise<RecoveryLog> {
    const record = this.repo.create(dto);
    return this.repo.save(record);
  }

  async findByUser(userId: string, days: number = 7): Promise<RecoveryLog[]> {
    const fromDate = new Date();
    fromDate.setDate(fromDate.getDate() - days);

    return this.repo
      .createQueryBuilder('recovery')
      .where('recovery.userId = :userId', { userId })
      .andWhere('recovery.fecha >= :fromDate', { fromDate })
      .orderBy('recovery.fecha', 'DESC')
      .getMany();
  }

  async findLatest(userId: string): Promise<RecoveryLog | null> {
    return this.repo.findOne({
      where: { userId },
      order: { fecha: 'DESC' },
    });
  }
}
