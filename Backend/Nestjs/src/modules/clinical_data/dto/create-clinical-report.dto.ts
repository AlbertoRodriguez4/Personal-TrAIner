import { Type } from 'class-transformer';
import {
  IsArray,
  IsDateString,
  IsIn,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  ValidateNested,
} from 'class-validator';

export const ESTADOS_MARCADOR = ['bajo', 'normal', 'alto', 'desconocido'] as const;

export class ClinicalMarkerInputDto {
  /// Slug canónico ya normalizado en el servicio de IA (`hba1c`, `ferritina`…).
  @IsString()
  @IsNotEmpty()
  codigo: string;

  @IsString()
  @IsNotEmpty()
  nombre: string;

  @IsNumber()
  valor: number;

  @IsString()
  @IsOptional()
  unidad?: string;

  @IsNumber()
  @IsOptional()
  rango_min?: number;

  @IsNumber()
  @IsOptional()
  rango_max?: number;

  @IsIn(ESTADOS_MARCADOR)
  @IsOptional()
  estado?: string;

  @IsString()
  @IsOptional()
  relevancia_fisico?: string;

  /// Fecha de la medición. Si falta, hereda la del informe.
  @IsDateString()
  @IsOptional()
  fecha?: string;
}

export class CreateClinicalReportDto {
  @IsUUID()
  @IsNotEmpty()
  userId: string;

  @IsDateString()
  @IsOptional()
  fecha_informe?: string;

  @IsString()
  @IsOptional()
  tipo_documento?: string;

  @IsString()
  @IsOptional()
  nombre_archivo?: string;

  @IsString()
  @IsNotEmpty()
  resumen_ia: string;

  @IsArray()
  @IsOptional()
  hallazgos_clave?: string[];

  @IsString()
  @IsOptional()
  implicaciones_entrenamiento?: string;

  @IsString()
  @IsOptional()
  implicaciones_nutricion?: string;

  @IsArray()
  @IsOptional()
  banderas_rojas?: string[];

  @IsArray()
  @IsOptional()
  fuentes_consultadas?: Record<string, unknown>[];

  @IsString()
  @IsOptional()
  confianza_extraccion?: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ClinicalMarkerInputDto)
  @IsOptional()
  marcadores?: ClinicalMarkerInputDto[];
}
