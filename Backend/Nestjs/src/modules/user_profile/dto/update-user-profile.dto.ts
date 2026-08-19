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

export class UpdateUserProfileDto {
  @IsOptional()
  @IsUUID('4')
  user_id?: string;

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
  @IsArray()
  @ArrayNotEmpty()
  @IsString({ each: true })
  actividades?: string[];

  @IsOptional()
  @IsString()
  sexo?: string;

  @IsOptional()
  @IsNumber()
  fc_reposo?: number;

  @IsOptional()
  @IsNumber()
  horas_sueno_habitual?: number;

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

  // ===== Metas diarias =====
  @IsOptional()
  @IsNumber()
  @Min(0)
  meta_kcal?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  meta_proteinas_g?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  meta_carbohidratos_g?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  meta_grasas_g?: number;
}
