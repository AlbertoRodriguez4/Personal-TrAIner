import { IsDateString, IsNotEmpty, IsNumber, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';

export class CreatePostureEvaluationDto {
  @IsUUID()
  @IsNotEmpty()
  userId: string;

  @IsDateString()
  @IsNotEmpty()
  fecha_evaluacion: string;

  @IsString()
  @IsNotEmpty()
  imagen_frontal_url: string;

  @IsString()
  @IsNotEmpty()
  imagen_lateral_url: string;

  @IsNumber()
  @Min(0)
  @Max(100)
  puntuacion_postura: number;

  @IsOptional()
  analisis_ia?: string | Record<string, unknown>;
}
