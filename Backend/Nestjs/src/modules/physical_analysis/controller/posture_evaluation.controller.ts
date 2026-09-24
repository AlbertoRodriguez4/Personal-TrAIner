import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Post, Put } from '@nestjs/common';
import { CurrentUser } from '../../auth/current-user.decorator';
import { PostureEvaluationService } from '../service/posture_evaluation.service';
import { CreatePostureEvaluationDto } from '../dto/create-posture-evaluation.dto';
import { UpdatePostureEvaluationDto } from '../dto/update-posture-evaluation.dto';

@Controller('posture-evaluations')
export class PostureEvaluationController {
  constructor(private readonly postureEvaluationService: PostureEvaluationService) {}

  @Post()
  create(@Body() dto: CreatePostureEvaluationDto) {
    return this.postureEvaluationService.create(dto);
  }

  @Get('user/:userId')
  findByUser(@Param('userId') userId: string) {
    return this.postureEvaluationService.findByUser(userId);
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() userId: string) {
    return this.postureEvaluationService.findOne(id, userId);
  }

  @Put(':id')
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() userId: string,
    @Body() dto: UpdatePostureEvaluationDto,
  ) {
    return this.postureEvaluationService.update(id, userId, dto);
  }

  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() userId: string) {
    return this.postureEvaluationService.remove(id, userId);
  }
}
