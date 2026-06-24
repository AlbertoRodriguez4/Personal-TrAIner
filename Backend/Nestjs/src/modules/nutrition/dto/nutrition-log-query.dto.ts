import { IsDateString, IsOptional } from 'class-validator';

export class NutritionLogQueryDto {
  @IsDateString()
  @IsOptional()
  startDate?: string;

  @IsDateString()
  @IsOptional()
  endDate?: string;
}
