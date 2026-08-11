from google.genai import types
import nest_client as nest


# ============================================================
# DIVISIÓN 1 — Creador de Rutina
# ============================================================

crear_rutina_decl = types.FunctionDeclaration(
    name="crear_rutina_personalizada",
    description=(
        "Crea y GUARDA en la base de datos una rutina de entrenamiento nueva para el "
        "usuario. Úsala solo cuando ya tengas todos los datos necesarios (si el usuario "
        "no especificó número de días, objetivo o nivel, pregúntaselo antes de llamar "
        "a esta función)."
    ),
    parameters=types.Schema(
        type="OBJECT",
        properties={
            "nombre_rutina": types.Schema(type="STRING", description="Nombre corto, ej. 'Fuerza 6 días - Push Pull Legs'"),
            "tipo_entrenamiento": types.Schema(type="STRING", description="Ej. 'Fuerza', 'Hipertrofia', 'Cardio', 'Full Body'"),
            "numero_dias": types.Schema(type="INTEGER", description="Entre 1 y 7"),
            "dias_entrenamiento": types.Schema(
                type="ARRAY",
                items=types.Schema(
                    type="OBJECT",
                    properties={
                        "numero_dia": types.Schema(type="INTEGER"),
                        "nombre_dia": types.Schema(type="STRING", description="Ej. 'Empuje', 'Tirón', 'Pierna'"),
                        "grupo_muscular": types.Schema(type="STRING"),
                        "ejercicios": types.Schema(
                            type="ARRAY",
                            items=types.Schema(
                                type="OBJECT",
                                properties={
                                    "nombre": types.Schema(type="STRING"),
                                    "series": types.Schema(type="INTEGER"),
                                    "repeticiones": types.Schema(type="INTEGER"),
                                    "descanso_segundos": types.Schema(type="INTEGER"),
                                    "notas": types.Schema(type="STRING"),
                                },
                                required=["nombre", "series", "repeticiones", "descanso_segundos"],
                            ),
                        ),
                    },
                    required=["numero_dia", "nombre_dia", "grupo_muscular", "ejercicios"],
                ),
            ),
            "notas_adicionales": types.Schema(type="STRING"),
        },
        required=["nombre_rutina", "tipo_entrenamiento", "numero_dias", "dias_entrenamiento"],
    ),
)

def crear_rutina_personalizada(user_id: str, **kwargs) -> dict:
    body = {"userId": user_id, "activa": True, **kwargs}
    return nest.post("/custom-routines", body)


buscar_ejercicios_decl = types.FunctionDeclaration(
    name="buscar_ejercicios_catalogo",
    description="Busca ejercicios válidos en el catálogo, opcionalmente filtrados por grupo muscular. Úsala para fundamentar los ejercicios antes de crear una rutina, en vez de inventar nombres.",
    parameters=types.Schema(
        type="OBJECT",
        properties={"grupo_muscular": types.Schema(type="STRING")},
    ),
)

def buscar_ejercicios_catalogo(user_id: str, grupo_muscular: str | None = None) -> dict:
    params = {"grupo": grupo_muscular} if grupo_muscular else None
    return {"ejercicios": nest.get("/exercises-catalog", params=params)}


# ============================================================
# DIVISIÓN 2 — Revisor de Rutina
# ============================================================

obtener_rutina_activa_decl = types.FunctionDeclaration(
    name="obtener_rutina_activa",
    description="Obtiene la rutina activa actual del usuario para poder analizarla o proponer cambios.",
    parameters=types.Schema(type="OBJECT", properties={}),
)

def obtener_rutina_activa(user_id: str) -> dict:
    return nest.get(f"/custom-routines/user/{user_id}/active")


aplicar_cambios_rutina_decl = types.FunctionDeclaration(
    name="aplicar_cambios_rutina",
    description=(
        "Sobreescribe los días/ejercicios de una rutina existente. SOLO llamar después de "
        "que el usuario haya confirmado explícitamente que quiere aplicar los cambios "
        "propuestos (un 'sí', 'dale', 'aplícalo', etc. en su último mensaje)."
    ),
    parameters=types.Schema(
        type="OBJECT",
        properties={
            "routine_id": types.Schema(type="STRING"),
            "dias_entrenamiento": crear_rutina_decl.parameters.properties["dias_entrenamiento"],
        },
        required=["routine_id", "dias_entrenamiento"],
    ),
)

def aplicar_cambios_rutina(user_id: str, routine_id: str, dias_entrenamiento: list) -> dict:
    return nest.put(f"/custom-routines/{routine_id}", {"dias_entrenamiento": dias_entrenamiento})


# ============================================================
# DIVISIÓN 3 — Sueño y Recuperación
# ============================================================

guardar_recuperacion_decl = types.FunctionDeclaration(
    name="guardar_analisis_recuperacion",
    description=(
        "Guarda en el historial el análisis de recuperación del día, con un readiness_score "
        "de 0 a 100 que vos calculás en base a los datos reales de Health Connect que te "
        "pasaron en el contexto del mensaje. Nunca inventes horas de sueño o HRV que no "
        "estén en ese contexto."
    ),
    parameters=types.Schema(
        type="OBJECT",
        properties={
            "fecha": types.Schema(type="STRING", description="YYYY-MM-DD"),
            "horas_sueno": types.Schema(type="NUMBER"),
            "hrv_estado": types.Schema(type="STRING", description="'low' | 'normal' | 'high'"),
            "frecuencia_cardiaca_reposo": types.Schema(type="INTEGER"),
            "readiness_score": types.Schema(type="INTEGER", description="0-100"),
            "notas_ia": types.Schema(type="STRING"),
        },
        required=["fecha", "readiness_score", "notas_ia"],
    ),
)

def guardar_analisis_recuperacion(user_id: str, **kwargs) -> dict:
    body = {"userId": user_id, "fuente": "mi_fitness_health_connect", **kwargs}
    return nest.post("/recovery-logs", body)


historial_recuperacion_decl = types.FunctionDeclaration(
    name="obtener_historial_recuperacion",
    description="Trae el historial de recuperación de los últimos N días para detectar tendencias.",
    parameters=types.Schema(
        type="OBJECT",
        properties={"dias": types.Schema(type="INTEGER", description="Default 7")},
    ),
)

def obtener_historial_recuperacion(user_id: str, dias: int = 7) -> dict:
    return {"registros": nest.get(f"/recovery-logs/user/{user_id}", params={"days": dias})}


# ============================================================
# DIVISIÓN 4 — Nutrición
# ============================================================

registrar_comida_decl = types.FunctionDeclaration(
    name="registrar_comida",
    description="Registra una comida/ingesta del usuario en su diario nutricional.",
    parameters=types.Schema(
        type="OBJECT",
        properties={
            "fecha_registro": types.Schema(type="STRING", description="YYYY-MM-DD"),
            "calorias_consumidas": types.Schema(type="INTEGER"),
            "proteinas_g": types.Schema(type="NUMBER"),
            "carbohidratos_g": types.Schema(type="NUMBER"),
            "grasas_g": types.Schema(type="NUMBER"),
            "notas": types.Schema(type="STRING"),
        },
        required=["fecha_registro", "calorias_consumidas", "proteinas_g", "carbohidratos_g", "grasas_g"],
    ),
)

def registrar_comida(user_id: str, **kwargs) -> dict:
    return nest.post("/nutrition-logs", {"userId": user_id, **kwargs})


resumen_diario_decl = types.FunctionDeclaration(
    name="obtener_resumen_diario",
    description="Trae cuánto lleva consumido el usuario hoy vs. sus objetivos de macros.",
    parameters=types.Schema(type="OBJECT", properties={}),
)

def obtener_resumen_diario(user_id: str) -> dict:
    return nest.get(f"/daily/{user_id}")


# ============================================================
# DIVISIÓN 5 — Diario de Entrenamiento
# ============================================================

registrar_sesion_decl = types.FunctionDeclaration(
    name="registrar_sesion_entrenamiento",
    description="Registra que el usuario completó (o va a hacer) una sesión de entrenamiento.",
    parameters=types.Schema(
        type="OBJECT",
        properties={
            "fecha_programada": types.Schema(type="STRING", description="ISO 8601"),
            "tipo_entrenamiento": types.Schema(type="STRING", description="Solo uno de: 'fuerza', 'cardio', 'flexibilidad'"),
            "ejercicios": types.Schema(type="ARRAY", items=types.Schema(type="OBJECT")),
            "estado": types.Schema(type="STRING", description="'pendiente' | 'completado'"),
        },
        required=["fecha_programada", "tipo_entrenamiento", "ejercicios"],
    ),
)

def registrar_sesion_entrenamiento(user_id: str, **kwargs) -> dict:
    return nest.post("/training-sessions", {"userId": user_id, **kwargs})


# ============================================================
# Registro por división — qué tools se exponen en cada modo
# ============================================================

TOOLS_BY_MODE = {
    "creador_rutina": [crear_rutina_decl, buscar_ejercicios_decl],
    "revisor_rutina": [obtener_rutina_activa_decl, aplicar_cambios_rutina_decl, buscar_ejercicios_decl],
    "sueno_recuperacion": [guardar_recuperacion_decl, historial_recuperacion_decl],
    "nutricion": [registrar_comida_decl, resumen_diario_decl],
    "entrenamiento": [registrar_sesion_decl],
}

EXECUTORS = {
    "crear_rutina_personalizada": crear_rutina_personalizada,
    "buscar_ejercicios_catalogo": buscar_ejercicios_catalogo,
    "obtener_rutina_activa": obtener_rutina_activa,
    "aplicar_cambios_rutina": aplicar_cambios_rutina,
    "guardar_analisis_recuperacion": guardar_analisis_recuperacion,
    "obtener_historial_recuperacion": obtener_historial_recuperacion,
    "registrar_comida": registrar_comida,
    "obtener_resumen_diario": obtener_resumen_diario,
    "registrar_sesion_entrenamiento": registrar_sesion_entrenamiento,
}

SYSTEM_PROMPTS = {
    "creador_rutina": (
        "Eres el Creador de Rutinas de Personal TrAIner. Tu único objetivo es diseñar "
        "rutinas de entrenamiento y GUARDARLAS con la función crear_rutina_personalizada. "
        "Antes de llamar a esa función, asegurate de tener: número de días, objetivo "
        "(fuerza/hipertrofia/cardio/etc.) y, si es posible, nivel de experiencia — si falta "
        "algo, pregúntalo primero. Usa buscar_ejercicios_catalogo para fundamentar los "
        "ejercicios en vez de inventar nombres poco comunes. Al terminar, confirma en "
        "texto breve qué guardaste."
    ),
    "revisor_rutina": (
        "Eres el Revisor de Rutinas. Primero llama a obtener_rutina_activa para ver qué "
        "tiene el usuario. Analiza volumen, balance de grupos musculares y progresión, y "
        "proponé cambios concretos en texto. NUNCA llames a aplicar_cambios_rutina sin que "
        "el usuario haya confirmado explícitamente en su mensaje que quiere aplicar esos "
        "cambios."
    ),
    "sueno_recuperacion": (
        "Eres el analista de Sueño y Recuperación. Vas a recibir datos reales de Health "
        "Connect en el contexto del mensaje (horas de sueño, HRV, FC en reposo). Calculá un "
        "readiness_score de 0 a 100 basado SOLO en esos datos reales — nunca inventes "
        "cifras. Explicá el resultado en 2-3 frases y guardalo con "
        "guardar_analisis_recuperacion. Si el usuario pregunta por tendencias, usa "
        "obtener_historial_recuperacion."
    ),
    "nutricion": (
        "Eres el Nutricionista de Personal TrAIner. Si el usuario describe una comida, "
        "estima sus macros y calorías y guárdala con registrar_comida. Si pregunta cómo va "
        "en el día, usa obtener_resumen_diario. Sé breve y accionable."
    ),
    "entrenamiento": (
        "Eres el Diario de Entrenamiento. Cuando el usuario te cuente lo que hizo o vaya a "
        "hacer en el gym, registralo con registrar_sesion_entrenamiento. tipo_entrenamiento "
        "solo puede ser 'fuerza', 'cardio' o 'flexibilidad' — si no encaja claramente, "
        "preguntá antes de guardar."
    ),
}
