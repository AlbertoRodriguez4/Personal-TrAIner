import { IsDateString, IsNumber, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';

export class UpdatePostureEvaluationDto {
  @IsUUID()
  @IsOptional()
  userId?: string;

  @IsDateString()
  @IsOptional()
  fecha_evaluacion?: string;

  @IsString()
  @IsOptional()
  imagen_frontal_url?: string;

  @IsString()
  @IsOptional()
  imagen_lateral_url?: string;

  @IsNumber()
  @Min(0)
  @Max(100)
  @IsOptional()
  puntuacion_postura?: number;

  @IsOptional()
  analisis_ia?: string | Record<string, unknown>;
}
