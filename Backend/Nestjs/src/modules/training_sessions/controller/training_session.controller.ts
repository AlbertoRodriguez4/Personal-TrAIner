import { Body, Controller, Delete, Get, Param, Post, Put } from '@nestjs/common';
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
