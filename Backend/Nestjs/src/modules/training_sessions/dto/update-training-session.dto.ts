import { IsArray, IsDateString, IsIn, IsOptional, IsString, IsUUID } from 'class-validator';

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
}
