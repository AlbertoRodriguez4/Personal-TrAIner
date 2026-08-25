import { BadGatewayException, HttpException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AiChatDto } from '../dto/chat.dto';
import {
  BodyCompositionDto,
  ClinicalDocumentDto,
  ClinicalManualDto,
  FoodEstimateDto,
  FoodSuggestionsDto,
  PhysiqueAnalysisDto,
} from '../dto/analysis.dto';

@Injectable()
export class AiService {
  /// Esperas entre reintentos ante un 429, en ms; su longitud fija cuántos hay.
  /// Escalonadas y cortas: el limitador que las provoca es de ventana corta, y
  /// al otro lado hay un usuario mirando una pantalla de carga con la foto ya
  /// hecha, así que el turno de chat ya se lleva lo suyo. Dos reintentos es el
  /// techo razonable — a partir de ahí se tarda más en insistir que en que el
  /// usuario le dé otra vez al botón.
  private static readonly ESPERAS_429_MS = [1_500, 4_000];

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

    // Cuando Python vive en un host propio (no en la red interna de Docker),
    // su puerto queda público: sin esta clave, cualquiera que encuentre la URL
    // podría llamar a sus endpoints directamente con el user_id que quisiera.
    // Python la exige en todas sus rutas salvo /health (ver main.py).
    const claveInterna = this.configService.get<string>('INTERNAL_API_KEY');

    const peticion = (): Promise<Response> =>
      fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(claveInterna ? { 'X-Internal-Key': claveInterna } : {}),
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(timeoutMs),
      });

    let response: Response;
    // Un 429 aquí no lo escribe FastAPI: el servicio Python no emite ese código
    // en ninguna ruta (la cuota agotada de Gemini/Groq se traduce a 503 en
    // main.py). Lo escribe el proxy que hay delante cuando esta llamada sale a
    // la red pública, y el limitador va por IP de origen — que en Render es una
    // IP de salida COMPARTIDA con otros clientes (74.220.48.0/20, registrada a
    // Render en ARIN). O sea: podemos comernos un 429 por tráfico que no es
    // nuestro. Reintentar es seguro justamente porque el 429 significa que la
    // petición nunca llegó a la app: no hay medio análisis hecho ni nada escrito
    // en base de datos que se pudiera duplicar.
    //
    // Esto es una tirita, no el arreglo: la solución es que AI_PYTHON_URL
    // apunte a la dirección interna del servicio Python (como ya hace
    // docker-compose.yml con http://ia:8000) para no pasar por el proxy.
    for (let intento = 0; ; intento++) {
      try {
        response = await peticion();
      } catch (error) {
        const detalle = error instanceof Error ? error.message : String(error);
        throw new BadGatewayException(
          `No se pudo contactar con el servicio Python de IA: ${detalle}`,
        );
      }
      const espera = AiService.ESPERAS_429_MS[intento];
      if (response.status !== 429 || espera === undefined) break;
      await new Promise((listo) => setTimeout(listo, espera));
    }

    if (!response.ok) {
      throw AiService.traducirFallo(response.status, await response.text());
    }

    return response.json() as Promise<T>;
  }


  /// El texto que salga de aquí acaba tal cual en un SnackBar del móvil: la app
  /// hace `throw Exception(<mensaje del backend>)` y lo pinta. Volcar el cuerpo
  /// crudo de la respuesta le enseñaba al usuario cosas como
  /// "Error al comunicarse con el servicio Python (429): Too Many Requests",
  /// que además atribuye a nuestro servicio un 429 que en realidad emite el
  /// proxy (Render/Cloudflare) que hay delante de Python, antes de que la
  /// petición llegue a FastAPI: nuestro código nunca devuelve 429 — la cuota
  /// agotada de Gemini/Groq se traduce a 503 en main.py.
  ///
  /// Python ya redacta mensajes pensados para el usuario en `detail`; lo que
  /// faltaba es sacarlos de ahí y conservar el significado del código de estado
  /// en vez de aplastarlo todo a 502.
  private static traducirFallo(status: number, cuerpo: string): HttpException {
    const detalle = AiService.extraerDetalle(cuerpo);

    // 429 (rate limit del proxy) y 503 (cuota de LLM agotada) son lo mismo para
    // quien está delante del móvil: transitorio, se arregla esperando.
    if (status === 429 || status === 503) {
      return new HttpException(
        detalle ??
          'El servicio de IA está saturado ahora mismo. Prueba de nuevo en un par de minutos.',
        503,
      );
    }

    // 400 (petición inválida) y 413 (no cabe en el presupuesto de tokens) traen
    // instrucciones concretas escritas en Python; reintentar no las arregla.
    if (status === 400 || status === 413) {
      return new HttpException(detalle ?? 'La petición no se pudo procesar.', status);
    }

    return new BadGatewayException(detalle ?? `El servicio de IA falló (${status}).`);
  }

  /// FastAPI empaqueta sus errores como {"detail": "..."}; el proxy que hay
  /// delante responde texto plano ("Too Many Requests"), que no aporta nada.
  private static extraerDetalle(cuerpo: string): string | null {
    try {
      const json: unknown = JSON.parse(cuerpo);
      const detail = (json as { detail?: unknown } | null)?.detail;
      if (typeof detail === 'string' && detail.trim()) return detail.trim();
    } catch {
      // No era JSON: el cuerpo lo escribió el proxy, no la app.
    }
    return null;
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

  /// Timeout corto a propósito, igual que registerBodyComposition: es una
  /// búsqueda en catálogo + una regla de tres, no una llamada a un modelo.
  async estimateFood(payload: FoodEstimateDto) {
    return this.post(
      '/api/ia/nutrition/food-estimate',
      {
        user_id: payload.userId,
        nombre_alimento: payload.nombreAlimento,
        cantidad_g: payload.cantidadG ?? null,
        referencia_unidad: payload.referenciaUnidad ?? null,
        referencia_cantidad: payload.referenciaCantidad ?? null,
      },
      15_000,
    );
  }

  /// Timeout corto: solo filtra el catálogo local en memoria, nunca sale a
  /// USDA/Open Food Facts — si tarda más de eso, algo va mal.
  async suggestFoods(payload: FoodSuggestionsDto) {
    return this.post('/api/ia/nutrition/food-suggestions', { query: payload.query }, 5_000);
  }
}
