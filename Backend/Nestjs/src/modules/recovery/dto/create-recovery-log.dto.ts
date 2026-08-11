import { IsUUID, IsDateString, IsInt, IsOptional, IsNumber, IsString } from 'class-validator';

export class CreateRecoveryLogDto {
  @IsString()
  userId: string;

  @IsDateString()
  fecha: string;

  @IsOptional()
  @IsNumber()
  horas_sueno?: number;

  @IsOptional()
  @IsString()
  hrv_estado?: string;

  @IsOptional()
  @IsInt()
  frecuencia_cardiaca_reposo?: number;

  @IsInt()
  readiness_score: number;

  @IsOptional()
  @IsString()
  fuente?: string;

  @IsOptional()
  @IsString()
  notas_ia?: string;
}
