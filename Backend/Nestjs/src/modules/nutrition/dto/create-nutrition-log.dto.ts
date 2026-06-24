import { IsDateString, IsInt, IsNotEmpty, IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';

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
}
