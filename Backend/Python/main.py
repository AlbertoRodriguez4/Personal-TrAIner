from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
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
