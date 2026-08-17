import { BadGatewayException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AiChatDto } from '../dto/chat.dto';
import {
  BodyCompositionDto,
  ClinicalDocumentDto,
  ClinicalManualDto,
  PhysiqueAnalysisDto,
} from '../dto/analysis.dto';

@Injectable()
export class AiService {
  constructor(private readonly configService: ConfigService) {}

  private get pythonBaseUrl(): string {
    return this.configService.get<string>('AI_PYTHON_URL') ?? 'http://127.0.0.1:8000';
  }

  /// El análisis de un PDF clínico encadena varias llamadas al modelo más
  /// consultas a MedlinePlus, así que tarda bastante más que un turno de chat:
  /// sin timeout propio, el `fetch` por defecto de Node corta antes de tiempo y
  /// el usuario ve un fallo sobre un análisis que en realidad sí terminó.
  private async post<T>(path: string, body: unknown, timeoutMs = 120_000): Promise<T> {
    const endpoint = new URL(path, this.pythonBaseUrl).toString();

    let response: Response;
    try {
      response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (error) {
      const detalle = error instanceof Error ? error.message : String(error);
      throw new BadGatewayException(
        `No se pudo contactar con el servicio Python de IA: ${detalle}`,
      );
    }

    if (!response.ok) {
      const errorBody = await response.text();
      throw new BadGatewayException(
        `Error al comunicarse con el servicio Python (${response.status}): ${errorBody}`,
      );
    }

    return response.json() as Promise<T>;
  }

  async chat(payload: AiChatDto): Promise<{ reply: string; actions_taken: unknown[] }> {
    const path = this.configService.get<string>('AI_PYTHON_CHAT_PATH') ?? '/api/ia/chat';
    return this.post(path, {
      user_id: payload.userId,
      mode: payload.mode,
      message: payload.message,
      history: (payload.history ?? []).map((h) => ({ role: h.role, text: h.text })),
      health_context: payload.healthContext ?? null,
      images: payload.images ?? [],
    });
  }

  async analyzeClinicalDocument(payload: ClinicalDocumentDto) {
    return this.post('/api/ia/clinical-report', {
      user_id: payload.userId,
      data: payload.data,
      mime_type: payload.mimeType,
      file_name: payload.fileName ?? null,
    });
  }

  async analyzeClinicalManual(payload: ClinicalManualDto) {
    return this.post('/api/ia/clinical-manual', {
      user_id: payload.userId,
      valores: payload.valores ?? [],
      fecha: payload.fecha ?? null,
    });
  }

  /// Timeout corto a propósito: esta ruta no llama a ningún modelo, solo guarda
  /// la medición y la clasifica contra tablas. Si tarda 15 s es que algo va mal,
  /// no que "está pensando".
  async registerBodyComposition(payload: BodyCompositionDto) {
    return this.post(
      '/api/ia/body-composition',
      {
        user_id: payload.userId,
        fecha: payload.fecha ?? null,
        metodo: payload.metodo ?? null,
        peso_kg: payload.pesoKg ?? null,
        porcentaje_grasa: payload.porcentajeGrasa ?? null,
        masa_muscular_kg: payload.masaMuscularKg ?? null,
        musculo_esqueletico_pct: payload.musculoEsqueleticoPct ?? null,
        masa_osea_kg: payload.masaOseaKg ?? null,
        densidad_osea: payload.densidadOsea ?? null,
        proteina_kg: payload.proteinaKg ?? null,
        agua_corporal_kg: payload.aguaCorporalKg ?? null,
        agua_corporal_pct: payload.aguaCorporalPct ?? null,
        grasa_subcutanea_pct: payload.grasaSubcutaneaPct ?? null,
        grasa_visceral: payload.grasaVisceral ?? null,
        tmb_kcal: payload.tmbKcal ?? null,
        edad_corporal: payload.edadCorporal ?? null,
        peso_ideal_kg: payload.pesoIdealKg ?? null,
        notas: payload.notas ?? null,
      },
      15_000,
    );
  }

  async analyzePhysique(payload: PhysiqueAnalysisDto) {
    return this.post('/api/ia/physique-analysis', {
      user_id: payload.userId,
      photos: (payload.photos ?? []).map((p) => ({
        data: p.data,
        mime_type: p.mimeType,
        angulo: p.angulo ?? 'otro',
      })),
      notas: payload.notas ?? null,
    });
  }
}
