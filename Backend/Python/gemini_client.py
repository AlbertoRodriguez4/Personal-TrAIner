"""Cliente Gemini compartido: configuración, reintentos ante 429 y salida JSON
estructurada. Vive aparte de `chat_engine.py` porque los análisis de una sola
pasada (documento clínico, fotos del físico) necesitan exactamente la misma
política de reintentos y de modelo, y duplicarla ahí garantizaba que las dos
copias se separasen en la primera corrección que se hiciera en una sola.

`chat_engine` reexporta `GeminiQuotaExhaustedError` para que `main.py` la siga
importando desde donde siempre.
"""
import json
import os
import time

from google import genai
from google.genai import errors as genai_errors
from google.genai import types


def _env(nombre: str, default: str = "") -> str:
    """os.environ.get(nombre, default) NO aplica el default cuando la variable existe
    pero está vacía (`GEMINI_MODEL=` en el .env devuelve "", no el default) — y un
    model="" llega a la API de Gemini como un 400 "falta especificar el modelo".
    Este helper trata vacío y ausente por igual."""
    return (os.environ.get(nombre) or default).strip()


GEMINI_MODEL = _env("GEMINI_MODEL", "gemini-3.5-flash-lite")
GEMINI_MODEL_FALLBACK = _env("GEMINI_MODEL_FALLBACK")

RETRY_ATTEMPTS = 3
RETRY_BACKOFF_SECONDS = (1, 2)  # pausas entre los intentos 1→2 y 2→3; nada de esperas largas
                                 # que bloqueen el request HTTP por mucho tiempo

client = genai.Client(api_key=_env("GEMINI_API_KEY"))


class LLMProviderExhaustedError(Exception):
    """Base: un proveedor de LLM agotó los reintentos ante 429/rate-limit sostenido."""


class GeminiQuotaExhaustedError(LLMProviderExhaustedError):
    """Gemini agotó los reintentos: 429/RESOURCE_EXHAUSTED sostenido (cuota de la API)."""


def _is_quota_error(exc: genai_errors.ClientError) -> bool:
    return exc.code == 429 or exc.status == "RESOURCE_EXHAUSTED"


def _generate_with_retry(contents, config, model: str):
    """generate_content con hasta RETRY_ATTEMPTS intentos cuando Gemini devuelve 429.
    Cualquier otro error (4xx distinto, red) no reintenta y sube tal cual."""
    last_exc = None
    for attempt in range(RETRY_ATTEMPTS):
        try:
            return client.models.generate_content(model=model, contents=contents, config=config)
        except genai_errors.ClientError as exc:
            if not _is_quota_error(exc):
                raise
            last_exc = exc
            if attempt < RETRY_ATTEMPTS - 1:
                time.sleep(RETRY_BACKOFF_SECONDS[attempt])
    raise GeminiQuotaExhaustedError(str(last_exc)) from last_exc


def generate(contents, config):
    """Reintenta contra GEMINI_MODEL; si agota cuota y hay GEMINI_MODEL_FALLBACK
    configurado, hace un único intento adicional contra ese modelo antes de rendirse."""
    try:
        return _generate_with_retry(contents, config, GEMINI_MODEL)
    except GeminiQuotaExhaustedError:
        if not GEMINI_MODEL_FALLBACK:
            raise
        try:
            return client.models.generate_content(
                model=GEMINI_MODEL_FALLBACK, contents=contents, config=config
            )
        except genai_errors.ClientError as exc:
            if not _is_quota_error(exc):
                raise
            raise GeminiQuotaExhaustedError(str(exc)) from exc


class RespuestaJsonInvalidaError(Exception):
    """El modelo devolvió algo que no es el JSON pedido pese al response_schema."""


def generar_json(
    contents,
    system_instruction: str,
    schema: types.Schema,
    temperature: float = 0.2,
) -> dict:
    """Salida estructurada garantizada por `response_schema`, no por prompt.

    Se usa en vez de function calling en los análisis de una sola pasada: aquí no
    hay que decidir NADA (no hay herramienta que elegir, ni varios pasos), solo
    rellenar un formulario — y con response_schema el modelo no puede devolver
    prosa por delante del JSON, que es el fallo que obliga a parsear a mano.

    `temperature` baja por defecto: extraer números de una analítica es una tarea
    de transcripción, no de redacción.
    """
    respuesta = generate(
        contents,
        types.GenerateContentConfig(
            system_instruction=system_instruction,
            response_mime_type="application/json",
            response_schema=schema,
            temperature=temperature,
        ),
    )
    texto = (respuesta.text or "").strip()
    if not texto:
        raise RespuestaJsonInvalidaError("El modelo no devolvió contenido.")
    try:
        datos = json.loads(texto)
    except json.JSONDecodeError as exc:
        raise RespuestaJsonInvalidaError(f"JSON no parseable: {texto[:200]}") from exc
    if not isinstance(datos, dict):
        raise RespuestaJsonInvalidaError(f"Se esperaba un objeto JSON, llegó {type(datos).__name__}.")
    return datos
