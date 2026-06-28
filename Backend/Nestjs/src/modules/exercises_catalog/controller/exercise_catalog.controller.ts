import { Controller, Get, Query } from '@nestjs/common';
import { ExerciseCatalogService } from '../service/exercise_catalog.service';
import { ExerciseCatalog } from '../entities/exercise_catalog.entity';

@Controller('exercises-catalog')
export class ExerciseCatalogController {
  constructor(private readonly service: ExerciseCatalogService) {}

  @Get()
  findAll(@Query('grupo') grupo?: string): Promise<ExerciseCatalog[]> {
    return grupo ? this.service.findByGrupo(grupo) : this.service.findAll();
  }
}