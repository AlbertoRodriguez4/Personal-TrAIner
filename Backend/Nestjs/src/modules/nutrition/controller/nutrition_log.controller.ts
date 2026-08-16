import { Body, Controller, Delete, Get, Param, Post, Put, Query } from '@nestjs/common';
import { NutritionLogService } from '../service/nutrition_log.service';
import { CreateNutritionLogDto } from '../dto/create-nutrition-log.dto';
import { UpdateNutritionLogDto } from '../dto/update-nutrition-log.dto';
import { NutritionLogQueryDto } from '../dto/nutrition-log-query.dto';

@Controller('nutrition-logs')
export class NutritionLogController {
  constructor(private readonly nutritionLogService: NutritionLogService) {}

  @Post()
  create(@Body() dto: CreateNutritionLogDto) {
    return this.nutritionLogService.create(dto);
  }

  @Get('user/:userId')
  findByUser(@Param('userId') userId: string, @Query() query: NutritionLogQueryDto) {
    return this.nutritionLogService.findByUser(userId, query.startDate, query.endDate);
  }

  @Get('user/:userId/today')
  findToday(@Param('userId') userId: string) {
    return this.nutritionLogService.findTodayByUser(userId);
  }

  @Get('user/:userId/calendar')
  findCalendar(
    @Param('userId') userId: string,
    @Query('from') from: string,
    @Query('to') to: string,
  ) {
    return this.nutritionLogService.findCalendarSummary(userId, from, to);
  }

  @Get('user/:userId/day/:date')
  findDay(@Param('userId') userId: string, @Param('date') date: string) {
    return this.nutritionLogService.findDayDetail(userId, date);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.nutritionLogService.findOne(id);
  }

  @Put(':id')
  update(@Param('id') id: string, @Body() dto: UpdateNutritionLogDto) {
    return this.nutritionLogService.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.nutritionLogService.remove(id);
  }
}
