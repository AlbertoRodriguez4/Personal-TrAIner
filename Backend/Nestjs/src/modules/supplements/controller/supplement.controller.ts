import { Controller, Post, Get, Patch, Delete, Body, Param, ParseUUIDPipe } from '@nestjs/common';
import { CurrentUser } from '../../auth/current-user.decorator';
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
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() userId: string,
    @Body() dto: UpdateSupplementDto,
  ) {
    return this.service.update(id, userId, dto);
  }

  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() userId: string) {
    return this.service.remove(id, userId);
  }

  @Post(':id/toggle')
  toggleToday(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() userId: string,
    @Body('fecha') fecha?: string,
  ) {
    return this.service.toggleToday(id, userId, fecha);
  }
}
