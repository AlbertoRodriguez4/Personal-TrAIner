import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DexaScan } from '../entities/dexa_scan.entity';
import { CreateDexaScanDto } from '../dto/create-dexa-scan.dto';
import { UpdateDexaScanDto } from '../dto/update-dexa-scan.dto';

@Injectable()
export class DexaScanService {
  constructor(
    @InjectRepository(DexaScan)
    private readonly dexaScanRepository: Repository<DexaScan>,
  ) {}

  async create(dto: CreateDexaScanDto) {
    const entity = this.dexaScanRepository.create({
      ...dto,
      fecha_escaneo: new Date(dto.fecha_escaneo),
    });
    return this.dexaScanRepository.save(entity);
  }

  async findByUser(userId: string) {
    return this.dexaScanRepository.find({
      where: { userId },
      order: { fecha_escaneo: 'DESC' },
    });
  }

  async findOne(id: string) {
    const dexaScan = await this.dexaScanRepository.findOne({ where: { id } });
    if (!dexaScan) {
      throw new NotFoundException('Escáner DEXA no encontrado.');
    }
    return dexaScan;
  }

  async update(id: string, dto: UpdateDexaScanDto) {
    await this.findOne(id);
    await this.dexaScanRepository.update(id, {
      ...dto,
      fecha_escaneo: dto.fecha_escaneo ? new Date(dto.fecha_escaneo) : undefined,
    });
    return this.findOne(id);
  }

  async remove(id: string) {
    const dexaScan = await this.findOne(id);
    await this.dexaScanRepository.remove(dexaScan);
    return { message: 'Escáner DEXA eliminado correctamente.' };
  }
}
