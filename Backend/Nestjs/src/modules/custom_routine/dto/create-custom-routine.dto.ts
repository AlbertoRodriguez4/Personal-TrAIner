import {
  ArrayNotEmpty,
  IsArray,
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class EjercicioDiaDto {
  @IsString()
  @IsNotEmpty()
  nombre: string;

  @IsInt()
  @Min(1)
  series: number;

  @IsInt()
  @Min(1)
  repeticiones: number;

  @IsInt()
  @Min(0)
  descanso_segundos: number;

  @IsString()
  @IsOptional()
  notas?: string;
}

export class DiaEntrenamientoDto {
  @IsInt()
  @Min(1)
  @Max(7)
  numero_dia: number;

  @IsString()
  @IsNotEmpty()
  nombre_dia: string;

  @IsString()
  @IsNotEmpty()
  grupo_muscular: string;

  @IsArray()
  @ArrayNotEmpty()
  @ValidateNested({ each: true })
  @Type(() => EjercicioDiaDto)
  ejercicios: EjercicioDiaDto[];
}

export class CreateCustomRoutineDto {
  @IsUUID()
  @IsNotEmpty()
  userId: string;

  @IsString()
  @IsNotEmpty()
  nombre_rutina: string;

  @IsString()
  @IsNotEmpty()
  tipo_entrenamiento: string;

  @IsInt()
  @Min(1)
  @Max(7)
  numero_dias: number;

  @IsArray()
  @ArrayNotEmpty()
  @ValidateNested({ each: true })
  @Type(() => DiaEntrenamientoDto)
  dias_entrenamiento: DiaEntrenamientoDto[];

  @IsString()
  @IsOptional()
  notas_adicionales?: string;

  @IsBoolean()
  @IsOptional()
  activa?: boolean;
}
