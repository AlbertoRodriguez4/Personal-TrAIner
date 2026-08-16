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

  // Carga sugerida por la IA. Opcional: solo viene cuando hay base real para estimarla
  // (nivel del usuario, cargas que ya mueve); se omite en ejercicios de peso corporal.
  @IsNumber()
  @IsOptional()
  peso_sugerido_kg?: number;

  @IsString()
  @IsOptional()
  notas?: string;
}

export class AiRoutineDayDto {
  @IsNumber()
  @IsNotEmpty()
  numero_dia: number;

  // Día real de la semana ('Lunes'..'Domingo'). Es lo que se guarda en day_of_week, y
  // la app Flutter cruza ese valor contra su lista fija de días para pintar el plan
  // semanal: un valor fuera de esa lista (el viejo `Día ${numero_dia}`) hacía que la
  // pantalla de edición saliera vacía y que al guardar se perdieran los días.
  // Opcional en el DTO por compatibilidad con rutinas creadas antes de este campo.
  @IsString()
  @IsOptional()
  dia_semana?: string;

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
