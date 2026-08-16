import { IsString, IsOptional } from 'class-validator';

export class CreateSupplementDto {
  @IsString()
  userId: string;

  @IsString()
  nombre: string;

  @IsOptional()
  @IsString()
  dosis?: string;
}
