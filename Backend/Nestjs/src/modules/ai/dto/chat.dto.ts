export class ChatTurnDto {
  role: 'user' | 'model';
  text: string;
}

export class AiChatDto {
  userId: string;
  mode: string;
  message: string;
  history?: ChatTurnDto[];
  healthContext?: Record<string, unknown>;
  images?: string[];
}
