"""Catálogo de biomarcadores relevantes para construir físico, con su código
LOINC, rango de referencia orientativo y la fuente concreta de la que sale ese
rango. Es la mitad "offline" del contexto contrastado: MedlinePlus (ver
`medlineplus_client.py`) explica QUÉ es cada prueba con la voz oficial del
NIH/NLM, pero su API no devuelve números — los rangos viven aquí.

Reglas duras de uso, para que esto no se convierta en un diagnóstico de juguete:

1. **El rango impreso en el informe del propio laboratorio SIEMPRE gana.** Cada
   laboratorio calibra sus métodos y publica su rango; el de esta tabla es solo
   el que se aplica cuando el documento no trae ninguno.
2. Son rangos de **población adulta general**, no de deportistas. Varios se
   mueven mucho con sexo, edad y método analítico — los que más, llevan `nota`.
3. Nada de esto es un diagnóstico. Clasificar un valor como "alto" solo sirve
   para decidir de qué hablar y para derivar a un profesional, nunca para
   concluir una patología.

Los códigos LOINC están verificados uno a uno contra MedlinePlus Connect: los 33
devuelven contenido real en español.
"""
import re

# ============================================================
# Fuentes citadas (el texto que se le pasa al modelo y se guarda
# en `fuentes_consultadas` para poder auditar de dónde salió cada cifra)
# ============================================================

FUENTES = {
    "atp3": "NHLBI — NCEP ATP III (panel de lípidos en adultos)",
    "ada": "American Diabetes Association — Standards of Care (glucemia y HbA1c)",
    "nih_ods": "NIH Office of Dietary Supplements (vitaminas y minerales)",
    "nlm": "MedlinePlus / U.S. National Library of Medicine (rangos de laboratorio habituales)",
    "who_hb": "OMS — umbrales de hemoglobina para anemia en adultos",
    "cdc_t": "CDC Hormone Standardization Program — rango armonizado de testosterona total en varones adultos",
    "kdigo": "KDIGO — clasificación de función renal por TFG estimada",
    "ace": "American Council on Exercise — categorías de porcentaje de grasa corporal",
    "who_imc": "OMS — clasificación del IMC en adultos",
    "issn": "International Society of Sports Nutrition — position stand sobre proteína y ejercicio",
    "ffmi_kouri": "Kouri et al. (1995), Clinical Journal of Sport Medicine — índice de masa libre de grasa (FFMI)",
}


# ============================================================
# Biomarcadores
# ============================================================
# rango: (min, max) en la `unidad` indicada. None en un extremo = sin límite por
# ese lado (p. ej. el colesterol total no tiene mínimo clínicamente accionable
# en este contexto).
#
# `porque_importa` es lo que convierte una analítica en algo que cambia una
# rutina: es el texto que el modelo usa para justificar decisiones de
# entrenamiento y macros, y el que se persiste en `relevancia_fisico`.

BIOMARCADORES = {
    # ---------- Perfil lipídico ----------
    "colesterol_total": {
        "nombre": "Colesterol total",
        "loinc": "2093-3",
        "unidad": "mg/dL",
        "rango": (None, 200),
        "fuente": "atp3",
        "porque_importa": (
            "Marca el margen que hay para dietas altas en grasa saturada en volumen. "
            "No limita el entrenamiento por sí solo."
        ),
    },
    "hdl": {
        "nombre": "Colesterol HDL",
        "loinc": "2085-9",
        "unidad": "mg/dL",
        "rango": (40, None),
        "fuente": "atp3",
        "nota": "El umbral deseable es ≥40 mg/dL en hombres y ≥50 mg/dL en mujeres.",
        "porque_importa": (
            "Sube con el trabajo aeróbico regular: es uno de los pocos marcadores que "
            "responde a añadir cardio a una rutina de fuerza."
        ),
    },
    "ldl": {
        "nombre": "Colesterol LDL",
        "loinc": "13457-7",
        "unidad": "mg/dL",
        "rango": (None, 130),
        "fuente": "atp3",
        "nota": "<100 mg/dL es el objetivo óptimo; el umbral aplicable depende del riesgo cardiovascular global.",
        "porque_importa": "Condiciona el perfil de grasas de la dieta en fases de superávit calórico.",
    },
    "trigliceridos": {
        "nombre": "Triglicéridos",
        "loinc": "2571-8",
        "unidad": "mg/dL",
        "rango": (None, 150),
        "fuente": "atp3",
        "porque_importa": (
            "Muy sensibles al exceso de hidratos refinados y alcohol. Elevados en un "
            "superávit sugieren revisar la fuente de los carbohidratos antes que recortar calorías."
        ),
    },

    # ---------- Metabolismo de la glucosa ----------
    "glucosa": {
        "nombre": "Glucosa en ayunas",
        "loinc": "1558-6",
        "unidad": "mg/dL",
        "rango": (70, 99),
        "fuente": "ada",
        "nota": "100-125 mg/dL en ayunas es el rango de prediabetes según la ADA.",
        "porque_importa": (
            "Determina cómo repartir los hidratos alrededor del entrenamiento y si "
            "conviene priorizar un déficit antes que un volumen."
        ),
    },
    "hba1c": {
        "nombre": "Hemoglobina glicosilada (HbA1c)",
        "loinc": "4548-4",
        "unidad": "%",
        "rango": (None, 5.7),
        "fuente": "ada",
        "nota": "5,7-6,4 % es prediabetes; ≥6,5 % es criterio diagnóstico de diabetes (ADA).",
        "porque_importa": "Media de 2-3 meses: no la mueve una comida, sí un cambio real de dieta.",
    },
    "insulina": {
        "nombre": "Insulina en ayunas",
        "loinc": "20448-7",
        "unidad": "µUI/mL",
        "rango": (2, 25),
        "fuente": "nlm",
        "nota": "Rango muy dependiente del método del laboratorio; interpretar solo junto a la glucosa.",
        "porque_importa": "Con glucosa normal pero insulina alta, la partición de nutrientes empeora en superávit.",
    },

    # ---------- Vitaminas y minerales ----------
    "vitamina_d": {
        "nombre": "Vitamina D (25-hidroxi)",
        "loinc": "1989-3",
        "unidad": "ng/mL",
        "rango": (20, 100),
        "fuente": "nih_ods",
        "nota": "El NIH considera ≥20 ng/mL suficiente para hueso y salud general; muchos laboratorios usan ≥30 ng/mL.",
        "porque_importa": (
            "Déficit asociado a peor función neuromuscular y más molestias osteomusculares: "
            "relevante cuando la queja es fatiga o estancamiento de fuerza."
        ),
    },
    "vitamina_b12": {
        "nombre": "Vitamina B12",
        "loinc": "2132-9",
        "unidad": "pg/mL",
        "rango": (200, 900),
        "fuente": "nih_ods",
        "porque_importa": "Vigilar en dietas vegetarianas/veganas altas en volumen de entrenamiento.",
    },
    "magnesio": {
        "nombre": "Magnesio",
        "loinc": "2601-3",
        "unidad": "mg/dL",
        "rango": (1.7, 2.2),
        "fuente": "nih_ods",
        "porque_importa": "Implicado en contracción muscular y calidad del sueño, que es donde se recupera.",
    },
    "zinc": {
        "nombre": "Zinc",
        "loinc": "5763-8",
        "unidad": "µg/dL",
        "rango": (60, 120),
        "fuente": "nih_ods",
        "porque_importa": "Pérdidas por sudor elevadas en cargas altas; interviene en la función hormonal.",
    },
    "calcio": {
        "nombre": "Calcio",
        "loinc": "17861-6",
        "unidad": "mg/dL",
        "rango": (8.6, 10.3),
        "fuente": "nlm",
        "porque_importa": "Salud ósea bajo carga; relevante en déficits calóricos prolongados.",
    },

    # ---------- Hierro y serie roja ----------
    "ferritina": {
        "nombre": "Ferritina",
        "loinc": "2276-4",
        "unidad": "ng/mL",
        "rango": (30, 300),
        "fuente": "nlm",
        "nota": "Rango habitual 30-300 ng/mL en hombres y 15-200 ng/mL en mujeres. Sube también por inflamación, no solo por hierro.",
        "porque_importa": (
            "Reservas de hierro bajas explican fatiga y caída del rendimiento aeróbico "
            "incluso con hemoglobina normal — causa frecuente de estancamiento."
        ),
    },
    "hierro_serico": {
        "nombre": "Hierro sérico",
        "loinc": "2498-4",
        "unidad": "µg/dL",
        "rango": (60, 170),
        "fuente": "nlm",
        "nota": "Varía mucho a lo largo del día; poco informativo sin ferritina y transferrina.",
        "porque_importa": "Se lee junto a la ferritina, nunca solo.",
    },
    "hemoglobina": {
        "nombre": "Hemoglobina",
        "loinc": "718-7",
        "unidad": "g/dL",
        "rango": (12.0, 17.5),
        "fuente": "who_hb",
        "nota": "Umbral de anemia: <13 g/dL en hombres y <12 g/dL en mujeres no embarazadas (OMS).",
        "porque_importa": "Transporte de oxígeno: techo directo del trabajo aeróbico y de la recuperación entre series.",
    },
    "hematocrito": {
        "nombre": "Hematocrito",
        "loinc": "4544-3",
        "unidad": "%",
        "rango": (35.5, 48.6),
        "fuente": "nlm",
        "nota": "Rango habitual 38,3-48,6 % en hombres y 35,5-44,9 % en mujeres.",
        "porque_importa": "Se interpreta junto a la hemoglobina; la deshidratación lo eleva de forma artificial.",
    },

    # ---------- Perfil hormonal ----------
    "testosterona_total": {
        "nombre": "Testosterona total",
        "loinc": "2986-8",
        "unidad": "ng/dL",
        "rango": (264, 916),
        "fuente": "cdc_t",
        "nota": "Rango armonizado por el CDC para varones adultos sanos de 19-39 años. En mujeres el rango es ~15-70 ng/dL. Extracción por la mañana.",
        "porque_importa": (
            "Influye en la capacidad de ganar masa magra. Valores bajos mantenidos son motivo "
            "de consulta médica, no de ajustar la rutina por tu cuenta."
        ),
    },
    "shbg": {
        "nombre": "SHBG (globulina fijadora de hormonas sexuales)",
        "loinc": "13967-5",
        "unidad": "nmol/L",
        "rango": (10, 57),
        "fuente": "nlm",
        "nota": "Rango habitual 10-57 nmol/L en hombres y 18-144 nmol/L en mujeres.",
        "porque_importa": "Sin ella, una testosterona total normal puede esconder una fracción libre baja.",
    },
    "tsh": {
        "nombre": "TSH (tirotropina)",
        "loinc": "3016-3",
        "unidad": "mUI/L",
        "rango": (0.4, 4.0),
        "fuente": "nlm",
        "porque_importa": (
            "La función tiroidea marca el gasto energético basal: altera el cálculo de "
            "calorías de mantenimiento sobre el que se construye todo lo demás."
        ),
    },
    "t4_libre": {
        "nombre": "T4 libre",
        "loinc": "3024-7",
        "unidad": "ng/dL",
        "rango": (0.8, 1.8),
        "fuente": "nlm",
        "porque_importa": "Se lee siempre junto a la TSH.",
    },
    "cortisol": {
        "nombre": "Cortisol (matinal)",
        "loinc": "2143-6",
        "unidad": "µg/dL",
        "rango": (6, 23),
        "fuente": "nlm",
        "nota": "Solo interpretable con la hora de extracción: tiene ritmo circadiano marcado.",
        "porque_importa": "Un valor alto aislado no prueba sobreentrenamiento; se lee con sueño, HRV y carga.",
    },

    # ---------- Riñón, hígado y músculo ----------
    "creatinina": {
        "nombre": "Creatinina",
        "loinc": "2160-0",
        "unidad": "mg/dL",
        "rango": (0.59, 1.35),
        "fuente": "nlm",
        "nota": "Rango habitual 0,74-1,35 mg/dL en hombres y 0,59-1,04 mg/dL en mujeres. Sube con más masa muscular y con la suplementación con creatina, sin que eso implique daño renal.",
        "porque_importa": (
            "Es EL falso positivo clásico en gente que entrena: mucha masa magra o creatina "
            "la elevan. Hay que decírselo al usuario en vez de alarmarlo."
        ),
    },
    "tfg": {
        "nombre": "Tasa de filtrado glomerular estimada (TFGe)",
        "loinc": "33914-3",
        "unidad": "mL/min/1,73m²",
        "rango": (60, None),
        "fuente": "kdigo",
        "porque_importa": "Con función renal reducida, las dietas muy altas en proteína dejan de ser inocuas y requieren criterio médico.",
    },
    "urea": {
        "nombre": "Urea / nitrógeno ureico (BUN)",
        "loinc": "3094-0",
        "unidad": "mg/dL",
        "rango": (7, 20),
        "fuente": "nlm",
        "porque_importa": "Sube con ingestas proteicas altas y con deshidratación; se lee junto a creatinina y TFG.",
    },
    "alt": {
        "nombre": "ALT (GPT)",
        "loinc": "1742-6",
        "unidad": "U/L",
        "rango": (7, 55),
        "fuente": "nlm",
        "porque_importa": "Puede elevarse de forma transitoria tras entrenamientos muy intensos, no solo por causa hepática.",
    },
    "ast": {
        "nombre": "AST (GOT)",
        "loinc": "1920-8",
        "unidad": "U/L",
        "rango": (8, 48),
        "fuente": "nlm",
        "porque_importa": "También está en el músculo: sube con el daño muscular del entrenamiento, junto a la CK.",
    },
    "ggt": {
        "nombre": "GGT",
        "loinc": "2324-2",
        "unidad": "U/L",
        "rango": (8, 61),
        "fuente": "nlm",
        "porque_importa": "Ayuda a separar una elevación hepática real de una de origen muscular.",
    },
    "ck": {
        "nombre": "Creatina quinasa (CK/CPK)",
        "loinc": "2157-6",
        "unidad": "U/L",
        "rango": (30, 200),
        "fuente": "nlm",
        "nota": "Se multiplica por varias veces durante 24-72 h tras entrenamiento excéntrico intenso; sin reposo previo el valor no es interpretable.",
        "porque_importa": (
            "El mejor marcador de daño muscular residual: elevada sin causa de entrenamiento "
            "reciente sugiere bajar volumen; elevada tras una sesión dura es esperable."
        ),
    },

    # ---------- Inflamación y otros ----------
    "pcr": {
        "nombre": "Proteína C reactiva (PCR)",
        "loinc": "1988-5",
        "unidad": "mg/L",
        "rango": (None, 3),
        "fuente": "nlm",
        "porque_importa": "Inflamación sistémica sostenida: contexto para no subir volumen de entrenamiento.",
    },
    "acido_urico": {
        "nombre": "Ácido úrico",
        "loinc": "3084-1",
        "unidad": "mg/dL",
        "rango": (3.5, 7.2),
        "fuente": "nlm",
        "porque_importa": "Relevante en dietas muy altas en proteína animal.",
    },
    "albumina": {
        "nombre": "Albúmina",
        "loinc": "1751-7",
        "unidad": "g/dL",
        "rango": (3.4, 5.4),
        "fuente": "nlm",
        "porque_importa": "Proxy grueso del estado nutricional en déficits calóricos prolongados.",
    },
    "sodio": {
        "nombre": "Sodio",
        "loinc": "2951-2",
        "unidad": "mmol/L",
        "rango": (135, 145),
        "fuente": "nlm",
        "porque_importa": "Contexto de hidratación en sesiones largas o con mucha sudoración.",
    },
    "potasio": {
        "nombre": "Potasio",
        "loinc": "2823-3",
        "unidad": "mmol/L",
        "rango": (3.5, 5.2),
        "fuente": "nlm",
        "porque_importa": "Función neuromuscular; se altera con diuréticos y con pérdidas por sudor muy altas.",
    },
}


# ============================================================
# Normalización de nombres de laboratorio → código canónico
# ============================================================
# Los informes españoles escriben lo mismo de diez maneras ("GPT (ALT)",
# "Transaminasa GPT", "ALAT"). Sin esta tabla cada analítica crearía códigos
# nuevos y la serie temporal de un marcador se partiría en trozos.

SINONIMOS = {
    "colesterol_total": ["colesterol total", "colesterol", "col total", "colesterol serico", "cholesterol total"],
    "hdl": ["hdl", "colesterol hdl", "hdl colesterol", "c-hdl", "hdl-c", "colesterol de alta densidad"],
    "ldl": ["ldl", "colesterol ldl", "ldl colesterol", "c-ldl", "ldl-c", "colesterol de baja densidad"],
    "trigliceridos": ["trigliceridos", "trigliceridos sericos", "tg", "triglycerides"],
    "glucosa": ["glucosa", "glucosa basal", "glucemia", "glucosa en ayunas", "glucemia basal", "glucose"],
    "hba1c": ["hba1c", "hemoglobina glicosilada", "hemoglobina glicada", "a1c", "hemoglobina a1c", "glicohemoglobina"],
    "insulina": ["insulina", "insulina basal", "insulina en ayunas"],
    "vitamina_d": ["vitamina d", "25 oh vitamina d", "25-oh-vitamina d", "vitamina d 25 hidroxi", "calcidiol", "25 hidroxivitamina d"],
    "vitamina_b12": ["vitamina b12", "b12", "cobalamina", "vitamina b-12"],
    "magnesio": ["magnesio", "mg serico"],
    "zinc": ["zinc", "zn"],
    "calcio": ["calcio", "calcio serico", "ca"],
    "ferritina": ["ferritina", "ferritina serica"],
    "hierro_serico": ["hierro", "hierro serico", "sideremia", "fe"],
    "hemoglobina": ["hemoglobina", "hb", "hgb"],
    "hematocrito": ["hematocrito", "hto", "hct"],
    "testosterona_total": ["testosterona", "testosterona total", "testosterona serica"],
    "shbg": ["shbg", "globulina fijadora de hormonas sexuales", "globulina transportadora"],
    "tsh": ["tsh", "tirotropina", "hormona estimulante del tiroides"],
    "t4_libre": ["t4 libre", "t4l", "tiroxina libre", "ft4"],
    "cortisol": ["cortisol", "cortisol basal", "cortisol matinal"],
    "creatinina": ["creatinina", "creatinina serica", "crea"],
    "tfg": ["tfg", "filtrado glomerular", "fg estimado", "egfr", "tasa de filtrado glomerular", "ckd-epi", "mdrd"],
    "urea": ["urea", "nitrogeno ureico", "bun", "nus"],
    "alt": ["alt", "gpt", "alat", "transaminasa gpt", "alanina aminotransferasa"],
    "ast": ["ast", "got", "asat", "transaminasa got", "aspartato aminotransferasa"],
    "ggt": ["ggt", "gamma gt", "gamma glutamil transferasa", "gamma-gt"],
    "ck": ["ck", "cpk", "creatina quinasa", "creatin kinasa", "creatinfosfoquinasa", "creatina cinasa"],
    "pcr": ["pcr", "proteina c reactiva", "crp", "pcr ultrasensible", "hs-crp"],
    "acido_urico": ["acido urico", "urato", "uric acid"],
    "albumina": ["albumina", "albumina serica"],
    "sodio": ["sodio", "na", "natremia"],
    "potasio": ["potasio", "k", "kalemia"],
}

_TRADUCTOR_TILDES = str.maketrans("áéíóúüñ", "aeiouun")


def _normalizar(texto: str) -> str:
    limpio = texto.strip().lower().translate(_TRADUCTOR_TILDES)
    return " ".join(limpio.replace("_", " ").replace("-", " ").split())


_INDICE_SINONIMOS = {
    _normalizar(alias): codigo
    for codigo, aliases in SINONIMOS.items()
    for alias in aliases
}


# Longitud a partir de la cual un alias puede casar dentro de un nombre más
# largo. Los símbolos químicos de una o dos letras ("ca", "na", "k", "fe", "mg")
# solo valen como nombre completo.
#
# No es una precaución teórica: con coincidencia por subcadena, "Masa
# Esquelética" casaba con calcio (por el "ca" de esqueléti-CA) y "Cantidad de
# proteína" con sodio (por el "na" de proteí-NA). Un informe de báscula acababa
# guardando dos biomarcadores de sangre inventados, con sus kg como si fueran
# mg/dL, y el coach hablaba después de un déficit de calcio que nadie midió.
LONGITUD_MINIMA_ALIAS_PARCIAL = 3


def normalizar_codigo(nombre: str) -> str | None:
    """Nombre tal cual lo imprime el laboratorio → código canónico, o None si no
    es un marcador del catálogo (una analítica trae decenas de valores que no
    aportan nada a construir físico; los descartamos en vez de guardar ruido)."""
    if not nombre:
        return None
    clave = _normalizar(nombre)
    if clave in BIOMARCADORES:
        return clave
    if clave in _INDICE_SINONIMOS:
        return _INDICE_SINONIMOS[clave]

    # Coincidencia parcial: "colesterol total (calculado)" o "GPT (ALT) suero".
    # Dos condiciones, y las dos hacen falta:
    #   - el alias tiene que casar como PALABRA completa (`\b`), no como trozo
    #     de otra: si no, cualquier palabra que contenga "ca" es calcio;
    #   - y tener al menos `LONGITUD_MINIMA_ALIAS_PARCIAL` caracteres, porque
    #     hasta con límites de palabra un "k" o un "na" sueltos dentro de una
    #     frase larga son casi siempre casualidad.
    # Se prefiere el alias más largo para que "colesterol hdl" no caiga en
    # "colesterol" (que mapea a colesterol_total).
    candidatos = [
        (len(alias), codigo)
        for alias, codigo in _INDICE_SINONIMOS.items()
        if len(alias) >= LONGITUD_MINIMA_ALIAS_PARCIAL
        and re.search(rf"\b{re.escape(alias)}\b", clave)
    ]
    return max(candidatos)[1] if candidatos else None


def clasificar(codigo: str, valor: float, rango_min=None, rango_max=None) -> str:
    """'bajo' | 'normal' | 'alto' | 'desconocido'. Si llegan `rango_min`/
    `rango_max` (los del propio informe) mandan sobre los de la tabla."""
    ficha = BIOMARCADORES.get(codigo)
    if rango_min is None and rango_max is None:
        if not ficha:
            return "desconocido"
        rango_min, rango_max = ficha["rango"]
    if rango_min is not None and valor < rango_min:
        return "bajo"
    if rango_max is not None and valor > rango_max:
        return "alto"
    if rango_min is None and rango_max is None:
        return "desconocido"
    return "normal"


def ficha_referencia(codigo: str) -> dict | None:
    """Bloque de referencia de un marcador, listo para meter en un prompt."""
    ficha = BIOMARCADORES.get(codigo)
    if not ficha:
        return None
    rango_min, rango_max = ficha["rango"]
    return {
        "codigo": codigo,
        "nombre": ficha["nombre"],
        "loinc": ficha["loinc"],
        "unidad": ficha["unidad"],
        "rango_referencia": {"min": rango_min, "max": rango_max},
        "nota": ficha.get("nota"),
        "porque_importa_para_el_fisico": ficha["porque_importa"],
        "fuente": FUENTES[ficha["fuente"]],
    }


def fichas_referencia(codigos: list[str]) -> list[dict]:
    return [f for f in (ficha_referencia(c) for c in dict.fromkeys(codigos)) if f]


# ============================================================
# Composición corporal — normas para el análisis por fotos
# ============================================================

CATEGORIAS_GRASA_ACE = {
    "hombre": [
        (2, 5, "grasa esencial"),
        (6, 13, "rango de atleta"),
        (14, 17, "en forma"),
        (18, 24, "media poblacional"),
        (25, None, "obesidad"),
    ],
    "mujer": [
        (10, 13, "grasa esencial"),
        (14, 20, "rango de atleta"),
        (21, 24, "en forma"),
        (25, 31, "media poblacional"),
        (32, None, "obesidad"),
    ],
}

CATEGORIAS_IMC_OMS = [
    (None, 18.5, "bajo peso"),
    (18.5, 25, "normopeso"),
    (25, 30, "sobrepeso"),
    (30, None, "obesidad"),
]

# Índice de masa libre de grasa: masa magra (kg) / altura (m)². Dice cuánto
# músculo hay PARA ESA ESTATURA, que es lo que el IMC no distingue — dos
# personas con el mismo IMC pueden tener 8 kg de diferencia en masa magra.
#
# Importa aquí porque es lo que separa "le queda mucho margen de crecimiento" de
# "está cerca de su techo": el estudio de Kouri sitúa en torno a 25 el máximo
# observado en varones sin ayuda farmacológica. Con margen de crecimiento amplio
# tiene sentido priorizar superávit y volumen; cerca del techo, recomposición.
CATEGORIAS_FFMI = {
    "hombre": [
        (None, 18, "masa magra por debajo de la media"),
        (18, 20, "media poblacional"),
        (20, 22, "claramente entrenado"),
        (22, 23, "muy musculado"),
        (23, 25, "cerca del techo natural"),
        (25, None, "por encima de lo observado sin ayuda farmacológica"),
    ],
    "mujer": [
        (None, 14, "masa magra por debajo de la media"),
        (14, 16, "media poblacional"),
        (16, 18, "claramente entrenada"),
        (18, 20, "muy musculada"),
        (20, None, "cerca del techo natural"),
    ],
}

# Ingesta proteica para ganar masa magra, según el position stand de la ISSN.
PROTEINA_G_POR_KG = {"min": 1.4, "max": 2.0, "fuente": FUENTES["issn"]}


def _clave_sexo(sexo: str | None) -> str:
    """Las categorías de grasa del ACE están tabuladas por sexo biológico y los
    tramos no se solapan, así que elegir mal la tabla cambia la clasificación
    entera. Ante un valor que no reconocemos se usa la tabla masculina, que es
    la más conservadora (exige menos grasa para cada etiqueta)."""
    return "mujer" if sexo and _normalizar(sexo).startswith(("f", "muj")) else "hombre"


def categoria_grasa(porcentaje: float | None, sexo: str | None) -> dict | None:
    """Clasifica un % de grasa según las categorías del ACE. None si falta el
    dato o el sexo — inventar el sexo cambiaría la categoría entera."""
    if porcentaje is None or not sexo:
        return None
    clave = _clave_sexo(sexo)
    for minimo, maximo, etiqueta in CATEGORIAS_GRASA_ACE[clave]:
        if porcentaje >= minimo and (maximo is None or porcentaje <= maximo):
            return {"categoria": etiqueta, "sexo_aplicado": clave, "fuente": FUENTES["ace"]}
    return None


def categoria_imc(peso_kg: float | None, altura_cm: float | None) -> dict | None:
    if not peso_kg or not altura_cm:
        return None
    imc = peso_kg / ((altura_cm / 100) ** 2)
    for minimo, maximo, etiqueta in CATEGORIAS_IMC_OMS:
        if (minimo is None or imc >= minimo) and (maximo is None or imc < maximo):
            return {"imc": round(imc, 1), "categoria": etiqueta, "fuente": FUENTES["who_imc"]}
    return None


def categoria_ffmi(ffmi: float | None, sexo: str | None) -> dict | None:
    """Sitúa un FFMI en su tramo. Como con la grasa, sin sexo no se clasifica:
    las escalas masculina y femenina están desplazadas ~4 puntos."""
    if ffmi is None or not sexo:
        return None
    clave = _clave_sexo(sexo)
    for minimo, maximo, etiqueta in CATEGORIAS_FFMI[clave]:
        if (minimo is None or ffmi >= minimo) and (maximo is None or ffmi < maximo):
            return {
                "ffmi": round(ffmi, 1),
                "categoria": etiqueta,
                "sexo_aplicado": clave,
                "fuente": FUENTES["ffmi_kouri"],
            }
    return None


# Fiabilidad de cada método de medida. No es un detalle cosmético: una báscula
# de bioimpedancia doméstica se mueve varios puntos porcentuales según la
# hidratación, así que una bajada de 2 puntos entre dos pesadas puede no ser
# nada. Va en el prompt para que la IA no lea como progreso lo que es ruido.
FIABILIDAD_METODO = {
    "dexa": "medición de referencia; sus cifras se pueden tomar como buenas",
    "plicometria": "fiable si la toma siempre la misma persona; ±3 puntos de grasa entre operadores",
    "bioimpedancia": "sensible a hidratación, hora del día y comidas; ±3-5 puntos de grasa entre pesadas",
    "bascula": "sensible a hidratación, hora del día y comidas; ±3-5 puntos de grasa entre pesadas",
    "otro": "fiabilidad desconocida; trátalo como orientativo",
}


def clasificar_composicion(medicion: dict | None, sexo: str | None,
                           altura_cm: float | None = None) -> dict:
    """Clasifica una medición de composición corporal contra las escalas
    publicadas. Determinista y sin modelo de por medio: son números medidos
    contra tramos citados, no hay nada que interpretar.

    Devuelve solo las claves que se han podido calcular — una báscula que solo
    da peso y grasa no produce categoría de FFMI, y rellenarla a ojo sería
    exactamente el error que este módulo existe para evitar."""
    if not medicion:
        return {}

    def _num(clave: str) -> float | None:
        valor = medicion.get(clave)
        if valor is None or valor == "":
            return None
        try:
            return float(valor)
        except (TypeError, ValueError):
            return None

    peso = _num("peso_kg")
    imc = _num("imc")
    resultado: dict = {}

    grasa = categoria_grasa(_num("porcentaje_grasa"), sexo)
    if grasa:
        resultado["grasa"] = grasa

    # El IMC guardado con la medición manda sobre el recalculado: se calculó con
    # la altura vigente entonces, y así el histórico no se mueve solo.
    if imc is not None:
        for minimo, maximo, etiqueta in CATEGORIAS_IMC_OMS:
            if (minimo is None or imc >= minimo) and (maximo is None or imc < maximo):
                resultado["imc"] = {
                    "imc": round(imc, 1),
                    "categoria": etiqueta,
                    "fuente": FUENTES["who_imc"],
                }
                break
    else:
        calculado = categoria_imc(peso, altura_cm)
        if calculado:
            resultado["imc"] = calculado

    ffmi = categoria_ffmi(_num("ffmi"), sexo)
    if ffmi:
        resultado["ffmi"] = ffmi

    metodo = (medicion.get("metodo") or "").strip().lower()
    if metodo:
        resultado["fiabilidad"] = {
            "metodo": metodo,
            "nota": FIABILIDAD_METODO.get(metodo, FIABILIDAD_METODO["otro"]),
        }

    if peso:
        resultado["proteina_objetivo_g_dia"] = {
            "min": round(peso * PROTEINA_G_POR_KG["min"]),
            "max": round(peso * PROTEINA_G_POR_KG["max"]),
            "fuente": PROTEINA_G_POR_KG["fuente"],
        }

    return resultado


def referencia_composicion_corporal(sexo: str | None, peso_kg: float | None, altura_cm: float | None) -> dict:
    """Bloque de normas contrastadas que se le antepone al modelo ANTES de que
    mire las fotos, para que clasifique contra una escala publicada en vez de
    contra su propia impresión."""
    clave = _clave_sexo(sexo)
    return {
        "categorias_grasa_corporal": {
            "sexo_aplicado": clave,
            "tramos": [
                {"desde": mn, "hasta": mx, "categoria": et}
                for mn, mx, et in CATEGORIAS_GRASA_ACE[clave]
            ],
            "fuente": FUENTES["ace"],
        },
        "imc": categoria_imc(peso_kg, altura_cm),
        "proteina_objetivo_g_por_kg": PROTEINA_G_POR_KG,
        "advertencia_metodo": (
            "Estas categorías se definieron sobre mediciones reales (plicometría, DEXA, "
            "bioimpedancia). Aplicarlas a una estimación visual hereda un margen de error "
            "amplio: úsalas para situar al usuario en un tramo, nunca para dar una cifra exacta."
        ),
    }
