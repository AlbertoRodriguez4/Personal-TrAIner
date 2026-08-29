from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from nest_client import INTERNAL_API_KEY
from schemas import SetTelemetryInput
from skills import analyze_failure
# Inicializamos la API
app = FastAPI()

# CORS abierto
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Cuando este servicio corre en un host propio (Hugging Face Spaces, etc.) en
# vez de en la red interna de Docker, su puerto queda público: sin este check,
# cualquiera que encuentre la URL podría llamar a estos endpoints con el
# user_id que quisiera y leer o escribir los datos de cualquier usuario (ver
# el aviso en nest_client.py, escrito para exactamente este escenario).
# /health se deja fuera a propósito: lo llama un monitor externo (UptimeRobot/
# cron-job.org) sin credenciales, y no expone nada sensible.
@app.middleware("http")
async def verificar_clave_interna(request: Request, call_next):
    if request.url.path == "/health":
        return await call_next(request)
    if not INTERNAL_API_KEY or request.headers.get("x-internal-key") != INTERNAL_API_KEY:
        return JSONResponse(status_code=401, content={"detail": "No autorizado"})
    return await call_next(request)


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/ai/analyze-set")
async def analyze_set(data: SetTelemetryInput):
    try:
        return analyze_failure(data)
    except ValueError as e:
        raise HTTPException(status_code=500, detail=f"Formato inválido: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Para ejecutar: uvicorn main:app --reload --port 8000

from chat_engine import (
    run_chat,
    GeminiQuotaExhaustedError,
    GeminiSobrecargadoError,
    GroqQuotaExhaustedError,
    RespuestaDemasiadoGrandeError,
)
from schemas import ChatRequest, ChatResponse

@app.post("/api/ia/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    try:
        result = run_chat(
            user_id=request.user_id,
            mode=request.mode,
            message=request.message,
            history=[t.model_dump() for t in request.history],
            health_context=request.health_context,
            images=[i.model_dump(by_alias=False) for i in request.images],
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except RespuestaDemasiadoGrandeError:
        # 413: el pedido no cabe en el presupuesto de tokens del tier gratuito de Groq.
        # No es transitorio — reintentar lo mismo vuelve a fallar — así que el mensaje
        # tiene que pedirle al usuario algo concreto, no "probá de nuevo".
        raise HTTPException(
            status_code=413,
            detail=(
                "La respuesta se pasa de tamaño para el modelo. Probá pidiendo algo más "
                "acotado: menos días por rutina, o menos ejercicios por día."
            ),
        )
    except GeminiQuotaExhaustedError:
        # Modos de Gemini (nutricion, analisis_fisico): mensaje explícito de qué no se
        # pudo hacer en vez del genérico de Groq. Ya no dice "la imagen" porque
        # nutrición también estima comidas descritas por escrito, sin foto ninguna.
        raise HTTPException(
            status_code=503,
            detail="No pude analizarlo ahora mismo: se agotó la cuota del servicio de IA. Probá de nuevo en un par de minutos.",
        )
    except GeminiSobrecargadoError:
        # 503 de Google, no de nuestra cuota: el modelo está saturado. El detalle crudo
        # que devolvía antes ("503 UNAVAILABLE. {'error': {'code': 503…") acababa
        # entero en un aviso dentro de la app, sin decirle al usuario qué hacer.
        raise HTTPException(
            status_code=503,
            detail="El modelo de IA está saturado ahora mismo. Vuelve a intentarlo en un minuto.",
        )
    except GroqQuotaExhaustedError:
        raise HTTPException(status_code=503, detail="Servicio de IA saturado, probá de nuevo en unos segundos")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# Análisis de una sola pasada (documento clínico / fotos del físico)
# ============================================================
# No pasan por el motor de chat: no hay conversación, hay un formulario que
# rellenar y persistir. Comparten la traducción de errores porque los dos
# terminan en el mismo sitio (Gemini + NestJS) y fallan por lo mismo.

import body_composition
import clinical_analysis
import food_lookup
import physique_analysis
from gemini_client import RespuestaJsonInvalidaError
from nest_client import NestApiError
from schemas import (
    BodyCompositionRequest,
    ClinicalManualRequest,
    ClinicalReportRequest,
    FoodEstimateRequest,
    FoodSuggestionsRequest,
    PhysiqueAnalysisRequest,
)


def _traducir_error_analisis(exc: Exception) -> HTTPException:
    if isinstance(exc, (
        clinical_analysis.DocumentoNoSoportadoError,
        physique_analysis.FotoNoSoportadaError,
        physique_analysis.FotosNoAnalizablesError,
        ValueError,
    )):
        return HTTPException(status_code=400, detail=str(exc))
    if isinstance(exc, (GeminiQuotaExhaustedError, GeminiSobrecargadoError)):
        return HTTPException(
            status_code=503,
            detail="No pude analizarlo ahora mismo (servicio de IA saturado). Probá de nuevo en un par de minutos.",
        )
    if isinstance(exc, RespuestaJsonInvalidaError):
        # El modelo no respetó el schema. Reintentar lo mismo suele funcionar, a
        # diferencia de un 413, así que el mensaje sí invita a repetir.
        return HTTPException(
            status_code=502,
            detail="El análisis salió incompleto. Probá de nuevo; si el archivo es una foto, que se lea bien el texto.",
        )
    if isinstance(exc, NestApiError):
        return HTTPException(
            status_code=502,
            detail=f"El análisis se hizo pero no se pudo guardar ({exc.status_code}). Probá de nuevo.",
        )
    return HTTPException(status_code=500, detail=str(exc))


@app.post("/api/ia/clinical-report")
async def analyze_clinical_report(request: ClinicalReportRequest):
    try:
        return clinical_analysis.analizar_documento(
            user_id=request.user_id,
            data_b64=request.data,
            mime_type=request.mime_type,
            file_name=request.file_name,
        )
    except Exception as e:
        raise _traducir_error_analisis(e)


@app.post("/api/ia/clinical-manual")
async def analyze_clinical_manual(request: ClinicalManualRequest):
    try:
        return clinical_analysis.analizar_valores_manuales(
            user_id=request.user_id,
            valores=[v.model_dump() for v in request.valores],
            fecha=request.fecha,
        )
    except Exception as e:
        raise _traducir_error_analisis(e)


@app.post("/api/ia/body-composition")
async def register_body_composition(request: BodyCompositionRequest):
    """Guarda una medición de composición corporal y devuelve su lectura.

    No pasa por ningún modelo: son cifras medidas y la clasificación sale de
    tablas citadas (ACE, OMS, Kouri). Va por aquí y no directo a NestJS para que
    esas tablas vivan en un único sitio y la pantalla enseñe exactamente los
    mismos tramos que después lee Pulso."""
    datos = request.model_dump(exclude_none=True)
    medidas = {
        clave: valor
        for clave, valor in datos.items()
        if clave not in ("user_id", "fecha", "metodo", "notas")
    }
    try:
        return body_composition.registrar(
            user_id=request.user_id,
            medidas=medidas,
            fecha=request.fecha,
            metodo=request.metodo,
            notas=request.notas,
        )
    except body_composition.ValorFueraDeRangoError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise _traducir_error_analisis(e)


@app.post("/api/ia/physique-analysis")
async def analyze_physique(request: PhysiqueAnalysisRequest):
    try:
        return physique_analysis.analizar_fotos(
            user_id=request.user_id,
            fotos=[p.model_dump() for p in request.photos],
            notas=request.notas,
        )
    except Exception as e:
        raise _traducir_error_analisis(e)


@app.post("/api/ia/nutrition/food-estimate")
async def estimate_food(request: FoodEstimateRequest):
    """Registro manual de comida (nutricion, sin foto): busca el alimento por
    nombre y escala sus macros a la cantidad pedida. No guarda nada — igual que
    estimar_comida en el chat, es la app la que llama a /nutrition-logs cuando
    el usuario confirma."""
    try:
        return food_lookup.estimar(
            nombre_alimento=request.nombre_alimento,
            cantidad_g=request.cantidad_g,
            referencia_unidad=request.referencia_unidad,
            referencia_cantidad=request.referencia_cantidad or 1.0,
        )
    except food_lookup.AlimentoNoEncontradoError as e:
        raise HTTPException(
            status_code=404,
            detail=f"No encontramos '{e}' en ninguna fuente nutricional. Probá con otro nombre o usa gramos con un alimento parecido.",
        )
    except food_lookup.ReferenciaNoDisponibleError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/ia/nutrition/food-suggestions")
async def suggest_foods(request: FoodSuggestionsRequest):
    return {"sugerencias": food_lookup.sugerir(request.query)}
