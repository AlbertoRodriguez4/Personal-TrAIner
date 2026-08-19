import { Body, Controller, Delete, Get, Param, Post, Put, Query } from '@nestjs/common';
import { TrainingSessionService } from '../service/training_session.service';
import { CreateTrainingSessionDto } from '../dto/create-training-session.dto';
import { UpdateTrainingSessionDto } from '../dto/update-training-session.dto';

@Controller('training-sessions')
export class TrainingSessionController {
  constructor(private readonly trainingSessionService: TrainingSessionService) {}

  @Post()
  create(@Body() dto: CreateTrainingSessionDto) {
    return this.trainingSessionService.create(dto);
  }

  @Get('user/:userId')
  findByUser(@Param('userId') userId: string) {
    return this.trainingSessionService.findByUser(userId);
  }

  /// Sesión + media del usuario en cada métrica + cuánto se desvía esta
  /// sesión de esa media. Antes de `:id` en las rutas para que Nest no lo
  /// confunda con `findOne(':id')`.
  @Get(':id/analysis')
  getAnalysis(@Param('id') id: string, @Query('userId') userId: string) {
    return this.trainingSessionService.getAnalysis(id, userId);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.trainingSessionService.findOne(id);
  }

  @Put(':id/complete')
  markAsCompleted(@Param('id') id: string) {
    return this.trainingSessionService.markAsCompleted(id);
  }

  @Put(':id')
  update(@Param('id') id: string, @Body() dto: UpdateTrainingSessionDto) {
    return this.trainingSessionService.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.trainingSessionService.remove(id);
  }
}
