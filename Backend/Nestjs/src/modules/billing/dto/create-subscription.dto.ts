import { IsDateString, IsIn, IsNotEmpty, IsString, IsUUID } from 'class-validator';

export class CreateSubscriptionDto {
  @IsUUID()
  @IsNotEmpty()
  userId: string;

  @IsString()
  @IsIn(['mensual', 'anual'])
  plan: string;

  @IsString()
  @IsIn(['activa', 'cancelada', 'vencida'])
  estado: string;

  @IsDateString()
  @IsNotEmpty()
  fecha_inicio: string;

  @IsDateString()
  @IsNotEmpty()
  fecha_fin: string;
}
