import { Controller, Post, Body, Get, Param, Query } from '@nestjs/common';
import { RecoveryService } from '../service/recovery.service';
import { CreateRecoveryLogDto } from '../dto/create-recovery-log.dto';

@Controller('recovery-logs')
export class RecoveryController {
  constructor(private readonly service: RecoveryService) {}

  @Post()
  create(@Body() dto: CreateRecoveryLogDto) {
    return this.service.create(dto);
  }

  @Get('user/:userId')
  findByUser(@Param('userId') userId: string, @Query('days') days?: string) {
    return this.service.findByUser(userId, days ? parseInt(days, 10) : 7);
  }

  @Get('user/:userId/latest')
  findLatest(@Param('userId') userId: string) {
    return this.service.findLatest(userId);
  }
}
