import { IsDateString, IsIn, IsInt, IsNotEmpty, IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';

const TIPOS_COMIDA = ['desayuno', 'comida', 'snack', 'cena', 'otro'];

export class CreateNutritionLogDto {
  @IsUUID()
  @IsNotEmpty()
  userId: string;

  @IsDateString()
  @IsNotEmpty()
  fecha_registro: string;

  @IsInt()
  @Min(0)
  calorias_consumidas: number;

  @IsNumber()
  @Min(0)
  proteinas_g: number;

  @IsNumber()
  @Min(0)
  carbohidratos_g: number;

  @IsNumber()
  @Min(0)
  grasas_g: number;

  @IsString()
  @IsOptional()
  notas?: string;

  @IsIn(TIPOS_COMIDA)
  @IsOptional()
  tipo_comida?: string;

  @IsString()
  @IsOptional()
  nombre_alimento?: string;
}
