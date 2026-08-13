import { Body, Controller, Post } from '@nestjs/common';

import { AiChatDto } from '../dto/chat.dto';
import { AiService } from '../service/ai.service';

@Controller('ai')
export class AiController {
  constructor(private readonly aiService: AiService) {}

  @Post('chat')
  chat(@Body() dto: AiChatDto) {
    return this.aiService.chat(dto);
  }
}

