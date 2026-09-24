import { BadGatewayException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TelemetryDto } from '../dto/telemetry.dto';

type AiSetResponse = {
  rir_estimado: number;
  pendiente_ataque?: number;
  plateau_index?: number;
  pico_bpm?: number;
  media_bpm?: number;
  zona?: string;
  feedback: string;
};

@Injectable()
export class TelemetryService {
  constructor(private readonly configService: ConfigService) {}

  async analyzeHrSet(dto: TelemetryDto): Promise<AiSetResponse> {
    const baseUrl = this.configService.get<string>('AI_PYTHON_URL') ?? 'http://127.0.0.1:8000';
    const path = this.configService.get<string>('AI_PYTHON_SET_PATH') ?? '/ai/analyze-set';
    const endpoint = new URL(path, baseUrl).toString();

    // Python exige esta clave en todas sus rutas salvo /health (ver
    // verificar_clave_interna en main.py). Sin ella la respuesta era siempre un
    // 401 "No autorizado", y el análisis de cada serie en vivo fallaba con 502.
    const claveInterna = this.configService.get<string>('INTERNAL_API_KEY');

    let response: Response;
    try {
      response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(claveInterna ? { 'X-Internal-Key': claveInterna } : {}),
        },
        body: JSON.stringify({
          uid: dto.uid,
          eid: dto.eid,
          dur: dto.dur,
          hr: dto.hr,
        }),
        // Es una heurística sobre la curva de pulso, sin modelo de por medio: si
        // tarda más que esto es que algo va mal, y al otro lado hay alguien entre
        // series esperando el resultado.
        signal: AbortSignal.timeout(15_000),
      });
    } catch (error) {
      // Timeout o Python caído: sin esto `fetch` lanzaba y salía un 500 genérico.
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

    const decoded = (await response.json()) as unknown;
    if (!this.isAiSetResponse(decoded)) {
      throw new BadGatewayException('La respuesta del servicio Python no tiene el formato esperado.');
    }

    return decoded;
  }

  private isAiSetResponse(value: unknown): value is AiSetResponse {
    if (!value || typeof value !== 'object') return false;
    const c = value as Partial<AiSetResponse>;
    return (
      typeof c.rir_estimado === 'number' && typeof c.feedback === 'string'
    );
  }
}