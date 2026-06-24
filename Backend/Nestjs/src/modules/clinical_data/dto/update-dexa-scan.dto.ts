import { IsDateString, IsNumber, IsOptional, IsUUID, Max, Min } from 'class-validator';

export class UpdateDexaScanDto {
  @IsUUID()
  @IsOptional()
  userId?: string;

  @IsDateString()
  @IsOptional()
  fecha_escaneo?: string;

  @IsNumber()
  @Min(0)
  @Max(100)
  @IsOptional()
  porcentaje_grasa?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  masa_muscular_kg?: number;

  @IsNumber()
  @Min(0)
  @IsOptional()
  densidad_osea?: number;
}
