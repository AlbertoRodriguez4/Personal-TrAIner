"""Composición corporal: peso, IMC, grasa, masa magra y compañía.

Es el dato que más pesa en todo lo que hace la app — de aquí salen las calorías,
los macros y la decisión entre superávit y recomposición —, así que este módulo
tiene una regla que lo distingue del resto del backend de IA: **no llama a
ningún modelo**.

Son números medidos por un aparato, contrastados contra escalas publicadas
(ACE, OMS, Kouri). No hay nada que interpretar y meter un LLM en medio solo
añadiría latencia, coste y la posibilidad de que redondee un 15,2 a "unos 15".
La lectura la escribe `clinical_reference` con tramos citados; la narrativa,
Pulso en el chat, que ya recibe estos datos en cada turno vía `ai_profile`.

Lo único que sí necesita modelo es leer un PDF de un DEXA, y de eso se encarga
`clinical_analysis`, que ya tiene el documento delante: aquí solo entran los
números que salen de ahí.
"""
import math
from datetime import date

import clinical_reference as ref
import nest_client as nest

METODOS = ("dexa", "bioimpedancia", "plicometria", "bascula", "otro")
METODO_POR_DEFECTO = "dexa"

# Los campos que se guardan, en el orden en que se piden y se enseñan. `derivado`
# marca los que el backend de NestJS calcula solo a partir de los demás: se
# muestran, pero no se piden — teclearlos a mano solo consigue que no cuadren.
CAMPOS = [
    {"codigo": "peso_kg", "nombre": "Peso", "unidad": "kg", "derivado": False},
    {"codigo": "porcentaje_grasa", "nombre": "Grasa corporal", "unidad": "%", "derivado": False},
    {"codigo": "masa_grasa_kg", "nombre": "Masa grasa", "unidad": "kg", "derivado": True},
    {"codigo": "masa_magra_kg", "nombre": "Masa magra", "unidad": "kg", "derivado": True},
    {"codigo": "masa_muscular_kg", "nombre": "Masa muscular", "unidad": "kg", "derivado": False},
    {"codigo": "musculo_pct", "nombre": "Músculo", "unidad": "%", "derivado": True},
    {"codigo": "musculo_esqueletico_pct", "nombre": "Músculo esquelético", "unidad": "%", "derivado": False},
    {"codigo": "masa_osea_kg", "nombre": "Masa ósea", "unidad": "kg", "derivado": False},
    {"codigo": "densidad_osea", "nombre": "Densidad ósea", "unidad": "g/cm²", "derivado": False},
    {"codigo": "proteina_kg", "nombre": "Proteína", "unidad": "kg", "derivado": False},
    {"codigo": "proteina_pct", "nombre": "Proteína", "unidad": "%", "derivado": True},
    {"codigo": "agua_corporal_kg", "nombre": "Agua corporal", "unidad": "kg", "derivado": False},
    {"codigo": "agua_corporal_pct", "nombre": "Agua corporal", "unidad": "%", "derivado": True},
    {"codigo": "grasa_subcutanea_pct", "nombre": "Grasa subcutánea", "unidad": "%", "derivado": False},
    {"codigo": "grasa_visceral", "nombre": "Grasa visceral", "unidad": "nivel", "derivado": False},
    {"codigo": "tmb_kcal", "nombre": "Metabolismo basal", "unidad": "kcal", "derivado": False},
    {"codigo": "edad_corporal", "nombre": "Edad corporal", "unidad": "años", "derivado": False},
    {"codigo": "peso_ideal_kg", "nombre": "Peso estándar", "unidad": "kg", "derivado": False},
    {"codigo": "imc", "nombre": "IMC", "unidad": "", "derivado": True},
    {"codigo": "ffmi", "nombre": "FFMI", "unidad": "", "derivado": True},
]

# Los `derivado` los calcula NestJS a partir de los demás y NO se mandan: si el
# cliente enviara el porcentaje de músculo además de los kg, los dos números
# podrían no cuadrar y ganaría el que llegase, no el correcto.
CAMPOS_EDITABLES = [c["codigo"] for c in CAMPOS if not c["derivado"]]

# Rangos de plausibilidad. No son rangos clínicos: solo cazan el error de dedo
# (un 78 en el campo de grasa, un 1,80 en el de peso) antes de que se guarde y
# contamine el histórico y todos los cálculos que salen de él.
LIMITES = {
    "peso_kg": (20, 400),
    "porcentaje_grasa": (2, 70),
    "masa_grasa_kg": (0, 200),
    "masa_magra_kg": (10, 200),
    "masa_muscular_kg": (5, 150),
    "musculo_pct": (10, 95),
    "musculo_esqueletico_pct": (10, 95),
    "masa_osea_kg": (0.5, 10),
    "densidad_osea": (0.3, 2.5),
    "proteina_kg": (1, 50),
    "proteina_pct": (5, 40),
    "agua_corporal_kg": (10, 150),
    "agua_corporal_pct": (20, 80),
    "grasa_subcutanea_pct": (1, 60),
    "grasa_visceral": (0, 60),
    "tmb_kcal": (600, 5000),
    "edad_corporal": (5, 120),
    "peso_ideal_kg": (20, 400),
}

# Los que se guardan como entero: un "20.0 años" de edad corporal o un TMB con
# decimales quedan mal en pantalla y no aportan precisión ninguna.
CAMPOS_ENTEROS = {"tmb_kcal", "edad_corporal"}


class ValorFueraDeRangoError(ValueError):
    """Un número que no puede ser lo que dice ser (grasa al 78 %, peso de 5 kg)."""


def _numero(valor) -> float | None:
    if valor is None or valor == "":
        return None
    try:
        numero = float(str(valor).replace(",", "."))
    except (TypeError, ValueError):
        return None
    return numero if math.isfinite(numero) else None


def normalizar(medidas: dict) -> dict:
    """Deja solo los campos editables con un número plausible dentro."""
    limpio: dict = {}
    for codigo in CAMPOS_EDITABLES:
        numero = _numero(medidas.get(codigo))
        if numero is None:
            continue
        minimo, maximo = LIMITES[codigo]
        if not (minimo <= numero <= maximo):
            nombre = next(c["nombre"] for c in CAMPOS if c["codigo"] == codigo)
            raise ValorFueraDeRangoError(
                f"{nombre}: {numero} está fuera de lo posible ({minimo}–{maximo}). Revísalo."
            )
        limpio[codigo] = int(round(numero)) if codigo in CAMPOS_ENTEROS else round(numero, 2)
    return limpio


def _fecha_valida(valor: str | None) -> str:
    if valor:
        try:
            return date.fromisoformat(str(valor).strip()[:10]).isoformat()
        except ValueError:
            pass
    return date.today().isoformat()


def _perfil_para_clasificar(user_id: str) -> tuple[str | None, float | None]:
    """Sexo y altura, que es lo que hace falta para clasificar. Si no se pueden
    leer, se devuelve (None, None) y la clasificación simplemente sale más
    corta: es preferible a suponer un sexo, que cambiaría el tramo entero."""
    try:
        perfil = nest.get(f"/ai-context/{user_id}") or {}
    except Exception:  # noqa: BLE001 — el guardado ya salió bien; esto solo adorna
        return None, None
    basicos = perfil.get("datos_basicos") or {}
    return basicos.get("sexo"), _numero(basicos.get("altura_cm"))


def _lecturas(medicion: dict, clasificacion: dict) -> list[str]:
    """Las frases que se enseñan bajo los números. Se componen a partir de los
    tramos ya calculados: cada una es trazable a una fuente citada."""
    frases = []
    if clasificacion.get("grasa"):
        g = clasificacion["grasa"]
        frases.append(
            f"Con un {medicion['porcentaje_grasa']} % de grasa estás en el tramo "
            f"«{g['categoria']}» de la escala del ACE para {g['sexo_aplicado']}."
        )
    if clasificacion.get("imc"):
        i = clasificacion["imc"]
        frases.append(f"Tu IMC es {i['imc']} → {i['categoria']} según la OMS.")
    if clasificacion.get("ffmi"):
        f = clasificacion["ffmi"]
        frases.append(
            f"Tu FFMI es {f['ffmi']}: {f['categoria']}. Mide cuánta masa magra tienes "
            "para tu estatura, que es lo que el IMC no distingue."
        )
    if clasificacion.get("proteina_objetivo_g_dia"):
        p = clasificacion["proteina_objetivo_g_dia"]
        frases.append(
            f"Para tu peso, el objetivo de proteína está en {p['min']}–{p['max']} g al día (ISSN)."
        )
    if clasificacion.get("fiabilidad"):
        frases.append("Fiabilidad de la medida: " + clasificacion["fiabilidad"]["nota"] + ".")
    return frases


def _fuentes(clasificacion: dict) -> list[dict]:
    fuentes = []
    for clave, tipo in (
        ("grasa", "categorias_grasa_corporal"),
        ("imc", "clasificacion_imc"),
        ("ffmi", "indice_masa_libre_grasa"),
        ("proteina_objetivo_g_dia", "proteina_objetivo"),
    ):
        dato = clasificacion.get(clave)
        if dato and dato.get("fuente"):
            fuentes.append({"tipo": tipo, "fuente": dato["fuente"]})
    return fuentes


def _resultado(medicion: dict, user_id: str) -> dict:
    sexo, altura = _perfil_para_clasificar(user_id)
    clasificacion = ref.clasificar_composicion(medicion, sexo, altura)
    return {
        "medicion": medicion,
        "clasificacion": clasificacion,
        "lecturas": _lecturas(medicion, clasificacion),
        "fuentes_consultadas": _fuentes(clasificacion),
        "sin_clasificar": not clasificacion.get("grasa") and not sexo,
    }


def registrar(user_id: str, medidas: dict, fecha: str | None = None,
              metodo: str | None = None, notas: str | None = None) -> dict:
    """Guarda una medición y devuelve cómo queda clasificada.

    NestJS es quien deriva IMC, masa grasa, masa magra y FFMI de lo que llegue,
    así que lo que se clasifica aquí es la fila ya guardada, no el formulario:
    lo que ve el usuario en pantalla es exactamente lo que leerá Pulso después.
    """
    limpio = normalizar(medidas)
    if not limpio:
        raise ValueError(
            "Rellena al menos un valor. Con el peso ya se puede empezar; "
            "el porcentaje de grasa es el que más aporta."
        )

    metodo_final = metodo if metodo in METODOS else METODO_POR_DEFECTO
    guardado = nest.post("/dexa-scans", {
        "userId": user_id,
        "fecha_escaneo": _fecha_valida(fecha),
        "metodo": metodo_final,
        "notas": notas or None,
        **limpio,
    })
    return _resultado(guardado or {}, user_id)


def desde_documento(user_id: str, extraido: dict | None, fecha: str | None,
                    metodo: str | None = None, notas: str | None = None) -> dict | None:
    """Guarda la composición que venga dentro de un informe (DEXA, InBody…).

    Devuelve None si el documento no traía ninguna, que es el caso normal en una
    analítica de sangre.

    No levanta: para cuando se llama a esto el informe clínico ya está redactado
    y guardado, y tirarlo entero porque el aparato imprimió un porcentaje de
    grasa raro sería un mal negocio. Pero tampoco lo esconde — el fallo vuelve
    en `error` para que la pantalla pueda decir que esa parte no se guardó."""
    if not extraido:
        return None
    try:
        return registrar(user_id, extraido, fecha=fecha, metodo=metodo, notas=notas)
    except Exception as exc:  # noqa: BLE001
        return {"error": str(exc), "medicion": None}
