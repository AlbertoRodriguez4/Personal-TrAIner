"""Cliente delgado para Edamam Nutrition Analysis, vía RapidAPI (nutricion) —
parsea una lista de líneas de ingrediente en lenguaje natural y devuelve el
macro combinado de la comida completa. Free tier de RapidAPI: 1000 req/día,
50/min, uso personal/no comercial (env RAPIDAPI_KEY).

OJO: a diferencia de wger/Open Food Facts/USDA, este contrato NO se pudo
verificar en vivo (requiere una RAPIDAPI_KEY que no está disponible en este
entorno de desarrollo) — está armado con la documentación pública de Edamam
(POST /api/nutrition-details, body {"title", "ingr": [...]}, nutrientes bajo
totalNutrients.<TAG>.quantity con tags ENERC_KCAL/PROCNT/FAT/CHOCDF). Probarlo
en vivo apenas haya una key real configurada, antes de darlo por cerrado."""
import os

import requests

EDAMAM_URL = "https://edamam-nutrition-analysis.p.rapidapi.com/api/nutrition-details"
EDAMAM_HOST = "edamam-nutrition-analysis.p.rapidapi.com"
EDAMAM_TIMEOUT = 15


def _headers() -> dict | None:
    api_key = os.environ.get("RAPIDAPI_KEY")
    if not api_key:
        return None
    return {
        "X-RapidAPI-Key": api_key,
        "X-RapidAPI-Host": EDAMAM_HOST,
        "Content-Type": "application/json",
    }


def _extraer(nutrientes: dict, tag: str):
    return nutrientes.get(tag, {}).get("quantity")


def estimar_macros(ingredientes: list[str], titulo: str = "comida") -> dict | None:
    """`ingredientes`: líneas en lenguaje natural, ej.
    ["2 huevos revueltos", "2 rebanadas de pan integral"] — el modelo las
    redacta a partir de lo que identificó en la foto/descripción, Edamam las
    parsea y devuelve el macro combinado. None si falta la key, no hay match,
    o la API falla — nunca levanta, es una fuente de enriquecimiento."""
    headers = _headers()
    if not headers or not ingredientes:
        return None

    try:
        resp = requests.post(
            EDAMAM_URL,
            headers=headers,
            json={"title": titulo, "ingr": ingredientes},
            timeout=EDAMAM_TIMEOUT,
        )
        resp.raise_for_status()
        data = resp.json()
    except (requests.RequestException, ValueError):
        return None

    nutrientes = data.get("totalNutrients", {})
    if not nutrientes:
        return None

    return {
        "kcal_total": _extraer(nutrientes, "ENERC_KCAL"),
        "proteinas_g_total": _extraer(nutrientes, "PROCNT"),
        "carbohidratos_g_total": _extraer(nutrientes, "CHOCDF"),
        "grasas_g_total": _extraer(nutrientes, "FAT"),
        "ingredientes_no_reconocidos": data.get("ingredients", []) and [
            i for i in data.get("ingredients", []) if not i.get("parsed")
        ],
        "fuente": "edamam",
    }
