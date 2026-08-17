import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { ClinicalReportService } from '../service/clinical_report.service';
import { CreateClinicalReportDto } from '../dto/create-clinical-report.dto';
import { CreateClinicalMarkersDto } from '../dto/create-clinical-markers.dto';

/// Sin capa de auth todavía: `userId` viaja explícito en cada request y el
/// servicio compara contra el dueño de la fila antes de leer o borrar, igual
/// que en `routine`, `nutrition` y `training_sessions`.
@Controller('clinical-reports')
export class ClinicalReportController {
  constructor(private readonly clinicalReportService: ClinicalReportService) {}

  private requireUserId(userId?: string): string {
    if (!userId) {
      throw new BadRequestException('Falta el parámetro userId.');
    }
    return userId;
  }

  @Post()
  create(@Body() dto: CreateClinicalReportDto) {
    return this.clinicalReportService.createWithMarkers(dto);
  }

  @Post('markers/manual')
  createManualMarkers(@Body() dto: CreateClinicalMarkersDto) {
    return this.clinicalReportService.createManualMarkers(dto);
  }

  @Get('user/:userId')
  findByUser(@Param('userId') userId: string) {
    return this.clinicalReportService.findReportsByUser(userId);
  }

  @Get('user/:userId/markers')
  findMarkers(@Param('userId') userId: string, @Query('codigo') codigo?: string) {
    return this.clinicalReportService.findMarkersByUser(userId, codigo);
  }

  @Get('user/:userId/markers/latest')
  findLatestMarkers(@Param('userId') userId: string) {
    return this.clinicalReportService.findLatestMarkers(userId);
  }

  @Get('user/:userId/ai-summary')
  buildAiSummary(@Param('userId') userId: string) {
    return this.clinicalReportService.buildAiSummary(userId);
  }

  @Get(':id')
  findOne(@Param('id') id: string, @Query('userId') userId?: string) {
    return this.clinicalReportService.findReport(id, this.requireUserId(userId));
  }

  @Delete('markers/:id')
  removeMarker(@Param('id') id: string, @Query('userId') userId?: string) {
    return this.clinicalReportService.removeMarker(id, this.requireUserId(userId));
  }

  @Delete(':id')
  remove(@Param('id') id: string, @Query('userId') userId?: string) {
    return this.clinicalReportService.removeReport(id, this.requireUserId(userId));
  }
}
