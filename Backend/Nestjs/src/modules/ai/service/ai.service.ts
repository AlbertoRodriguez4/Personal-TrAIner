import { BadGatewayException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AiChatDto } from '../dto/chat.dto';

@Injectable()
export class AiService {
  constructor(private readonly configService: ConfigService) {}

  async chat(payload: AiChatDto): Promise<{ reply: string; actions_taken: unknown[] }> {
    const baseUrl = this.configService.get<string>('AI_PYTHON_URL') ?? 'http://127.0.0.1:8000';
    const path = this.configService.get<string>('AI_PYTHON_CHAT_PATH') ?? '/api/ia/chat';
    const endpoint = new URL(path, baseUrl).toString();

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        user_id: payload.userId,
        mode: payload.mode,
        message: payload.message,
        history: (payload.history ?? []).map((h) => ({ role: h.role, text: h.text })),
        health_context: payload.healthContext ?? null,
        images: payload.images ?? [],
      }),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      throw new BadGatewayException(
        `Error al comunicarse con el servicio Python (${response.status}): ${errorBody}`,
      );
    }

    return response.json() as Promise<{ reply: string; actions_taken: unknown[] }>;
  }
}
