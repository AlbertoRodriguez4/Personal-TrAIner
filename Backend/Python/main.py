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


# Los handlers de abajo son `def` y NO `async def` a propósito, y volver a
# ponerles el `async` es el fallo que más caro sale aquí: todos hacen I/O
# bloqueante (requests a USDA/Open Food Facts/NestJS, y el SDK de Gemini/Groq
# dentro de run_chat), y un `async def` corre EN el event loop. Con `async`,
# una sola estimación de comida —que el formulario manual dispara CADA 500 ms
# mientras el usuario teclea, y que puede tardar lo que tarden las dos APIs
# externas— dejaba clavado el servicio ENTERO mientras tanto: el chat de IA,
# el análisis clínico y hasta el /health de otro usuario esperaban su turno.
# Sin `async`, Starlette los ejecuta en su threadpool y se atienden en
# paralelo. Los que sí pueden ser async son los que no tocan I/O: /health y el
# middleware, que necesita el await de call_next.

@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/ai/analyze-set")
def analyze_set(data: SetTelemetryInput):
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
    GroqQuotaExhaustedError,
    RespuestaDemasiadoGrandeError,
)
from schemas import ChatRequest, ChatResponse

@app.post("/api/ia/chat", response_model=ChatResponse)
def chat(request: ChatRequest):
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
        # Modos con imagen (nutricion, analisis_fisico): sin fallback a otro modelo,
        # mensaje explícito de qué no se pudo hacer en vez del genérico de Groq.
        raise HTTPException(
            status_code=503,
            detail="No pude analizar la imagen ahora mismo (servicio de IA saturado). Probá de nuevo en un par de minutos.",
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
    if isinstance(exc, GeminiQuotaExhaustedError):
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
def analyze_clinical_report(request: ClinicalReportRequest):
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
def analyze_clinical_manual(request: ClinicalManualRequest):
    try:
        return clinical_analysis.analizar_valores_manuales(
            user_id=request.user_id,
            valores=[v.model_dump() for v in request.valores],
            fecha=request.fecha,
        )
    except Exception as e:
        raise _traducir_error_analisis(e)


@app.post("/api/ia/body-composition")
def register_body_composition(request: BodyCompositionRequest):
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
def analyze_physique(request: PhysiqueAnalysisRequest):
    try:
        return physique_analysis.analizar_fotos(
            user_id=request.user_id,
            fotos=[p.model_dump() for p in request.photos],
            notas=request.notas,
        )
    except Exception as e:
        raise _traducir_error_analisis(e)


@app.post("/api/ia/nutrition/food-estimate")
def estimate_food(request: FoodEstimateRequest):
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
def suggest_foods(request: FoodSuggestionsRequest):
    return {"sugerencias": food_lookup.sugerir(request.query)}
