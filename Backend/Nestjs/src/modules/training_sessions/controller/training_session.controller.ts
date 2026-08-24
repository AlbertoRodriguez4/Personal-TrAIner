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

  /// Volumen, intensidad y fatiga acumulada por grupo muscular en los últimos
  /// `dias` días — lo que pinta el mapa corporal de la pantalla de entrenar.
  /// Cuelga de `user/:userId` y no de la raíz para que la guarda global
  /// compruebe la pertenencia por el parámetro de ruta, igual que el resto de
  /// rutas por usuario.
  @Get('user/:userId/muscle-load')
  getMuscleLoad(@Param('userId') userId: string, @Query('dias') dias?: string) {
    return this.trainingSessionService.getMuscleLoad(userId, Number(dias) || 7);
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
