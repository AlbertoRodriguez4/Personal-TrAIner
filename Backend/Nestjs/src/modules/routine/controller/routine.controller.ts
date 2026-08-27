import { Body, Controller, Delete, Get, Param, Patch, Post, Put, Query } from '@nestjs/common';
import { RoutineService } from '../service/routine.service';
import { CreateRoutineDto } from '../dto/create-routine.dto';
import { UpdateRoutineDto } from '../dto/update-routine.dto';
import { CreateRoutineFromAiDto } from '../dto/create-routine-from-ai.dto';

@Controller('api/routines')
export class RoutineController {
  constructor(private readonly routineService: RoutineService) {}

  @Get()
  findAll() {
    return this.routineService.findAll();
  }

  @Get('user/:userId')
  findByUser(@Param('userId') userId: string) {
    return this.routineService.findAll(userId);
  }

  @Get('user/:userId/active')
  findActiveByUser(@Param('userId') userId: string) {
    return this.routineService.findActiveByUser(userId);
  }

  /// Volumen semanal planificado por músculo, para contrastarlo con el hecho.
  ///
  /// La ruta lleva `:userId` a propósito y no el id de la rutina: `JwtAuthGuard`
  /// es global y compara el `userId` de params contra el `sub` del token, así
  /// que una ruta `/:id/muscle-load` no le daría nada que comparar.
  @Get('user/:userId/active/muscle-load')
  getActiveMuscleLoad(@Param('userId') userId: string) {
    return this.routineService.getActiveMuscleLoad(userId);
  }

  @Post()
  create(@Body() dto: CreateRoutineDto) {
    return this.routineService.create(dto);
  }

  @Post('ai')
  createFromAi(@Body() dto: CreateRoutineFromAiDto) {
    return this.routineService.createFromAiPayload(dto);
  }

  @Get(':id')
  findOne(@Param('id') id: string, @Query('userId') userId: string) {
    return this.routineService.findOneForUser(id, userId);
  }

  @Patch(':id')
  update(
    @Param('id') id: string,
    @Query('userId') userId: string,
    @Body() dto: UpdateRoutineDto,
  ) {
    return this.routineService.update(id, userId, dto);
  }

  @Put(':id/ai')
  updateFromAi(
    @Param('id') id: string,
    @Query('userId') userId: string,
    @Body('dias_entrenamiento') dias: any[],
  ) {
    return this.routineService.updateFromAiPayload(id, userId, dias);
  }

  @Put(':id/activate')
  setAsActive(@Param('id') id: string, @Body('userId') userId: string) {
    return this.routineService.setAsActive(id, userId);
  }

  @Delete(':id')
  remove(@Param('id') id: string, @Query('userId') userId: string) {
    return this.routineService.remove(id, userId);
  }
}
