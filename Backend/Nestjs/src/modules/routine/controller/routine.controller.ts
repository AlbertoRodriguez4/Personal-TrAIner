import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
} from '@nestjs/common';
import { CurrentUser } from '../../auth/current-user.decorator';
import { RoutineService } from '../service/routine.service';
import { CreateRoutineDto } from '../dto/create-routine.dto';
import { UpdateRoutineDto } from '../dto/update-routine.dto';
import {
  CreateRoutineFromAiDto,
  UpdateRoutineFromAiDto,
} from '../dto/create-routine-from-ai.dto';

@Controller('api/routines')
export class RoutineController {
  constructor(private readonly routineService: RoutineService) {}

  /// Las rutinas del usuario de la sesión. Sin filtro devolvía las de TODOS
  /// los usuarios a cualquier token válido.
  @Get()
  findAll(@CurrentUser() userId: string) {
    return this.routineService.findAll(userId);
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

  /// El dueño sale de la sesión, no del cuerpo: `userId` es opcional en el DTO
  /// y sin él la rutina se guardaba huérfana, sin nadie que pudiera verla.
  @Post()
  create(@Body() dto: CreateRoutineDto, @CurrentUser() userId: string) {
    return this.routineService.create({ ...dto, userId });
  }

  @Post('ai')
  createFromAi(@Body() dto: CreateRoutineFromAiDto) {
    return this.routineService.createFromAiPayload(dto);
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() userId: string) {
    return this.routineService.findOneForUser(id, userId);
  }

  @Patch(':id')
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() userId: string,
    @Body() dto: UpdateRoutineDto,
  ) {
    return this.routineService.update(id, userId, dto);
  }

  @Put(':id/ai')
  updateFromAi(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() userId: string,
    @Body() dto: UpdateRoutineFromAiDto,
  ) {
    return this.routineService.updateFromAiPayload(id, userId, dto.dias_entrenamiento);
  }

  @Put(':id/activate')
  setAsActive(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() userId: string) {
    return this.routineService.setAsActive(id, userId);
  }

  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() userId: string) {
    return this.routineService.remove(id, userId);
  }
}
