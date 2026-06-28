import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ExerciseCatalog } from '../entities/exercise_catalog.entity';

@Injectable()
export class ExerciseCatalogService {
  constructor(
    @InjectRepository(ExerciseCatalog)
    private readonly repo: Repository<ExerciseCatalog>,
  ) {}

  findAll(): Promise<ExerciseCatalog[]> {
    return this.repo.find({ order: { grupo_muscular: 'ASC', nombre: 'ASC' } });
  }

  findByGrupo(grupo: string): Promise<ExerciseCatalog[]> {
    return this.repo.find({
      where: { grupo_muscular: grupo },
      order: { nombre: 'ASC' },
    });
  }
}