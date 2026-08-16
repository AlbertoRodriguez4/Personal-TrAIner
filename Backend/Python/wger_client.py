"""Cliente delgado para wger (https://wger.de/api/v2/) — catálogo abierto de
ejercicios. Lectura pública sin API key, sin límite de tasa en los endpoints
que usamos (ver backend_python_ai/SKILL.md). Verificado en vivo contra la API
real: NO existe un endpoint de búsqueda de texto libre (/exercise/search/ da
404, y los intentos de filtro por nombre en exercise-translation se ignoran en
silencio) — por eso este cliente filtra por categoría/equipamiento (IDs
reales, confirmados) en vez de por texto, igual que ya hace
`buscar_ejercicios_catalogo` con el catálogo interno."""
import requests

WGER_BASE_URL = "https://wger.de/api/v2"
WGER_TIMEOUT = 10
IDIOMA_ES = 4
IDIOMA_EN = 2

# IDs estables (8 categorías, 12 equipos — ver exercisecategory/equipment).
CATEGORIAS = {
    "abdomen": 10, "abdominales": 10, "core": 10,
    "brazos": 8, "biceps": 8, "triceps": 8,
    "espalda": 12,
    "pantorrillas": 14, "gemelos": 14,
    "cardio": 15,
    "pecho": 11, "pectorales": 11,
    "piernas": 9, "cuadriceps": 9, "femoral": 9, "gluteos": 9,
    "hombros": 13, "deltoides": 13,
}

EQUIPAMIENTO = {
    "barra": 1, "barra olimpica": 1,
    "banco": 8,
    "polea": 12, "maquina de cable": 12, "cable": 12,
    "mancuerna": 3, "mancuernas": 3,
    "colchoneta": 4, "esterilla": 4,
    "banco inclinado": 9,
    "kettlebell": 10, "pesa rusa": 10,
    "barra de dominadas": 6, "dominadas": 6,
    "banda elastica": 11, "banda": 11,
    "barra z": 2, "barra sz": 2,
    "fitball": 5, "pelota suiza": 5, "swiss ball": 5,
    "peso corporal": 7, "sin equipamiento": 7, "ninguno": 7,
}


def _normalizar(texto: str) -> str:
    reemplazos = str.maketrans("áéíóúñ", "aeioun")
    return texto.strip().lower().translate(reemplazos)


def _resolver_id(termino: str | None, tabla: dict) -> int | None:
    if not termino:
        return None
    clave = _normalizar(termino)
    if clave in tabla:
        return tabla[clave]
    for nombre, id_ in tabla.items():
        if nombre in clave or clave in nombre:
            return id_
    return None


def _mejor_traduccion(traducciones: list[dict]) -> str | None:
    for idioma in (IDIOMA_ES, IDIOMA_EN):
        for t in traducciones:
            if t.get("language") == idioma and t.get("name"):
                return t["name"]
    for t in traducciones:
        if t.get("name"):
            return t["name"]
    return None


def buscar_ejercicios(grupo_muscular: str | None = None, equipamiento: str | None = None) -> list[dict]:
    """Devuelve ejercicios de wger filtrados por categoría/equipamiento (IDs
    reales resueltos desde texto en español). Lista vacía si no hay match o si
    wger no responde — nunca levanta, es una fuente de enriquecimiento."""
    params = {"format": "json", "limit": 15}
    categoria_id = _resolver_id(grupo_muscular, CATEGORIAS)
    equipo_id = _resolver_id(equipamiento, EQUIPAMIENTO)
    if categoria_id:
        params["category"] = categoria_id
    if equipo_id:
        params["equipment"] = equipo_id

    try:
        resp = requests.get(f"{WGER_BASE_URL}/exerciseinfo/", params=params, timeout=WGER_TIMEOUT)
        resp.raise_for_status()
        data = resp.json()
    except (requests.RequestException, ValueError):
        return []

    ejercicios = []
    for item in data.get("results", []):
        nombre = _mejor_traduccion(item.get("translations", []))
        if not nombre:
            continue
        ejercicios.append({
            "nombre": nombre,
            "categoria": item.get("category", {}).get("name"),
            "musculos": [m["name"] for m in item.get("muscles", [])],
            "equipamiento": [e["name"] for e in item.get("equipment", [])],
            "fuente": "wger",
        })
    return ejercicios
