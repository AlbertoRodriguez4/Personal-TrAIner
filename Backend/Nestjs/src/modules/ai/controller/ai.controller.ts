import { Body, Controller, Post } from '@nestjs/common';
import { AnalyzeNutritionDto } from '../dto/analyze-nutrition.dto';
import { AnalyzeRoutineDto } from '../dto/analyze-routine.dto';
import { AnalyzeBodyDto } from '../dto/analyze-body.dto';
import { AiService } from '../service/ai.service';

@Controller('ai')
export class AiController {
  constructor(private readonly aiService: AiService) {}

  @Post('analizar-nutricion')
  analyzeNutrition(@Body() dto: AnalyzeNutritionDto) {
    return this.aiService.analyzeNutrition(dto);
  }

  @Post('analizar-rutina')
  analyzeRoutine(@Body() dto: AnalyzeRoutineDto) {
    return this.aiService.analyzeRoutine(dto);
  }

  @Post('analizar-fisico')
  analyzeBody(@Body() dto: AnalyzeBodyDto) {
    return this.aiService.analyzeBody(dto);
  }
}

