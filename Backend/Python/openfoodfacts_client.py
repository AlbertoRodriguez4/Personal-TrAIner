"""Cliente delgado para Open Food Facts — catálogo abierto de productos
envasados (nutricion). Sin API key, solo pide un User-Agent descriptivo (env
OPENFOODFACTS_USER_AGENT). Verificado en vivo: búsqueda por nombre
(cgi/search.pl, clave "products") y lookup por código de barras
(api/v2/product/{codigo}.json, clave "product" + "status":0 si no existe)
tienen formas de respuesta distintas — este cliente normaliza ambas al mismo
shape de salida."""
import os

import requests

OFF_SEARCH_URL = "https://world.openfoodfacts.org/cgi/search.pl"
OFF_PRODUCT_URL = "https://world.openfoodfacts.org/api/v2/product/{barcode}.json"
OFF_TIMEOUT = 10
OFF_FIELDS = "product_name,brands,nutriscore_grade,nova_group,ecoscore_grade,nutriments,code"


def _headers() -> dict:
    user_agent = os.environ.get("OPENFOODFACTS_USER_AGENT") or "PersonalTrAIner/1.0 (sin-contacto-configurado)"
    return {"User-Agent": user_agent}


def _normalizar_producto(p: dict) -> dict:
    nutrientes = p.get("nutriments", {})
    return {
        "nombre": p.get("product_name") or None,
        "marca": p.get("brands") or None,
        "codigo_barras": p.get("code") or None,
        "nutriscore": (p.get("nutriscore_grade") or "").upper() or None,
        "nova_group": p.get("nova_group"),
        "ecoscore": (p.get("ecoscore_grade") or "").upper() or None,
        "kcal_100g": nutrientes.get("energy-kcal_100g"),
        "proteinas_100g": nutrientes.get("proteins_100g"),
        "carbohidratos_100g": nutrientes.get("carbohydrates_100g"),
        "grasas_100g": nutrientes.get("fat_100g"),
        "fuente": "openfoodfacts",
    }


def buscar_producto(consulta: str) -> dict | None:
    """`consulta` puede ser un código de barras (todo dígitos) o un
    nombre/marca de producto envasado. None si no hay match o si la API
    falla — nunca levanta, es una fuente de enriquecimiento."""
    if not consulta or not consulta.strip():
        return None
    try:
        if consulta.strip().isdigit():
            resp = requests.get(
                OFF_PRODUCT_URL.format(barcode=consulta.strip()),
                params={"fields": OFF_FIELDS},
                headers=_headers(),
                timeout=OFF_TIMEOUT,
            )
            resp.raise_for_status()
            data = resp.json()
            if not data.get("status") or "product" not in data:
                return None
            return _normalizar_producto(data["product"])

        resp = requests.get(
            OFF_SEARCH_URL,
            params={
                "search_terms": consulta,
                "search_simple": 1,
                "action": "process",
                "json": 1,
                "page_size": 1,
                "fields": OFF_FIELDS,
            },
            headers=_headers(),
            timeout=OFF_TIMEOUT,
        )
        resp.raise_for_status()
        productos = resp.json().get("products", [])
        if not productos:
            return None
        return _normalizar_producto(productos[0])
    except (requests.RequestException, ValueError):
        return None
