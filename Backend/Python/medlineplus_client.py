"""Cliente delgado para MedlinePlus Connect (NIH / U.S. National Library of
Medicine) — información oficial de pruebas de laboratorio. Sin API key y sin
registro; es el servicio que la propia NLM publica para que un sistema clínico
resuelva un código LOINC a contenido para el paciente.

Verificado en vivo contra la API real:
- El endpoint es `https://connect.medlineplus.gov/service` y responde JSON con
  `knowledgeResponseType=application/json`.
- `informationRecipient.languageCode.c=es` devuelve el contenido en español
  (título, resumen y enlace a la página en español de MedlinePlus).
- El sistema de codificación LOINC es el OID `2.16.840.1.113883.6.1`.
- Los 33 códigos LOINC de `clinical_reference.BIOMARCADORES` devuelven al menos
  una entrada; varios devuelven 2-3 (la primera suele ser el concepto general y
  la segunda la prueba concreta — de ahí que se prefiera la que menciona
  "prueba"/"análisis" en el título).
- El `summary` viene en HTML, no en texto plano: hay que limpiarlo antes de
  meterlo en un prompt o el modelo gasta tokens leyendo `<h3>` y `<a href>`.

Esto es material informativo para pacientes, NO un diagnóstico ni una
recomendación clínica. Quien lo consuma tiene que decírselo al usuario.
"""
import html
import re
import urllib.parse

import requests

MEDLINEPLUS_URL = "https://connect.medlineplus.gov/service"
MEDLINEPLUS_TIMEOUT = 12
OID_LOINC = "2.16.840.1.113883.6.1"

# Longitud del resumen que se le pasa al modelo. El texto completo de una página
# de MedlinePlus ronda los 4-6 mil caracteres; con 12 marcadores en una analítica
# eso son ~15k tokens solo de referencia, y el presupuesto de Groq son 8000 TPM.
MAX_CARACTERES_RESUMEN = 700

_ETIQUETAS_HTML = re.compile(r"<[^>]+>")
_ESPACIOS = re.compile(r"\s+")


def _texto_plano(fragmento_html: str) -> str:
    sin_etiquetas = _ETIQUETAS_HTML.sub(" ", fragmento_html or "")
    return _ESPACIOS.sub(" ", html.unescape(sin_etiquetas)).strip()


def _puntuar_entrada(entrada: dict) -> tuple:
    """Cuando MedlinePlus devuelve varias entradas para un LOINC, la útil es la
    de la PRUEBA (`Prueba de ferritina`), no la del concepto general
    (`Colesterol`). Se ordena por eso; a igualdad, se respeta el orden original."""
    titulo = (entrada.get("title", {}) or {}).get("_value", "").lower()
    es_prueba = any(p in titulo for p in ("prueba", "analisis", "análisis", "examen", "test"))
    return (0 if es_prueba else 1,)


def info_prueba(loinc: str, idioma: str = "es") -> dict | None:
    """Título, resumen y enlace oficiales de una prueba de laboratorio a partir
    de su código LOINC. None si no hay match o el servicio falla — nunca levanta:
    es enriquecimiento del prompt, no un paso obligatorio del análisis."""
    if not loinc:
        return None

    params = {
        "mainSearchCriteria.v.cs": OID_LOINC,
        "mainSearchCriteria.v.c": loinc,
        "knowledgeResponseType": "application/json",
        "informationRecipient.languageCode.c": idioma,
    }
    try:
        resp = requests.get(MEDLINEPLUS_URL, params=params, timeout=MEDLINEPLUS_TIMEOUT)
        resp.raise_for_status()
        datos = resp.json()
    except (requests.RequestException, ValueError):
        return None

    entradas = (datos.get("feed") or {}).get("entry") or []
    if not entradas:
        return None

    entrada = sorted(entradas, key=_puntuar_entrada)[0]
    resumen = _texto_plano((entrada.get("summary", {}) or {}).get("_value", ""))
    if len(resumen) > MAX_CARACTERES_RESUMEN:
        resumen = resumen[:MAX_CARACTERES_RESUMEN].rsplit(" ", 1)[0] + "…"

    enlaces = entrada.get("link") or []
    url = next((l.get("href") for l in enlaces if l.get("href")), None)
    if url:
        # El servicio añade parámetros de analítica propios; sobran en una cita.
        partes = urllib.parse.urlsplit(url)
        url = urllib.parse.urlunsplit(partes._replace(query=""))

    return {
        "titulo": (entrada.get("title", {}) or {}).get("_value"),
        "resumen": resumen,
        "url": url,
        "loinc": loinc,
        "fuente": "MedlinePlus — U.S. National Library of Medicine (NIH)",
        "disclaimer": (
            "Información divulgativa oficial del NIH sobre la prueba, no un diagnóstico "
            "ni una interpretación de este resultado concreto."
        ),
    }


def info_pruebas(loincs: list[str], idioma: str = "es") -> dict[str, dict]:
    """Varias pruebas de una vez. Secuencial a propósito: una analítica trae
    como mucho 15-20 marcadores del catálogo y MedlinePlus responde en ~300 ms,
    así que no compensa abrir un pool de hilos contra un servicio público."""
    resultados = {}
    for loinc in dict.fromkeys(l for l in loincs if l):
        info = info_prueba(loinc, idioma)
        if info:
            resultados[loinc] = info
    return resultados
