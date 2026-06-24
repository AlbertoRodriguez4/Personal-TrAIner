import { IsNotEmpty, IsString, IsOptional, IsUUID } from 'class-validator';

export class AnalyzeNutritionDto {
  @IsString()
  @IsNotEmpty({ message: 'La imagen en base64 es obligatoria.' })
  image_base64: string;

  @IsString()
  @IsNotEmpty({ message: 'El prompt es obligatorio.' })
  prompt: string;

  @IsOptional()
  @IsUUID('4')
  user_id?: string;
}
