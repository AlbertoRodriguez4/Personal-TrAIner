import { Type } from 'class-transformer';
import {
  IsArray,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';
import { CreateBodyAnalysisRecordDto } from './create-body-analysis-record.dto';

export const ANGULOS_FOTO = ['frontal', 'lateral', 'espalda', 'otro'] as const;

export class PhysiquePhotoInputDto {
  @IsIn(ANGULOS_FOTO)
  @IsOptional()
  angulo?: string;

  @IsString()
  @IsOptional()
  mime_type?: string;

  /// JPEG/PNG en base64, ya reescalado por el cliente (~1280px, calidad 80).
  @IsString()
  @IsNotEmpty()
  data: string;
}

/// Análisis físico completo tal y como lo cierra el servicio de IA: el registro
/// con los datos clave + las fotos que lo originaron, en una sola llamada para
/// que no queden fotos huérfanas si el segundo request falla.
export class CreatePhysiqueAnalysisDto extends CreateBodyAnalysisRecordDto {
  @IsString()
  @IsOptional()
  origen?: string;

  @IsArray()
  @IsOptional()
  angulos_fotos?: string[];

  @IsArray()
  @IsOptional()
  grupos_musculares_retrasados?: string[];

  @IsArray()
  @IsOptional()
  grupos_musculares_dominantes?: string[];

  @IsOptional()
  medidas_estimadas?: Record<string, unknown>;

  @IsString()
  @IsOptional()
  postura_observaciones?: string;

  @IsString()
  @IsOptional()
  prioridad_entrenamiento?: string;

  @IsArray()
  @IsOptional()
  fuentes_consultadas?: Record<string, unknown>[];

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PhysiquePhotoInputDto)
  @IsOptional()
  fotos?: PhysiquePhotoInputDto[];
}
