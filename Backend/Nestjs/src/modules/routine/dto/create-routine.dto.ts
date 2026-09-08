import {
  ArrayNotEmpty,
  IsArray,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateExerciseDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsInt()
  @IsOptional()
  sets?: number;

  @IsString()
  @IsOptional()
  reps?: string;

  @IsNumber()
  @IsOptional()
  weight?: number;

  /// Peso de cada serie, para los ejercicios en rampa. `weight` sigue siendo el
  /// de referencia y se usa cuando esto viene vacio.
  weights?: number[];

  @IsString()
  @IsOptional()
  duration?: string;

  @IsString()
  @IsOptional()
  notes?: string;

  /// Descanso entre series. Sin declararlo aqui llegaba igual a la entidad
  /// porque el ValidationPipe va sin whitelist, pero eso es un accidente
  /// afortunado y no un contrato: escrito, se ve que forma parte del payload.
  rest_seconds?: number;
}

export class CreateRoutineDayDto {
  @IsString()
  @IsNotEmpty()
  day_of_week: string;

  @IsString()
  @IsOptional()
  focus?: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateExerciseDto)
  exercises: CreateExerciseDto[];
}

export class CreateRoutineDto {
  @IsString()
  @IsOptional()
  userId?: string;

  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsNotEmpty()
  activity_type: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsArray()
  @ArrayNotEmpty()
  @ValidateNested({ each: true })
  @Type(() => CreateRoutineDayDto)
  days: CreateRoutineDayDto[];
}
