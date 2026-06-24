import {
  ArrayNotEmpty,
  IsArray,
  IsDateString,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';

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
}
