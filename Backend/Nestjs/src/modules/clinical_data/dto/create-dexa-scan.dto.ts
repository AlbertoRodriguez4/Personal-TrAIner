import {
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

export const METODOS_COMPOSICION = [
  'dexa',
  'bioimpedancia',
  'plicometria',
  'bascula',
  'otro',
] as const;

/// Solo `userId` y `fecha_escaneo` son obligatorios. Cada aparato mide un
/// subconjunto distinto y el servicio deriva lo que pueda (IMC, masa grasa,
/// masa magra, FFMI) de lo que sí llegue, así que exigir más aquí solo
/// conseguiría que el cliente rellenase huecos a ojo.
export class CreateDexaScanDto {
  @IsUUID()
  @IsNotEmpty()
  userId: string;

  @IsDateString()
  @IsNotEmpty()
  fecha_escaneo: string;

  @IsString()
  @IsIn(METODOS_COMPOSICION)
  @IsOptional()
  metodo?: string;

  @IsNumber()
  @Min(20)
  @Max(400)
  @IsOptional()
  peso_kg?: number;

  @IsNumber()
  @Min(0)
  @Max(100)
  @IsOptional()
  porcentaje_grasa?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  masa_grasa_kg?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  masa_magra_kg?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  masa_muscular_kg?: number;

  @IsNumber()
  @Min(0)
  @Max(100)
  @IsOptional()
  musculo_pct?: number;

  @IsNumber()
  @Min(0)
  @Max(100)
  @IsOptional()
  musculo_esqueletico_pct?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  masa_osea_kg?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  densidad_osea?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  proteina_kg?: number;

  @IsNumber()
  @Min(0)
  @Max(100)
  @IsOptional()
  proteina_pct?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  agua_corporal_kg?: number;

  @IsNumber()
  @Min(0)
  @Max(100)
  @IsOptional()
  agua_corporal_pct?: number;

  @IsNumber()
  @Min(0)
  @Max(100)
  @IsOptional()
  grasa_subcutanea_pct?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  grasa_visceral?: number;

  @IsInt()
  @Min(0)
  @IsOptional()
  tmb_kcal?: number;

  @IsInt()
  @Min(0)
  @Max(120)
  @IsOptional()
  edad_corporal?: number;

  @IsNumber()
  @Min(20)
  @Max(400)
  @IsOptional()
  peso_ideal_kg?: number;

  @IsString()
  @MaxLength(2000)
  @IsOptional()
  notas?: string;
}
