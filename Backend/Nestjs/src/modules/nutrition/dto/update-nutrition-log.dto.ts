import { IsDateString, IsInt, IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class UpdateNutritionLogDto {
  @IsUUID()
  @IsOptional()
  userId?: string;

  @IsDateString()
  @IsOptional()
  fecha_registro?: string;

  @IsInt()
  @Min(0)
  @IsOptional()
  calorias_consumidas?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  proteinas_g?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  carbohidratos_g?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  grasas_g?: number;

  @IsString()
  @IsOptional()
  notas?: string;
}
