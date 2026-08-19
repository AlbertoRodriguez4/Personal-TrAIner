import { IsString, IsOptional, IsBoolean } from 'class-validator';

export class UpdateSupplementDto {
  @IsOptional()
  @IsString()
  nombre?: string;

  @IsOptional()
  @IsString()
  dosis?: string;

  @IsOptional()
  @IsBoolean()
  activo?: boolean;
}
