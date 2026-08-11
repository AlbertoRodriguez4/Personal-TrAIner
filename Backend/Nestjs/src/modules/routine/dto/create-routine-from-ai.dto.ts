import {
  IsArray,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class AiExerciseDto {
  @IsString()
  @IsNotEmpty()
  nombre: string;

  @IsNumber()
  @IsNotEmpty()
  series: number;

  @IsNumber()
  @IsNotEmpty()
  repeticiones: number;

  @IsNumber()
  @IsOptional()
  descanso_segundos?: number;

  @IsString()
  @IsOptional()
  notas?: string;
}

export class AiRoutineDayDto {
  @IsNumber()
  @IsNotEmpty()
  numero_dia: number;

  @IsString()
  @IsNotEmpty()
  nombre_dia: string;

  @IsString()
  @IsNotEmpty()
  grupo_muscular: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => AiExerciseDto)
  ejercicios: AiExerciseDto[];
}

export class CreateRoutineFromAiDto {
  @IsString()
  @IsNotEmpty()
  userId: string;

  @IsString()
  @IsNotEmpty()
  nombre_rutina: string;

  @IsString()
  @IsNotEmpty()
  tipo_entrenamiento: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => AiRoutineDayDto)
  dias_entrenamiento: AiRoutineDayDto[];

  @IsString()
  @IsOptional()
  notas_adicionales?: string;
}
