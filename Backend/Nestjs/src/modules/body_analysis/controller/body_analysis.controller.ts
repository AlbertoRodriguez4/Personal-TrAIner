import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { CurrentUser } from '../../auth/current-user.decorator';
import { BodyAnalysisService } from '../service/body_analysis.service';
import { PhysiquePhotoService } from '../service/physique_photo.service';
import { CreateBodyAnalysisRecordDto } from '../dto/create-body-analysis-record.dto';
import { CreatePhysiqueAnalysisDto } from '../dto/create-physique-analysis.dto';
import { UpdateBodyAnalysisRecordDto } from '../dto/update-body-analysis-record.dto';

@Controller('body-analysis')
export class BodyAnalysisController {
  constructor(
    private readonly bodyAnalysisService: BodyAnalysisService,
    private readonly physiquePhotoService: PhysiquePhotoService,
  ) {}

  @Post()
  create(@Body() dto: CreateBodyAnalysisRecordDto) {
    return this.bodyAnalysisService.create(dto);
  }

  /// Alta del apartado "Físico": registro + fotos en una sola llamada.
  @Post('with-photos')
  createWithPhotos(@Body() dto: CreatePhysiqueAnalysisDto) {
    return this.physiquePhotoService.createWithPhotos(dto);
  }

  @Get('user/:userId/ai-summary')
  buildAiSummary(@Param('userId') userId: string) {
    return this.physiquePhotoService.buildAiSummary(userId);
  }

  /// Declarado ANTES de `:id/photos` para que `/photos/<uuid>` no se lea como
  /// un id de análisis seguido del literal "photos".
  @Get('photos/:photoId')
  async getPhoto(
    @Param('photoId', ParseUUIDPipe) photoId: string,
    @Res() res: Response,
    @CurrentUser() userId: string,
  ) {
    const foto = await this.physiquePhotoService.findPhotoBytes(photoId, userId);
    // Cabeceras a mano: con @Res() Nest cede el control de la respuesta, así
    // que el decorador @Header no llegaría a aplicarse.
    res.setHeader('Content-Type', foto.mime_type);
    res.setHeader('Cache-Control', 'private, max-age=86400');
    res.send(foto.imagen);
  }

  @Get(':id/photos')
  findPhotos(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() userId: string) {
    return this.physiquePhotoService.findPhotoMetaByRecord(id, userId);
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
  findOne(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() userId: string) {
    return this.bodyAnalysisService.findOne(id, userId);
  }

  @Put(':id')
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() userId: string,
    @Body() dto: UpdateBodyAnalysisRecordDto,
  ) {
    return this.bodyAnalysisService.update(id, userId, dto);
  }

  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() userId: string) {
    return this.bodyAnalysisService.remove(id, userId);
  }
}
