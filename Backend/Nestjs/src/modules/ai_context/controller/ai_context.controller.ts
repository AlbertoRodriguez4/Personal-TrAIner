import { Controller, Get, Param } from '@nestjs/common';
import { AiContextService } from '../service/ai_context.service';

@Controller('ai-context')
export class AiContextController {
  constructor(private readonly aiContextService: AiContextService) {}

  @Get(':userId')
  build(@Param('userId') userId: string) {
    return this.aiContextService.build(userId);
  }
}
