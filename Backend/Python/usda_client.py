"""Cliente delgado para USDA FoodData Central — perfil nutricional preciso de
ingredientes crudos/individuales (nutricion). Key gratis en
https://fdc.nal.usda.gov/api-key-signup/ (env USDA_FDC_API_KEY), 1000
req/hora. Dataset Foundation Foods: verificado en vivo que los macros/energía
se identifican por `nutrientId` estable (1003 proteína, 1004 grasa, 1005
carbohidratos), no por nombre — Foundation Foods no siempre trae un nutriente
"Energy" plano, solo variantes "Energy (Atwater General/Specific Factors)"
(nutrientId 2047/2048), así que la energía cae a buscar por prefijo si 2047
no está."""
import os

import requests

USDA_SEARCH_URL = "https://api.nal.usda.gov/fdc/v1/foods/search"
USDA_TIMEOUT = 10

NUTRIENT_ID_PROTEINA = 1003
NUTRIENT_ID_GRASA = 1004
NUTRIENT_ID_CARBOHIDRATOS = 1005
NUTRIENT_ID_ENERGIA_ATWATER_GENERAL = 2047


def _api_key() -> str:
    return os.environ.get("USDA_FDC_API_KEY") or "DEMO_KEY"


def _extraer_macros(food_nutrients: list[dict]) -> dict:
    por_id = {n.get("nutrientId"): n.get("value") for n in food_nutrients}
    kcal = por_id.get(NUTRIENT_ID_ENERGIA_ATWATER_GENERAL)
    if kcal is None:
        kcal = next(
            (n["value"] for n in food_nutrients if str(n.get("nutrientName", "")).startswith("Energy")),
            None,
        )
    return {
        "kcal_100g": kcal,
        "proteinas_100g": por_id.get(NUTRIENT_ID_PROTEINA),
        "carbohidratos_100g": por_id.get(NUTRIENT_ID_CARBOHIDRATOS),
        "grasas_100g": por_id.get(NUTRIENT_ID_GRASA),
    }


def buscar_alimento(nombre_alimento: str) -> dict | None:
    """Busca un ingrediente crudo en Foundation Foods (USDA). None si no hay
    match o si la API falla — nunca levanta, es una fuente de enriquecimiento."""
    if not nombre_alimento or not nombre_alimento.strip():
        return None
    try:
        resp = requests.get(
            USDA_SEARCH_URL,
            params={
                "api_key": _api_key(),
                "query": nombre_alimento,
                "dataType": "Foundation",
                "pageSize": 1,
            },
            timeout=USDA_TIMEOUT,
        )
        resp.raise_for_status()
        alimentos = resp.json().get("foods", [])
    except (requests.RequestException, ValueError):
        return None

    if not alimentos:
        return None

    alimento = alimentos[0]
    resultado = {
        "nombre": alimento.get("description"),
        "fuente": "usda_fdc",
    }
    resultado.update(_extraer_macros(alimento.get("foodNutrients", [])))
    return resultado
