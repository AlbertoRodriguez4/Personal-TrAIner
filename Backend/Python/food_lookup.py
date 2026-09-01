"""Estimación de macros para el registro manual de comida (nutricion, sin foto):
el usuario teclea un nombre + una cantidad (gramos directos, o una referencia
corporal/de plato) y esto devuelve kcal/proteína/carbohidratos/grasas SIN pasar
por ningún modelo — igual que body_composition.py, es una cifra buscada y
escalada, no algo que un LLM podría redondear o inventar.

Fuente, en orden:
1. Catálogo local (`_ALIMENTOS`): ~70 alimentos frescos/cocinados de uso común
   en España, valores fijos verificados a mano. Cubre los sugeridos como chips
   en la UI y la gran mayoría de búsquedas reales — no depende de red ni de
   ninguna API key, así que funciona igual de bien el primer día que con el
   proyecto en producción.
2. USDA FoodData Central (`usda_client`) — mejor para ingredientes crudos que
   no estén en el catálogo, sobre todo si `USDA_FDC_API_KEY` está configurada
   (si no, cae a DEMO_KEY, muy limitada).
3. Open Food Facts (`openfoodfacts_client`) — mejor para productos envasados
   con nombre/marca reconocible.

El modo "Referencias" (palma, puño, ¼ de plato...) traduce la unidad a gramos
según la CATEGORÍA del alimento (proteína/carbohidrato/verdura/fruta/grasa/
lácteo) — por eso cada entrada del catálogo lleva una, y por eso un resultado
externo sin categoría reconocible solo puede usar gramos, nunca referencias:
inventar la categoría metería un puño de proteína donde debería ir un pulgar
de grasa y el error se colaría directo en las kcal.
"""
import re
import threading
import time
import unicodedata
from collections import OrderedDict
from concurrent import futures

import openfoodfacts_client
import usda_client


class AlimentoNoEncontradoError(Exception):
    """Ni el catálogo local ni USDA/Open Food Facts tienen este alimento."""


class ReferenciaNoDisponibleError(Exception):
    """La unidad de referencia pedida no aplica a la categoría de este alimento
    (o el alimento vino de una fuente externa sin categoría reconocible)."""

    def __init__(self, unidad: str, categoria: str | None):
        self.unidad = unidad
        self.categoria = categoria
        detalle = f"La referencia '{unidad}' no está disponible para este alimento"
        detalle += f" (categoría: {categoria})." if categoria else " (no se pudo determinar su categoría)."
        super().__init__(detalle)


# ============================================================
# Catálogo local — nombre : (categoria, kcal, proteinas, carbohidratos, grasas) por 100 g
# ============================================================
# Cocinado/tal cual se come cuando ese es el uso habitual (arroz, pasta, carnes,
# huevo...), crudo cuando se come crudo (fruta, verdura de hoja, frutos secos).
# Legumbres van en 'carbohidrato': es como se reparten en el método del plato/
# de la mano (ración de fist junto a arroz/pasta), no por ser su único macro.

_ALIMENTOS: list[dict] = [
    # ---- Proteína ----
    {"nombre": "Pechuga de pollo", "alias": ["pollo", "filete de pollo", "pechuga de pollo a la plancha"],
     "categoria": "proteina", "kcal_100g": 165, "proteinas_100g": 31.0, "carbohidratos_100g": 0.0, "grasas_100g": 3.6},
    {"nombre": "Muslo de pollo", "alias": ["contramuslo de pollo", "muslo de pollo sin piel"],
     "categoria": "proteina", "kcal_100g": 178, "proteinas_100g": 24.5, "carbohidratos_100g": 0.0, "grasas_100g": 8.3},
    {"nombre": "Pechuga de pavo", "alias": ["pavo"],
     "categoria": "proteina", "kcal_100g": 135, "proteinas_100g": 30.0, "carbohidratos_100g": 0.0, "grasas_100g": 1.0},
    {"nombre": "Ternera magra", "alias": ["filete de ternera", "solomillo de ternera", "carne de ternera"],
     "categoria": "proteina", "kcal_100g": 172, "proteinas_100g": 26.5, "carbohidratos_100g": 0.0, "grasas_100g": 6.5},
    {"nombre": "Solomillo de cerdo", "alias": ["cerdo", "lomo de cerdo"],
     "categoria": "proteina", "kcal_100g": 143, "proteinas_100g": 26.0, "carbohidratos_100g": 0.0, "grasas_100g": 3.5},
    {"nombre": "Salmón", "alias": ["salmon a la plancha", "filete de salmon"],
     "categoria": "proteina", "kcal_100g": 208, "proteinas_100g": 20.4, "carbohidratos_100g": 0.0, "grasas_100g": 13.4},
    {"nombre": "Atún al natural", "alias": ["atun en lata", "atun en conserva", "atun al natural"],
     "categoria": "proteina", "kcal_100g": 116, "proteinas_100g": 26.0, "carbohidratos_100g": 0.0, "grasas_100g": 1.0},
    {"nombre": "Atún fresco", "alias": ["atun a la plancha", "atun fresco"],
     "categoria": "proteina", "kcal_100g": 132, "proteinas_100g": 28.0, "carbohidratos_100g": 0.0, "grasas_100g": 1.3},
    {"nombre": "Merluza", "alias": ["merluza a la plancha"],
     "categoria": "proteina", "kcal_100g": 90, "proteinas_100g": 17.8, "carbohidratos_100g": 0.0, "grasas_100g": 1.3},
    {"nombre": "Gambas", "alias": ["langostinos", "camarones", "gambas cocidas"],
     "categoria": "proteina", "kcal_100g": 99, "proteinas_100g": 24.0, "carbohidratos_100g": 0.2, "grasas_100g": 0.3},
    {"nombre": "Huevo", "alias": ["huevo cocido", "huevo frito", "huevos"],
     "categoria": "proteina", "kcal_100g": 155, "proteinas_100g": 12.6, "carbohidratos_100g": 1.1, "grasas_100g": 10.6},
    {"nombre": "Clara de huevo", "alias": ["claras de huevo"],
     "categoria": "proteina", "kcal_100g": 52, "proteinas_100g": 11.0, "carbohidratos_100g": 0.7, "grasas_100g": 0.2},
    {"nombre": "Tofu", "alias": [],
     "categoria": "proteina", "kcal_100g": 76, "proteinas_100g": 8.0, "carbohidratos_100g": 1.9, "grasas_100g": 4.8},
    {"nombre": "Jamón cocido o pavo", "alias": ["fiambre de pavo", "pechuga de pavo fiambre", "jamon york", "fiambre"],
     "categoria": "proteina", "kcal_100g": 105, "proteinas_100g": 18.0, "carbohidratos_100g": 1.5, "grasas_100g": 3.0},
    {"nombre": "Jamón serrano", "alias": ["jamon iberico", "jamon curado"],
     "categoria": "proteina", "kcal_100g": 241, "proteinas_100g": 31.0, "carbohidratos_100g": 0.5, "grasas_100g": 13.5},

    # ---- Carbohidrato ----
    {"nombre": "Arroz blanco cocido", "alias": ["arroz cocido", "arroz blanco", "arroz"],
     "categoria": "carbohidrato", "kcal_100g": 130, "proteinas_100g": 2.7, "carbohidratos_100g": 28.2, "grasas_100g": 0.3},
    {"nombre": "Arroz integral cocido", "alias": ["arroz integral"],
     "categoria": "carbohidrato", "kcal_100g": 123, "proteinas_100g": 2.6, "carbohidratos_100g": 25.8, "grasas_100g": 1.0},
    {"nombre": "Pasta cocida", "alias": ["pasta", "macarrones", "espaguetis", "espagueti"],
     "categoria": "carbohidrato", "kcal_100g": 131, "proteinas_100g": 5.0, "carbohidratos_100g": 25.0, "grasas_100g": 1.1},
    {"nombre": "Pasta integral cocida", "alias": ["pasta integral"],
     "categoria": "carbohidrato", "kcal_100g": 124, "proteinas_100g": 5.3, "carbohidratos_100g": 25.0, "grasas_100g": 1.4},
    {"nombre": "Patata cocida", "alias": ["patata", "papa", "patata asada", "patatas"],
     "categoria": "carbohidrato", "kcal_100g": 87, "proteinas_100g": 1.9, "carbohidratos_100g": 20.1, "grasas_100g": 0.1},
    {"nombre": "Boniato", "alias": ["batata", "patata dulce", "boniato asado"],
     "categoria": "carbohidrato", "kcal_100g": 90, "proteinas_100g": 2.0, "carbohidratos_100g": 20.7, "grasas_100g": 0.2},
    {"nombre": "Pan blanco", "alias": ["pan"],
     "categoria": "carbohidrato", "kcal_100g": 265, "proteinas_100g": 9.0, "carbohidratos_100g": 49.0, "grasas_100g": 3.2},
    {"nombre": "Pan integral", "alias": [],
     "categoria": "carbohidrato", "kcal_100g": 247, "proteinas_100g": 13.0, "carbohidratos_100g": 41.0, "grasas_100g": 3.4},
    {"nombre": "Avena", "alias": ["copos de avena", "avena en copos"],
     "categoria": "carbohidrato", "kcal_100g": 389, "proteinas_100g": 16.9, "carbohidratos_100g": 66.3, "grasas_100g": 6.9},
    {"nombre": "Quinoa cocida", "alias": ["quinoa"],
     "categoria": "carbohidrato", "kcal_100g": 120, "proteinas_100g": 4.4, "carbohidratos_100g": 21.3, "grasas_100g": 1.9},
    {"nombre": "Cuscús cocido", "alias": ["cuscus", "cous cous"],
     "categoria": "carbohidrato", "kcal_100g": 112, "proteinas_100g": 3.8, "carbohidratos_100g": 23.2, "grasas_100g": 0.2},
    {"nombre": "Lentejas cocidas", "alias": ["lentejas"],
     "categoria": "carbohidrato", "kcal_100g": 116, "proteinas_100g": 9.0, "carbohidratos_100g": 20.1, "grasas_100g": 0.4},
    {"nombre": "Garbanzos cocidos", "alias": ["garbanzos"],
     "categoria": "carbohidrato", "kcal_100g": 164, "proteinas_100g": 8.9, "carbohidratos_100g": 27.4, "grasas_100g": 2.6},
    {"nombre": "Judías o alubias cocidas", "alias": ["alubias", "judias blancas", "frijoles"],
     "categoria": "carbohidrato", "kcal_100g": 127, "proteinas_100g": 8.7, "carbohidratos_100g": 22.8, "grasas_100g": 0.5},
    {"nombre": "Maíz cocido", "alias": ["maiz", "elote", "maiz dulce"],
     "categoria": "carbohidrato", "kcal_100g": 96, "proteinas_100g": 3.4, "carbohidratos_100g": 21.0, "grasas_100g": 1.5},

    # ---- Verdura ----
    {"nombre": "Brócoli cocido", "alias": ["brocoli"],
     "categoria": "verdura", "kcal_100g": 35, "proteinas_100g": 2.4, "carbohidratos_100g": 7.2, "grasas_100g": 0.4},
    {"nombre": "Espinacas", "alias": ["espinacas crudas"],
     "categoria": "verdura", "kcal_100g": 23, "proteinas_100g": 2.9, "carbohidratos_100g": 3.6, "grasas_100g": 0.4},
    {"nombre": "Lechuga", "alias": [],
     "categoria": "verdura", "kcal_100g": 15, "proteinas_100g": 1.4, "carbohidratos_100g": 2.9, "grasas_100g": 0.2},
    {"nombre": "Tomate", "alias": ["tomates"],
     "categoria": "verdura", "kcal_100g": 18, "proteinas_100g": 0.9, "carbohidratos_100g": 3.9, "grasas_100g": 0.2},
    {"nombre": "Zanahoria", "alias": ["zanahorias"],
     "categoria": "verdura", "kcal_100g": 41, "proteinas_100g": 0.9, "carbohidratos_100g": 10.0, "grasas_100g": 0.2},
    {"nombre": "Calabacín cocido", "alias": ["calabacin"],
     "categoria": "verdura", "kcal_100g": 17, "proteinas_100g": 1.2, "carbohidratos_100g": 3.1, "grasas_100g": 0.3},
    {"nombre": "Pimiento", "alias": ["pimientos"],
     "categoria": "verdura", "kcal_100g": 31, "proteinas_100g": 1.0, "carbohidratos_100g": 6.0, "grasas_100g": 0.3},
    {"nombre": "Cebolla", "alias": [],
     "categoria": "verdura", "kcal_100g": 40, "proteinas_100g": 1.1, "carbohidratos_100g": 9.3, "grasas_100g": 0.1},
    {"nombre": "Champiñones", "alias": ["setas", "champinones"],
     "categoria": "verdura", "kcal_100g": 22, "proteinas_100g": 3.1, "carbohidratos_100g": 3.3, "grasas_100g": 0.3},
    {"nombre": "Judías verdes cocidas", "alias": ["judias verdes", "ejotes"],
     "categoria": "verdura", "kcal_100g": 31, "proteinas_100g": 1.8, "carbohidratos_100g": 7.0, "grasas_100g": 0.1},
    {"nombre": "Coliflor cocida", "alias": ["coliflor"],
     "categoria": "verdura", "kcal_100g": 25, "proteinas_100g": 1.9, "carbohidratos_100g": 5.0, "grasas_100g": 0.3},
    {"nombre": "Pepino", "alias": [],
     "categoria": "verdura", "kcal_100g": 15, "proteinas_100g": 0.7, "carbohidratos_100g": 3.6, "grasas_100g": 0.1},
    {"nombre": "Berenjena cocida", "alias": ["berenjena"],
     "categoria": "verdura", "kcal_100g": 25, "proteinas_100g": 1.0, "carbohidratos_100g": 6.0, "grasas_100g": 0.2},

    # ---- Fruta ----
    {"nombre": "Manzana", "alias": [],
     "categoria": "fruta", "kcal_100g": 52, "proteinas_100g": 0.3, "carbohidratos_100g": 13.8, "grasas_100g": 0.2},
    {"nombre": "Plátano", "alias": ["platano", "banana"],
     "categoria": "fruta", "kcal_100g": 89, "proteinas_100g": 1.1, "carbohidratos_100g": 22.8, "grasas_100g": 0.3},
    {"nombre": "Naranja", "alias": [],
     "categoria": "fruta", "kcal_100g": 47, "proteinas_100g": 0.9, "carbohidratos_100g": 11.8, "grasas_100g": 0.1},
    {"nombre": "Fresas", "alias": ["fresones", "fresa"],
     "categoria": "fruta", "kcal_100g": 32, "proteinas_100g": 0.7, "carbohidratos_100g": 7.7, "grasas_100g": 0.3},
    {"nombre": "Uvas", "alias": ["uva"],
     "categoria": "fruta", "kcal_100g": 69, "proteinas_100g": 0.7, "carbohidratos_100g": 18.1, "grasas_100g": 0.2},
    {"nombre": "Sandía", "alias": ["sandia"],
     "categoria": "fruta", "kcal_100g": 30, "proteinas_100g": 0.6, "carbohidratos_100g": 7.6, "grasas_100g": 0.2},
    {"nombre": "Pera", "alias": [],
     "categoria": "fruta", "kcal_100g": 57, "proteinas_100g": 0.4, "carbohidratos_100g": 15.2, "grasas_100g": 0.1},
    {"nombre": "Piña", "alias": ["pina"],
     "categoria": "fruta", "kcal_100g": 50, "proteinas_100g": 0.5, "carbohidratos_100g": 13.1, "grasas_100g": 0.1},
    {"nombre": "Kiwi", "alias": [],
     "categoria": "fruta", "kcal_100g": 61, "proteinas_100g": 1.1, "carbohidratos_100g": 14.7, "grasas_100g": 0.5},
    {"nombre": "Melón", "alias": ["melon"],
     "categoria": "fruta", "kcal_100g": 34, "proteinas_100g": 0.8, "carbohidratos_100g": 8.2, "grasas_100g": 0.2},
    {"nombre": "Mandarina", "alias": ["mandarinas"],
     "categoria": "fruta", "kcal_100g": 53, "proteinas_100g": 0.8, "carbohidratos_100g": 13.3, "grasas_100g": 0.3},

    # ---- Grasa ----
    {"nombre": "Aceite de oliva", "alias": ["aceite"],
     "categoria": "grasa", "kcal_100g": 884, "proteinas_100g": 0.0, "carbohidratos_100g": 0.0, "grasas_100g": 100.0},
    {"nombre": "Mantequilla", "alias": [],
     "categoria": "grasa", "kcal_100g": 717, "proteinas_100g": 0.9, "carbohidratos_100g": 0.1, "grasas_100g": 81.0},
    {"nombre": "Almendras", "alias": ["almendra"],
     "categoria": "grasa", "kcal_100g": 579, "proteinas_100g": 21.2, "carbohidratos_100g": 21.6, "grasas_100g": 49.9},
    {"nombre": "Nueces", "alias": ["nuez"],
     "categoria": "grasa", "kcal_100g": 654, "proteinas_100g": 15.2, "carbohidratos_100g": 13.7, "grasas_100g": 65.2},
    {"nombre": "Cacahuetes", "alias": ["mani", "cacahuete"],
     "categoria": "grasa", "kcal_100g": 567, "proteinas_100g": 25.8, "carbohidratos_100g": 16.1, "grasas_100g": 49.2},
    {"nombre": "Mantequilla de cacahuete", "alias": ["crema de cacahuete", "peanut butter"],
     "categoria": "grasa", "kcal_100g": 588, "proteinas_100g": 25.0, "carbohidratos_100g": 20.0, "grasas_100g": 50.0},
    {"nombre": "Aceitunas", "alias": ["olivas", "aceituna"],
     "categoria": "grasa", "kcal_100g": 115, "proteinas_100g": 0.8, "carbohidratos_100g": 6.3, "grasas_100g": 10.7},
    {"nombre": "Aguacate", "alias": [],
     "categoria": "grasa", "kcal_100g": 160, "proteinas_100g": 2.0, "carbohidratos_100g": 8.5, "grasas_100g": 14.7},
    {"nombre": "Queso curado", "alias": ["queso manchego", "queso semicurado"],
     "categoria": "grasa", "kcal_100g": 402, "proteinas_100g": 26.0, "carbohidratos_100g": 1.3, "grasas_100g": 33.0},
    {"nombre": "Semillas de chía", "alias": ["chia", "semillas de chia"],
     "categoria": "grasa", "kcal_100g": 486, "proteinas_100g": 16.5, "carbohidratos_100g": 42.1, "grasas_100g": 30.7},

    # ---- Lácteo ----
    {"nombre": "Leche entera", "alias": ["leche"],
     "categoria": "lacteo", "kcal_100g": 61, "proteinas_100g": 3.2, "carbohidratos_100g": 4.8, "grasas_100g": 3.3},
    {"nombre": "Leche desnatada", "alias": ["leche descremada"],
     "categoria": "lacteo", "kcal_100g": 35, "proteinas_100g": 3.4, "carbohidratos_100g": 5.0, "grasas_100g": 0.1},
    {"nombre": "Yogur natural", "alias": ["yogur"],
     "categoria": "lacteo", "kcal_100g": 61, "proteinas_100g": 3.5, "carbohidratos_100g": 4.7, "grasas_100g": 3.3},
    {"nombre": "Yogur griego", "alias": [],
     "categoria": "lacteo", "kcal_100g": 97, "proteinas_100g": 9.0, "carbohidratos_100g": 3.6, "grasas_100g": 5.0},
    {"nombre": "Queso fresco", "alias": ["requeson", "queso batido", "queso cottage", "cottage"],
     "categoria": "lacteo", "kcal_100g": 98, "proteinas_100g": 11.0, "carbohidratos_100g": 3.4, "grasas_100g": 4.3},

    # ---- Bebidas ----
    # Batidos, zumos y sustitutivos: valores por 100 ml (agua = kcal/proteína/
    # grasa ~0, así que "100 ml" no infla el resultado como pasaría promediando
    # con la proteína en polvo seca). La proteína en polvo SIN preparar va
    # aparte, en 'proteina', para quien prefiera pesar su cacito con precisión
    # en vez de fiarse de "1 batido" ya mezclado.
    {"nombre": "Proteína en polvo (sin preparar)", "alias": ["proteina en polvo", "whey", "batido de proteina en polvo"],
     "categoria": "proteina", "kcal_100g": 380, "proteinas_100g": 75.0, "carbohidratos_100g": 8.0, "grasas_100g": 6.0},
    {"nombre": "Batido de proteína (listo para beber)", "alias": ["batido de proteina", "batido proteico", "protein shake"],
     "categoria": "bebida", "kcal_100g": 62, "proteinas_100g": 10.0, "carbohidratos_100g": 3.0, "grasas_100g": 1.0},
    {"nombre": "Batido de chocolate", "alias": ["leche con cacao", "batido de cacao"],
     "categoria": "bebida", "kcal_100g": 83, "proteinas_100g": 3.3, "carbohidratos_100g": 11.0, "grasas_100g": 3.0},
    {"nombre": "Batido sustitutivo de comida", "alias": ["meal replacement", "batido sustitutivo"],
     "categoria": "bebida", "kcal_100g": 90, "proteinas_100g": 6.0, "carbohidratos_100g": 10.0, "grasas_100g": 3.0},
    {"nombre": "Smoothie de frutas", "alias": ["batido de frutas"],
     "categoria": "bebida", "kcal_100g": 55, "proteinas_100g": 1.0, "carbohidratos_100g": 13.0, "grasas_100g": 0.3},
    {"nombre": "Bebida isotónica", "alias": ["isotonica", "gatorade", "powerade"],
     "categoria": "bebida", "kcal_100g": 24, "proteinas_100g": 0.0, "carbohidratos_100g": 6.0, "grasas_100g": 0.0},
    {"nombre": "Zumo de naranja natural", "alias": ["zumo de naranja", "jugo de naranja"],
     "categoria": "bebida", "kcal_100g": 45, "proteinas_100g": 0.7, "carbohidratos_100g": 10.0, "grasas_100g": 0.2},
    {"nombre": "Café con leche", "alias": ["cafe con leche"],
     "categoria": "bebida", "kcal_100g": 40, "proteinas_100g": 2.0, "carbohidratos_100g": 4.0, "grasas_100g": 1.5},
]

LONGITUD_MINIMA_COINCIDENCIA_PARCIAL = 3


def normalizar(texto: str) -> str:
    """minúsculas, sin tildes, espacios colapsados — 'Aguacate', 'aguacate' y
    'AGUACATE' tienen que resolver a la misma entrada del catálogo."""
    texto = unicodedata.normalize("NFKD", texto or "").encode("ascii", "ignore").decode("ascii")
    return re.sub(r"\s+", " ", texto.lower().strip())


def _construir_indice() -> dict[str, dict]:
    indice: dict[str, dict] = {}
    for alimento in _ALIMENTOS:
        for clave in (alimento["nombre"], *alimento.get("alias", [])):
            indice[normalizar(clave)] = alimento
    return indice


_INDICE = _construir_indice()

# Las claves largas de sobra para el match parcial, de la más larga a la más
# corta y con su patrón `\bclave\b` ya compilado. Las dos cosas por el mismo
# motivo: `estimar()` corre en CADA pulsación del formulario manual (500 ms de
# debounce), y recompilar los ~200 regex del catálogo en cada consulta —además
# de recorrerlos todos para quedarse con la clave más larga— era trabajo
# repetido en el camino caliente. Ordenadas aquí, el primer acierto ya es el
# bueno y el bucle sale antes.
_CLAVES_PARCIALES: list[tuple[str, re.Pattern[str], dict]] = sorted(
    (
        (clave, re.compile(r"\b" + re.escape(clave) + r"\b"), alimento)
        for clave, alimento in _INDICE.items()
        if len(clave) >= LONGITUD_MINIMA_COINCIDENCIA_PARCIAL
    ),
    key=lambda entrada: len(entrada[0]),
    reverse=True,
)

# Nombre visible + todas sus claves ya normalizadas. `sugerir()` responde con
# 150 ms de debounce, así que normalizar los ~200 alias del catálogo (unicodedata
# + regex por cada uno) en cada pulsación era el grueso de su coste.
_CLAVES_POR_ALIMENTO: list[tuple[str, list[str]]] = [
    (
        alimento["nombre"],
        [normalizar(c) for c in (alimento["nombre"], *alimento.get("alias", []))],
    )
    for alimento in _ALIMENTOS
]


def buscar_local(consulta: str) -> dict | None:
    """Coincidencia exacta primero; si no, la clave más larga que aparezca
    como palabra(s) completas dentro de la consulta o viceversa — así
    "pollo a la plancha con especias" cae en "pollo" y "pechuga" cae en
    "pechuga de pollo", pero "pan" nunca cae dentro de "champán" (el mismo
    bug de subcadena suelta que ya mordió a clinical_reference, ver
    normalizar_codigo allí — por eso el límite de palabra y el mínimo de
    longitud son obligatorios, no un detalle de estilo)."""
    q = normalizar(consulta)
    if not q:
        return None

    exacto = _INDICE.get(q)
    if exacto:
        return exacto

    if len(q) < LONGITUD_MINIMA_COINCIDENCIA_PARCIAL:
        return None

    # `_CLAVES_PARCIALES` ya viene de más larga a más corta, así que el primer
    # acierto es el mismo que antes elegía el `len(clave) > mejor_longitud`.
    patron_consulta = re.compile(r"\b" + re.escape(q) + r"\b")
    for clave, patron_clave, alimento in _CLAVES_PARCIALES:
        if patron_clave.search(q) or patron_consulta.search(clave):
            return alimento
    return None


def sugerir(consulta: str, limite: int = 8) -> list[str]:
    """Nombres del catálogo local para autocompletar mientras el usuario
    escribe. Solo el catálogo local a propósito: ir a USDA/Open Food Facts en
    cada pulsación sería lento y gastaría cuota de API para nada — el que
    resuelve alimentos fuera del catálogo sigue siendo `estimar()`, una vez
    el usuario ya eligió/terminó de escribir uno.
    Los que EMPIEZAN por la consulta van antes que los que solo la
    contienen, así que escribir "poll" sube "Pollo" antes que cualquier
    alimento que lo mencione de pasada."""
    q = normalizar(consulta)
    if len(q) < LONGITUD_MINIMA_COINCIDENCIA_PARCIAL:
        return []

    empiezan: list[str] = []
    contienen: list[str] = []
    for nombre, claves_norm in _CLAVES_POR_ALIMENTO:
        if any(c.startswith(q) for c in claves_norm):
            empiezan.append(nombre)
        elif any(q in c for c in claves_norm):
            contienen.append(nombre)

    return (empiezan + contienen)[:limite]


# ============================================================
# Adivinar categoría de un resultado EXTERNO (USDA/Open Food Facts) — solo
# para habilitar el modo Referencias sobre él. Las macros de ese resultado
# nunca dependen de esto, así que un fallo aquí (categoria=None) solo apaga
# Referencias para ese alimento concreto, no afecta la precisión de Gramos.
# ============================================================
_PALABRAS_CATEGORIA: dict[str, list[str]] = {
    "proteina": ["chicken", "pollo", "beef", "ternera", "pork", "cerdo", "turkey", "pavo",
                 "fish", "pescado", "salmon", "tuna", "atun", "egg", "huevo", "shrimp",
                 "gamba", "meat", "carne", "tofu"],
    "carbohidrato": ["rice", "arroz", "pasta", "potato", "patata", "bread", "pan", "oat",
                      "avena", "quinoa", "lentil", "lenteja", "bean", "alubia", "garbanzo",
                      "chickpea", "cereal", "cuscus", "couscous"],
    "verdura": ["broccoli", "brocoli", "spinach", "espinaca", "lettuce", "lechuga", "tomato",
                "tomate", "carrot", "zanahoria", "pepper", "pimiento", "onion", "cebolla",
                "vegetable", "verdura", "mushroom", "champinon"],
    "fruta": ["apple", "manzana", "banana", "platano", "orange", "naranja", "berry", "fresa",
              "grape", "uva", "melon", "pear", "pera", "fruit", "fruta", "kiwi"],
    "grasa": ["oil", "aceite", "butter", "mantequilla", "almond", "almendra", "nut", "nuez",
              "peanut", "cacahuete", "olive", "aceituna", "avocado", "aguacate"],
    "lacteo": ["milk", "leche", "yogurt", "yogur", "cheese", "queso", "dairy"],
    "bebida": ["shake", "smoothie", "juice", "zumo", "jugo", "drink", "bebida", "batido"],
}


def _adivinar_categoria(nombre: str) -> str | None:
    q = f" {normalizar(nombre)} "
    for categoria, palabras in _PALABRAS_CATEGORIA.items():
        for palabra in palabras:
            if re.search(r"\b" + re.escape(palabra) + r"\b", q):
                return categoria
    return None


# ============================================================
# Referencias corporales/de plato -> gramos, por categoría del alimento.
# Método de la mano (Precision Nutrition) + método del plato de Harvard —
# ambos ampliamente usados por nutricionistas, no una escala inventada para
# esta app. Una unidad solo aparece para las categorías donde tiene sentido
# real (no hay "pulgar de verdura").
# ============================================================
REFERENCIAS_GRAMOS: dict[str, dict[str, float]] = {
    "palma": {"proteina": 120, "lacteo": 150},
    "puno": {"carbohidrato": 150, "verdura": 100},
    "punado": {"grasa": 30, "fruta": 40},
    "pulgar": {"grasa": 15},
    "vaso": {"lacteo": 200, "bebida": 200},
    "botella": {"lacteo": 330, "bebida": 330},
    "cuarto_plato": {"proteina": 100, "carbohidrato": 130, "verdura": 130, "fruta": 90, "grasa": 25, "lacteo": 90},
    "media_plato": {"proteina": 200, "carbohidrato": 260, "verdura": 260, "fruta": 180, "grasa": 50, "lacteo": 180},
    "plato_completo": {"proteina": 350, "carbohidrato": 400, "verdura": 400, "fruta": 300, "grasa": 80, "lacteo": 300},
}


def _resolver_gramos(
    cantidad_g: float | None,
    referencia_unidad: str | None,
    referencia_cantidad: float,
    categoria: str | None,
) -> tuple[float, dict | None]:
    if cantidad_g is not None:
        if cantidad_g <= 0:
            raise ValueError("cantidad_g debe ser mayor que 0")
        return float(cantidad_g), None

    if not referencia_unidad:
        raise ValueError("hay que indicar cantidad_g o referencia_unidad")

    tabla = REFERENCIAS_GRAMOS.get(referencia_unidad)
    if tabla is None:
        raise ValueError(f"unidad de referencia desconocida: '{referencia_unidad}'")

    gramos_por_unidad = tabla.get(categoria) if categoria else None
    if gramos_por_unidad is None:
        raise ReferenciaNoDisponibleError(referencia_unidad, categoria)

    cantidad = referencia_cantidad if referencia_cantidad and referencia_cantidad > 0 else 1.0
    gramos = gramos_por_unidad * cantidad
    return gramos, {
        "unidad": referencia_unidad,
        "cantidad": cantidad,
        "gramos_por_unidad": gramos_por_unidad,
    }


# ============================================================
# Fuentes externas (USDA / Open Food Facts): a la vez y con caché
# ============================================================
# `estimar()` no se llama una vez por alimento: el formulario manual la dispara
# 500 ms después de cada pulsación (manual_food_entry_card.dart), así que
# escribir "pechuga de pollo" son también "pec", "pechu", "pechuga d"... y cada
# una que el catálogo local no reconozca salía a la red. Encadenadas —USDA y
# solo después Open Food Facts, 10 s de timeout cada una— eso es hasta 20 s por
# pulsación, y las mismas consultas fallidas repetidas contra la cuota de USDA
# (1000 req/h con key propia, mucho menos con DEMO_KEY).
#
# Nada de esto cambia QUÉ se responde, solo lo que cuesta responderlo:
#  - Las dos fuentes se lanzan A LA VEZ. Si USDA trae macros se devuelve sin
#    esperar a Open Food Facts, así que el caso bueno no se ralentiza; el peor
#    caso pasa de 20 s a 10 s.
#  - Se cachea el resultado, y TAMBIÉN el "no lo encuentra nadie": teclear deja
#    un reguero de prefijos que no existen en ninguna base, y son justo los que
#    más se repiten. Sin cachear los negativos, el prefijo se pagaría entero
#    cada vez que el usuario borra una letra y la vuelve a escribir.
_CACHE_TTL_SEGUNDOS = 6 * 60 * 60
_CACHE_MAX_ENTRADAS = 512

_cache_externo: OrderedDict[str, tuple[float, dict | None]] = OrderedDict()
_cache_lock = threading.Lock()

# Los handlers de main.py corren en el threadpool de Starlette, así que varias
# estimaciones pueden entrar aquí a la vez: 4 hilos dan para dos búsquedas
# simultáneas sin que una espere a la otra.
_pool_externo = futures.ThreadPoolExecutor(max_workers=4, thread_name_prefix="food-lookup")


def _cache_leer(clave: str) -> tuple[bool, dict | None]:
    """(hubo_acierto, valor). El valor cacheado puede ser None legítimamente —
    de ahí el booleano, y no un `if valor:` en la llamada."""
    with _cache_lock:
        entrada = _cache_externo.get(clave)
        if entrada is None:
            return False, None
        guardado_en, valor = entrada
        if time.monotonic() - guardado_en > _CACHE_TTL_SEGUNDOS:
            del _cache_externo[clave]
            return False, None
        _cache_externo.move_to_end(clave)
        return True, valor


def _cache_guardar(clave: str, valor: dict | None) -> None:
    with _cache_lock:
        _cache_externo[clave] = (time.monotonic(), valor)
        _cache_externo.move_to_end(clave)
        while len(_cache_externo) > _CACHE_MAX_ENTRADAS:
            _cache_externo.popitem(last=False)


def _tiene_macros(resultado: dict | None) -> bool:
    """Un resultado sin kcal no sirve para estimar nada: es exactamente el que
    antes se colaba como `usda or off` y cortaba el paso a Open Food Facts."""
    return bool(resultado) and resultado.get("kcal_100g") is not None


def _resultado_o_none(tarea: "futures.Future[dict | None]") -> dict | None:
    """Los dos clientes ya devuelven None ante cualquier fallo de red, pero un
    error inesperado dentro del hilo no puede tumbar la estimación entera."""
    try:
        return tarea.result()
    except Exception:
        return None


def buscar_externo(consulta: str) -> dict | None:
    """USDA y Open Food Facts en paralelo. Mantiene la preferencia de siempre
    (USDA para ingrediente crudo, Open Food Facts para envasado) pero solo
    entre resultados que traigan kcal. None si ninguno reconoce el alimento."""
    clave = normalizar(consulta)
    if not clave:
        return None

    en_cache, valor = _cache_leer(clave)
    if en_cache:
        return valor

    tarea_usda = _pool_externo.submit(usda_client.buscar_alimento, consulta)
    tarea_off = _pool_externo.submit(openfoodfacts_client.buscar_producto, consulta)

    usda = _resultado_o_none(tarea_usda)
    if _tiene_macros(usda):
        # Open Food Facts sigue en vuelo; no la esperamos (su hilo termina
        # solo y su resultado se descarta): esperarla sería pagar su timeout
        # para nada cuando ya tenemos la respuesta buena.
        resultado = usda
    else:
        off = _resultado_o_none(tarea_off)
        resultado = off if _tiene_macros(off) else None

    _cache_guardar(clave, resultado)
    return resultado


def estimar(
    nombre_alimento: str,
    cantidad_g: float | None = None,
    referencia_unidad: str | None = None,
    referencia_cantidad: float = 1.0,
) -> dict:
    """Punto de entrada único del endpoint. Nunca inventa un número: si nada
    (catálogo local, USDA, Open Food Facts) reconoce el alimento, levanta
    AlimentoNoEncontradoError en vez de devolver ceros silenciosos — un 0 kcal
    guardado en el diario es peor que un error, porque parece un dato real."""
    consulta = (nombre_alimento or "").strip()
    if not consulta:
        raise ValueError("nombre_alimento vacío")

    local = buscar_local(consulta)
    if local:
        nombre_resuelto = local["nombre"]
        categoria = local["categoria"]
        kcal_100g = local["kcal_100g"]
        proteinas_100g = local["proteinas_100g"]
        carbohidratos_100g = local["carbohidratos_100g"]
        grasas_100g = local["grasas_100g"]
        fuente = "local"
        coincidencia_exacta = True
    else:
        externo = buscar_externo(consulta)
        if not externo:
            raise AlimentoNoEncontradoError(consulta)
        nombre_resuelto = externo.get("nombre") or consulta
        categoria = _adivinar_categoria(nombre_resuelto)
        kcal_100g = externo["kcal_100g"]
        proteinas_100g = externo.get("proteinas_100g") or 0
        carbohidratos_100g = externo.get("carbohidratos_100g") or 0
        grasas_100g = externo.get("grasas_100g") or 0
        fuente = externo.get("fuente", "externo")
        coincidencia_exacta = False

    gramos, referencia_aplicada = _resolver_gramos(cantidad_g, referencia_unidad, referencia_cantidad, categoria)
    factor = gramos / 100.0

    return {
        "nombre_alimento": nombre_resuelto,
        "categoria": categoria,
        "cantidad_g": round(gramos, 1),
        "calorias_consumidas": round(kcal_100g * factor),
        "proteinas_g": round(proteinas_100g * factor, 1),
        "carbohidratos_g": round(carbohidratos_100g * factor, 1),
        "grasas_g": round(grasas_100g * factor, 1),
        "fuente": fuente,
        "coincidencia_exacta": coincidencia_exacta,
        "referencia_aplicada": referencia_aplicada,
    }
