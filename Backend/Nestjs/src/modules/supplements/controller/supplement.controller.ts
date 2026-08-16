import { Controller, Post, Get, Patch, Delete, Body, Param, Query } from '@nestjs/common';
import { SupplementService } from '../service/supplement.service';
import { CreateSupplementDto } from '../dto/create-supplement.dto';
import { UpdateSupplementDto } from '../dto/update-supplement.dto';

@Controller('supplements')
export class SupplementController {
  constructor(private readonly service: SupplementService) {}

  @Post()
  create(@Body() dto: CreateSupplementDto) {
    return this.service.create(dto);
  }

  @Get('user/:userId')
  findByUser(@Param('userId') userId: string) {
    return this.service.findByUser(userId);
  }

  @Get('user/:userId/today')
  findTodayByUser(@Param('userId') userId: string) {
    return this.service.findTodayByUser(userId);
  }

  @Patch(':id')
  update(
    @Param('id') id: string,
    @Query('userId') userId: string,
    @Body() dto: UpdateSupplementDto,
  ) {
    return this.service.update(id, userId, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string, @Query('userId') userId: string) {
    return this.service.remove(id, userId);
  }

  @Post(':id/toggle')
  toggleToday(
    @Param('id') id: string,
    @Body('userId') userId: string,
    @Body('fecha') fecha?: string,
  ) {
    return this.service.toggleToday(id, userId, fecha);
  }
}
