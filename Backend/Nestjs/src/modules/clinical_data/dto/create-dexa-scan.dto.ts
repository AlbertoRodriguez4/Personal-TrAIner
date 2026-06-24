import { IsDateString, IsNotEmpty, IsNumber, IsUUID, Max, Min } from 'class-validator';

export class CreateDexaScanDto {
  @IsUUID()
  @IsNotEmpty()
  userId: string;

  @IsDateString()
  @IsNotEmpty()
  fecha_escaneo: string;

  @IsNumber()
  @Min(0)
  @Max(100)
  porcentaje_grasa: number;

  @IsNumber()
  @Min(0)
  masa_muscular_kg: number;

  @IsNumber()
  @Min(0)
  densidad_osea: number;
}
