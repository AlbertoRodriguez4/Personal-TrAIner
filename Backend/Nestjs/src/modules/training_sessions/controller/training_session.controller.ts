import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { CurrentUser } from '../../auth/current-user.decorator';
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
  getAnalysis(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() userId: string) {
    return this.trainingSessionService.getAnalysis(id, userId);
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() userId: string) {
    return this.trainingSessionService.findOne(id, userId);
  }

  @Put(':id/complete')
  markAsCompleted(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() userId: string) {
    return this.trainingSessionService.markAsCompleted(id, userId);
  }

  @Put(':id')
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() userId: string,
    @Body() dto: UpdateTrainingSessionDto,
  ) {
    return this.trainingSessionService.update(id, userId, dto);
  }

  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() userId: string) {
    return this.trainingSessionService.remove(id, userId);
  }
}
