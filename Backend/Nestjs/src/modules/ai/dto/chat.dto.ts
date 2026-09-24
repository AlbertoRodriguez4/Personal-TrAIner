import { IsArray, IsNotEmpty, IsObject, IsOptional, IsString } from 'class-validator';

export class ChatTurnDto {
  role: 'user' | 'model';
  text: string;
}

/// Cada campo lleva al menos un decorador porque el ValidationPipe global va con
/// `whitelist`: lo que no esté declarado se descarta antes de llegar aquí. Las
/// listas se validan como listas y nada más — `AiService` ya copia solo los
/// campos que Python lee, y validar cada turno del historial rechazaría una
/// conversación entera por un turno raro.
export class AiChatDto {
  @IsString()
  @IsNotEmpty()
  userId: string;

  @IsString()
  mode: string;

  @IsString()
  message: string;

  @IsOptional()
  @IsArray()
  history?: ChatTurnDto[];

  @IsOptional()
  @IsObject()
  healthContext?: Record<string, unknown>;

  @IsOptional()
  @IsArray()
  images?: { data: string; mimeType: string }[];
}
