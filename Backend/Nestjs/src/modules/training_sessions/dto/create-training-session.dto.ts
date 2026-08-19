import {
  ArrayNotEmpty,
  IsArray,
  IsDateString,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export const ORIGENES_SESION = ['manual', 'app', 'health_connect'] as const;

export class CreateTrainingSessionDto {
  @IsUUID()
  @IsNotEmpty()
  userId: string;

  @IsDateString()
  @IsNotEmpty()
  fecha_programada: string;

  @IsString()
  @IsIn(['fuerza', 'cardio', 'flexibilidad'])
  tipo_entrenamiento: string;

  @IsArray()
  @ArrayNotEmpty()
  ejercicios: Record<string, unknown>[];

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
