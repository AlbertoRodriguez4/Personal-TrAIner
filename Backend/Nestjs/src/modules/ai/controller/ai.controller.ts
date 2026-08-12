import { Body, Controller, Post } from '@nestjs/common';
import { AnalyzeNutritionDto } from '../dto/analyze-nutrition.dto';

import { AiChatDto } from '../dto/chat.dto';
import { AiService } from '../service/ai.service';

@Controller('ai')
export class AiController {
  constructor(private readonly aiService: AiService) {}

  @Post('analizar-nutricion')
  analyzeNutrition(@Body() dto: AnalyzeNutritionDto) {
    return this.aiService.analyzeNutrition(dto);
  }


  @Post('chat')
  chat(@Body() dto: AiChatDto) {
    return this.aiService.chat(dto);
  }
}

