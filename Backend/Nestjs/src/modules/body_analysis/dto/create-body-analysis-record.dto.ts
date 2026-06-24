import {
  IsArray,
  IsDateString,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';

export class CreateBodyAnalysisRecordDto {
  @IsUUID()
  @IsNotEmpty()
  userId: string;

  @IsDateString()
  @IsOptional()
  fecha_analisis?: string;

  @IsString()
  @IsNotEmpty()
  analisis_general: string;

  @IsNumber()
  @IsOptional()
  peso_estimado_kg?: number;

  @IsNumber()
  @IsOptional()
  porcentaje_grasa_estimado?: number;

  @IsNumber()
  @IsOptional()
  masa_muscular_estimada_kg?: number;

  @IsString()
  @IsOptional()
  somatotipo_estimado?: string;

  @IsString()
  @IsOptional()
  nivel_fitness_estimado?: string;

  @IsArray()
  @IsOptional()
  puntos_fuertes_fisicos?: string[];

  @IsArray()
  @IsOptional()
  areas_mejora_fisicas?: string[];

  @IsString()
  @IsOptional()
  recomendaciones?: string;

  @IsOptional()
  metricas_adicionales?: Record<string, unknown>;

  @IsString()
  @IsOptional()
  notas_adicionales?: string;

  @IsString()
  @IsOptional()
  comparacion_progreso?: string;
}
