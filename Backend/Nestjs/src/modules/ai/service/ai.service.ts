import { BadGatewayException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AnalyzeNutritionDto } from '../dto/analyze-nutrition.dto';
import { UserProfile } from '../../user_profile/entities/user_profile.entity';
import { AiChatDto } from '../dto/chat.dto';

type NutritionAiResponse = {
  calorias_consumidas: number;
  proteinas_g: number;
  carbohidratos_g: number;
  grasas_g: number;
  notas: string;
};



@Injectable()
export class AiService {
  constructor(
    private readonly configService: ConfigService,
    @InjectRepository(UserProfile)
    private readonly profileRepository: Repository<UserProfile>,
  ) {}

  async analyzeNutrition(payload: AnalyzeNutritionDto): Promise<NutritionAiResponse> {
    const baseUrl = this.configService.get<string>('AI_PYTHON_URL') ?? 'http://127.0.0.1:8000';
    const path = this.configService.get<string>('AI_PYTHON_NUTRITION_PATH') ?? '/api/ia/analizar-nutricion';
    const endpoint = new URL(path, baseUrl).toString();

    let userProfile: UserProfile | null = null;
    if (payload.user_id) {
      userProfile = await this.profileRepository.findOne({
        where: { user_id: payload.user_id },
      });
    }

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        image_base64: payload.image_base64,
        prompt: payload.prompt,
        user_profile: userProfile ? this.serializeProfile(userProfile) : null,
      }),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      throw new BadGatewayException(
        `Error al comunicarse con el servicio Python (${response.status}): ${errorBody}`,
      );
    }

    const decoded = (await response.json()) as unknown;
    if (!this.isNutritionAiResponse(decoded)) {
      throw new BadGatewayException(
        'La respuesta del servicio Python no tiene el formato esperado.',
      );
    }

    return decoded;
  }

  private serializeProfile(profile: UserProfile): Record<string, unknown> {
    return {
      dias_entrenamiento_semana: profile.dias_entrenamiento_semana,
      intensidad: profile.intensidad,
      nivel_experiencia: profile.nivel_experiencia,
      objetivos: profile.objetivos,
      tipo_cuerpo: profile.tipo_cuerpo,
      condiciones_medicas: profile.condiciones_medicas,
      bmi: profile.bmi,
      dexa_porcentaje_grasa: profile.dexa_porcentaje_grasa,
      dexa_masa_muscular_kg: profile.dexa_masa_muscular_kg,
      notas_adicionales: profile.notas_adicionales,
    };
  }

  private isNutritionAiResponse(value: unknown): value is NutritionAiResponse {
    if (!value || typeof value !== 'object') {
      return false;
    }

    const candidate = value as Partial<NutritionAiResponse>;
    return (
      typeof candidate.calorias_consumidas === 'number' &&
      typeof candidate.proteinas_g === 'number' &&
      typeof candidate.carbohidratos_g === 'number' &&
      typeof candidate.grasas_g === 'number' &&
      typeof candidate.notas === 'string'
    );
  }



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
