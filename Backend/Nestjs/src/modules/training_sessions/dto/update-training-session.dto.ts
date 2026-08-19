import {
  IsArray,
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { ORIGENES_SESION } from './create-training-session.dto';

export class UpdateTrainingSessionDto {
  @IsUUID()
  @IsOptional()
  userId?: string;

  @IsDateString()
  @IsOptional()
  fecha_programada?: string;

  @IsString()
  @IsIn(['fuerza', 'cardio', 'flexibilidad'])
  @IsOptional()
  tipo_entrenamiento?: string;

  @IsArray()
  @IsOptional()
  ejercicios?: Record<string, unknown>[];

  @IsString()
  @IsIn(['pendiente', 'completado'])
  @IsOptional()
  estado?: string;

  @IsInt()
  @Min(0)
  @Max(1440)
  @IsOptional()
  duracion_minutos?: number;

  @IsInt()
  @Min(0)
  @Max(20000)
  @IsOptional()
  calorias_kcal?: number;

  @IsInt()
  @Min(20)
  @Max(250)
  @IsOptional()
  frecuencia_cardiaca_media?: number;

  @IsInt()
  @Min(20)
  @Max(250)
  @IsOptional()
  frecuencia_cardiaca_max?: number;

  @IsNumber()
  @Min(0)
  @Max(500)
  @IsOptional()
  distancia_km?: number;

  @IsString()
  @IsIn(ORIGENES_SESION)
  @IsOptional()
  origen?: string;

  @IsString()
  @MaxLength(60)
  @IsOptional()
  origen_id?: string;
}
