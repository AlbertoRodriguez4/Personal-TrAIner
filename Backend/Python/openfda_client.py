"""Cliente delgado para OpenFDA (sueno_recuperacion) — info de etiqueta de
medicamentos/suplementos que el usuario mencione. Sin API key: 1000 req/día;
con key gratis (env OPENFDA_API_KEY, signup en
https://open.fda.gov/apis/authentication/): 120000 req/día.

Verificado en vivo: `openfda.generic_name`/`brand_name` son listas; el
buscador soporta full-text (search=<termino>, sin prefijo de campo) además de
campo exacto, lo que ayuda cuando el usuario usa el nombre común en español
("paracetamol") en vez del genérico usado en EE.UU. ("acetaminophen") — de
ahí la tabla de sinónimos para los casos más comunes en contexto de
recuperación/entrenamiento.

Esto es SOLO información de etiqueta oficial (indicaciones/advertencias/
interacciones) — nunca diagnóstico ni recomendación de dosis. El system
prompt de sueno_recuperacion debe reforzar el disclaimer médico explícito;
este cliente ya lo incluye en el resultado por si acaso."""
import os

import requests

OPENFDA_LABEL_URL = "https://api.fda.gov/drug/label.json"
OPENFDA_TIMEOUT = 10

# Casos comunes en contexto de recuperación/entrenamiento donde el nombre en
# español no coincide con el genérico usado por la FDA en EE.UU.
SINONIMOS_ES_EN = {
    "paracetamol": "acetaminophen",
    "acido acetilsalicilico": "aspirin",
    "aspirina": "aspirin",
}


def _normalizar(termino: str) -> str:
    reemplazos = str.maketrans("áéíóúñ", "aeioun")
    return termino.strip().lower().translate(reemplazos)


def _api_key_param() -> dict:
    key = os.environ.get("OPENFDA_API_KEY")
    return {"api_key": key} if key else {}


def _buscar(query: str, limit: int = 5) -> list[dict]:
    try:
        resp = requests.get(
            OPENFDA_LABEL_URL,
            params={**_api_key_param(), "search": query, "limit": limit},
            timeout=OPENFDA_TIMEOUT,
        )
        resp.raise_for_status()
        data = resp.json()
    except (requests.RequestException, ValueError):
        return []
    return data.get("results", [])


def _prioridad_candidato(resultado: dict, termino_en: str) -> tuple:
    """Heurística para elegir entre varios candidatos: OpenFDA está dominado
    por combinaciones homeopáticas con 10-20 ingredientes listados en
    `generic_name` (ej. buscar "melatonin" devuelve mayormente combos tipo
    "Bio Thalamus Phase"). Prioridad: 1) match exacto de un solo ingrediente,
    2) `generic_name` más corto (proxy de "menos ingredientes mezclados")."""
    genericos = resultado.get("openfda", {}).get("generic_name") or [""]
    nombre = genericos[0]
    es_exacto = nombre.strip().lower() == termino_en.strip().lower()
    return (0 if es_exacto else 1, len(nombre))


def buscar_medicamento(nombre: str) -> dict | None:
    """Info de etiqueta (indicaciones, advertencias, interacciones) de un
    medicamento/suplemento de venta libre o con receta. None si no hay match
    o la API falla — nunca levanta, es una fuente de enriquecimiento
    informativa, NUNCA un diagnóstico ni una recomendación de dosis."""
    if not nombre or not nombre.strip():
        return None

    termino = _normalizar(nombre)
    termino_en = SINONIMOS_ES_EN.get(termino, nombre.strip())

    candidatos = (
        _buscar(f'openfda.generic_name:"{termino_en}"', limit=10)
        or _buscar(f'openfda.brand_name:"{termino_en}"', limit=10)
        or _buscar(termino_en, limit=10)
    )
    if not candidatos:
        return None
    resultado = min(candidatos, key=lambda r: _prioridad_candidato(r, termino_en))

    openfda = resultado.get("openfda", {})
    nombre_generico = (openfda.get("generic_name") or [None])[0]
    es_combinacion = bool(nombre_generico) and "," in nombre_generico
    return {
        "nombre_generico": nombre_generico,
        "nombre_comercial": (openfda.get("brand_name") or [None])[0],
        "indicaciones": (resultado.get("indications_and_usage") or [None])[0],
        "advertencias": (resultado.get("warnings") or resultado.get("warnings_and_cautions") or [None])[0],
        "interacciones": (resultado.get("drug_interactions") or [None])[0],
        # OpenFDA está dominado por combinaciones homeopáticas — si el match
        # tiene varios ingredientes listados, el modelo debe aclarar que las
        # advertencias/indicaciones son del PRODUCTO COMBINADO, no del
        # ingrediente puro que preguntó el usuario (en vez de presentarlas
        # como si aplicaran 1 a 1).
        "es_posible_combinacion": es_combinacion,
        "fuente": "openfda",
        "disclaimer": (
            "Información de la etiqueta oficial de la FDA, no un consejo médico "
            "ni una recomendación de dosis — no sustituye a un profesional de la salud."
        ),
    }
