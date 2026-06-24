import {
  IsString,
  IsNumber,
  IsOptional,
  IsArray,
  Min,
  Max,
  ArrayNotEmpty,
  IsUUID,
} from 'class-validator';

export class CreateUserProfileDto {
  @IsUUID('4')
  user_id: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(7)
  dias_entrenamiento_semana?: number;

  @IsOptional()
  @IsString()
  intensidad?: string;

  @IsOptional()
  @IsString()
  nivel_experiencia?: string;

  @IsOptional()
  @IsArray()
  @ArrayNotEmpty()
  @IsString({ each: true })
  objetivos?: string[];

  @IsOptional()
  @IsString()
  tipo_cuerpo?: string;

  @IsOptional()
  @IsString()
  condiciones_medicas?: string;

  @IsOptional()
  @IsNumber()
  bmi?: number;

  @IsOptional()
  @IsNumber()
  dexa_porcentaje_grasa?: number;

  @IsOptional()
  @IsNumber()
  dexa_masa_muscular_kg?: number;

  @IsOptional()
  @IsString()
  notas_adicionales?: string;
}
