import { Body, Controller, Delete, Get, Param, Post, Put } from '@nestjs/common';
import { BodyAnalysisService } from '../service/body_analysis.service';
import { CreateBodyAnalysisRecordDto } from '../dto/create-body-analysis-record.dto';
import { UpdateBodyAnalysisRecordDto } from '../dto/update-body-analysis-record.dto';

@Controller('body-analysis')
export class BodyAnalysisController {
  constructor(private readonly bodyAnalysisService: BodyAnalysisService) {}

  @Post()
  create(@Body() dto: CreateBodyAnalysisRecordDto) {
    return this.bodyAnalysisService.create(dto);
  }

  @Get('user/:userId')
  findByUser(@Param('userId') userId: string) {
    return this.bodyAnalysisService.findByUser(userId);
  }

  @Get('user/:userId/latest')
  findLatestByUser(@Param('userId') userId: string) {
    return this.bodyAnalysisService.findLatestByUser(userId);
  }

  @Get('user/:userId/should-create')
  shouldCreateNewRecord(@Param('userId') userId: string) {
    return this.bodyAnalysisService.shouldCreateNewRecord(userId);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.bodyAnalysisService.findOne(id);
  }

  @Put(':id')
  update(@Param('id') id: string, @Body() dto: UpdateBodyAnalysisRecordDto) {
    return this.bodyAnalysisService.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.bodyAnalysisService.remove(id);
  }
}
