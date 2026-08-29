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
RETRY_BACKOFF_SECONDS = (2, 4)  # pausas entre los intentos 1→2 y 2→3. NestJS espera hasta
                                 # 120 s por esta llamada (ai.service.post), así que 6 s
                                 # acumulados caben de sobra; lo que no cabe es reintentar
                                 # sin pausa, que contra un modelo saturado devuelve el
                                 # mismo 503 tres veces en el mismo segundo.

client = genai.Client(api_key=_env("GEMINI_API_KEY"))


class LLMProviderExhaustedError(Exception):
    """Base: un proveedor de LLM agotó los reintentos ante 429/rate-limit sostenido."""


class GeminiQuotaExhaustedError(LLMProviderExhaustedError):
    """Gemini agotó los reintentos: 429/RESOURCE_EXHAUSTED sostenido (cuota de la API)."""


class GeminiSobrecargadoError(LLMProviderExhaustedError):
    """Gemini agotó los reintentos: 503 UNAVAILABLE / 500 INTERNAL sostenido.

    El fallo es de Google, no de la key ("This model is currently experiencing
    high demand"). Va aparte de la cuota porque ni el consejo al usuario ni la
    palanca del operador son los mismos: contra la cuota se espera a que renueve
    y contra la saturación se reintenta o se cambia de modelo con
    GEMINI_MODEL_FALLBACK.
    """


# 429/RESOURCE_EXHAUSTED es la cuota de la key; 503/UNAVAILABLE y 500/INTERNAL son el
# modelo saturado o un tropiezo pasajero de Google. Los tres se reintentan. El resto
# (400, 403, 404…) son errores nuestros: reintentarlos solo alarga el fallo.
_CODIGOS_CUOTA = (429,)
_ESTADOS_CUOTA = ("RESOURCE_EXHAUSTED",)
_CODIGOS_SOBRECARGA = (500, 503)
_ESTADOS_SOBRECARGA = ("UNAVAILABLE", "INTERNAL")


def _is_quota_error(exc: genai_errors.APIError) -> bool:
    return exc.code in _CODIGOS_CUOTA or exc.status in _ESTADOS_CUOTA


def _es_sobrecarga(exc: genai_errors.APIError) -> bool:
    return exc.code in _CODIGOS_SOBRECARGA or exc.status in _ESTADOS_SOBRECARGA


def _es_reintentable(exc: genai_errors.APIError) -> bool:
    return _is_quota_error(exc) or _es_sobrecarga(exc)


def _error_agotado(exc: genai_errors.APIError) -> LLMProviderExhaustedError:
    if _is_quota_error(exc):
        return GeminiQuotaExhaustedError(str(exc))
    return GeminiSobrecargadoError(str(exc))


def _generate_with_retry(contents, config, model: str):
    """generate_content con hasta RETRY_ATTEMPTS intentos cuando Gemini devuelve algo
    transitorio (429 de cuota, 503 de modelo saturado, 500 suyo). Cualquier otro error
    no reintenta y sube tal cual.

    Se captura `APIError` y no `ClientError`: el 503 del modelo saturado llega como
    `ServerError`, que es hermana de `ClientError` y no descendiente, así que el
    `except` anterior ni lo veía — subía crudo hasta la app, que enseñaba el JSON de
    Google tal cual en un aviso.
    """
    last_exc = None
    for attempt in range(RETRY_ATTEMPTS):
        try:
            return client.models.generate_content(model=model, contents=contents, config=config)
        except genai_errors.APIError as exc:
            if not _es_reintentable(exc):
                raise
            last_exc = exc
            if attempt < RETRY_ATTEMPTS - 1:
                time.sleep(RETRY_BACKOFF_SECONDS[attempt])
    raise _error_agotado(last_exc) from last_exc


def generate(contents, config):
    """Reintenta contra GEMINI_MODEL; si se agotan los intentos —por cuota o por
    saturación— y hay GEMINI_MODEL_FALLBACK configurado, hace un único intento adicional
    contra ese modelo antes de rendirse.

    Ese fallback es la única salida real a un 503 sostenido: lo que está saturado es un
    modelo concreto, no la API entera, así que reintentar contra el mismo puede fallar
    toda la tarde mientras otro modelo responde a la primera.
    """
    try:
        return _generate_with_retry(contents, config, GEMINI_MODEL)
    except LLMProviderExhaustedError:
        if not GEMINI_MODEL_FALLBACK:
            raise
        try:
            return client.models.generate_content(
                model=GEMINI_MODEL_FALLBACK, contents=contents, config=config
            )
        except genai_errors.APIError as exc:
            if not _es_reintentable(exc):
                raise
            # El tipo sale del último fallo real: si el primario cayó por saturación y
            # el de reserva por cuota, lo que deja al usuario sin respuesta es la cuota,
            # y ese es el mensaje que tiene que ver.
            raise _error_agotado(exc) from exc


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
