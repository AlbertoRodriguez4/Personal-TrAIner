import { IsNotEmpty, IsOptional, IsString, IsUUID } from 'class-validator';

export class AnalyzeRoutineDto {
  @IsUUID()
  @IsNotEmpty()
  user_id: string;

  @IsString()
  @IsOptional()
  prompt?: string;

  @IsString()
  @IsOptional()
  routine_id?: string;
}
