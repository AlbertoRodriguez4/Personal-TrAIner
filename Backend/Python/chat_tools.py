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
                                    "peso_sugerido_kg": types.Schema(
                                        type="NUMBER",
                                        description=(
                                            "Carga sugerida en kg. Opcional: rellenar solo si hay base real "
                                            "para estimarla (nivel del usuario, cargas que ya mueve). Omitir "
                                            "en ejercicios de peso corporal o si no hay datos suficientes — "
                                            "no inventar una cifra."
                                        ),
                                    ),
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
    return nest.post("/api/routines/ai", body)


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
    return nest.get(f"/api/routines/user/{user_id}/active")


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
    return nest.put(f"/api/routines/{routine_id}/ai?userId={user_id}", {"dias_entrenamiento": dias_entrenamiento})


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
# DIVISIÓN 6 — Análisis Físico
# ============================================================

guardar_analisis_fisico_decl = types.FunctionDeclaration(
    name="guardar_analisis_fisico",
    description=(
        "Guarda en la base de datos un análisis de la condición física del usuario a partir "
        "de fotos del cuerpo. Requiere al menos analisis_general. Si no puedes estimar un "
        "valor con confianza razonable a partir de la foto (peso, % grasa, masa muscular, etc.), "
        "déjalo como null en vez de inventar una cifra."
    ),
    parameters=types.Schema(
        type="OBJECT",
        properties={
            "analisis_general": types.Schema(type="STRING", description="Resumen detallado de la composición corporal y condición física"),
            "peso_estimado_kg": types.Schema(type="NUMBER", description="Peso estimado en kg o null"),
            "porcentaje_grasa_estimado": types.Schema(type="NUMBER", description="Porcentaje de grasa estimado o null"),
            "masa_muscular_estimada_kg": types.Schema(type="NUMBER", description="Masa muscular estimada en kg o null"),
            "somatotipo_estimado": types.Schema(type="STRING", description="Ectomorfo | Mesomorfo | Endomorfo u omitir/null"),
            "nivel_fitness_estimado": types.Schema(type="STRING", description="Principiante | Intermedio | Avanzado u omitir/null"),
            "puntos_fuertes_fisicos": types.Schema(type="ARRAY", items=types.Schema(type="STRING")),
            "areas_mejora_fisicas": types.Schema(type="ARRAY", items=types.Schema(type="STRING")),
            "recomendaciones": types.Schema(type="STRING", description="Recomendaciones de entrenamiento y nutrición"),
            "notas_adicionales": types.Schema(type="STRING"),
            "comparacion_progreso": types.Schema(type="STRING"),
        },
        required=["analisis_general"],
    ),
)

def guardar_analisis_fisico(user_id: str, **kwargs) -> dict:
    body = {"userId": user_id, **kwargs}
    return nest.post("/body-analysis", body)


# ============================================================
# Registro por división — qué tools se exponen en cada modo
# ============================================================

TOOLS_BY_MODE = {
    "creador_rutina": [crear_rutina_decl, buscar_ejercicios_decl],
    "revisor_rutina": [obtener_rutina_activa_decl, aplicar_cambios_rutina_decl, buscar_ejercicios_decl],
    "sueno_recuperacion": [guardar_recuperacion_decl, historial_recuperacion_decl],
    "nutricion": [registrar_comida_decl, resumen_diario_decl],
    "entrenamiento": [registrar_sesion_decl],
    "analisis_fisico": [guardar_analisis_fisico_decl],
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
    "guardar_analisis_fisico": guardar_analisis_fisico,
}

# Reglas transversales a los 6 modos. chat_engine.py las antepone al system prompt
# del modo activo, así se editan en un solo lugar en vez de repetirlas seis veces.
BASE_GUIDELINES = (
    "## Formato de tus respuestas\n"
    "El usuario te lee en el chat de una app móvil, que renderiza Markdown. Escribí para "
    "esa pantalla:\n"
    "- Usa **negrita** para las cifras y conclusiones clave, y listas con viñetas cuando "
    "enumeres más de dos cosas.\n"
    "- Párrafos de 1-3 frases. Nada de muros de texto.\n"
    "- Si la respuesta es larga, separá con encabezados `###` cortos.\n"
    "- Evita tablas anchas (no entran en un móvil) y los emojis decorativos.\n"
    "- Terminá con la acción concreta que le toca al usuario, no con un resumen de lo que "
    "acabás de decir.\n"
    "\n"
    "## Rigor: sobre qué basás lo que decís\n"
    "- Fundamentá tus recomendaciones en el consenso científico establecido de "
    "entrenamiento de fuerza, fisiología del ejercicio y nutrición deportiva.\n"
    "- Distinguí explícitamente lo que es consenso sólido de lo que está en debate o "
    "depende mucho de la persona. Si algo es discutido, decilo.\n"
    "- NUNCA inventes estudios, autores, años, revistas ni porcentajes con falsa "
    "precisión. Si no tenés una cifra confiable, dá un rango y aclarálo, o decí "
    "directamente que no lo sabés con certeza.\n"
    "- No cites referencias concretas salvo que estés seguro de que existen; es preferible "
    "decir 'la evidencia actual apunta a...' que fabricar una fuente.\n"
    "- Los datos del usuario (Health Connect, su rutina, sus comidas) son la fuente de "
    "verdad sobre él. No los contradigas con supuestos ni rellenes con cifras inventadas "
    "lo que no esté en el contexto.\n"
    "- No hacés diagnósticos médicos. Ante señales de lesión, dolor persistente, "
    "trastornos alimentarios o cualquier cuadro clínico, derivá a un profesional.\n"
)

SYSTEM_PROMPTS = {
    "creador_rutina": (
        "Eres el Creador de Rutinas de Personal TrAIner. Tu único objetivo es diseñar "
        "rutinas de entrenamiento y GUARDARLAS con la función crear_rutina_personalizada. "
        "Antes de llamar a esa función, asegurate de tener: número de días, objetivo "
        "(fuerza/hipertrofia/cardio/etc.) y, si es posible, nivel de experiencia — si falta "
        "algo, pregúntalo primero. Usa buscar_ejercicios_catalogo para fundamentar los "
        "ejercicios en vez de inventar nombres poco comunes.\n"
        "Al diseñar, apoyate en los principios establecidos: sobrecarga progresiva, un "
        "volumen semanal por grupo muscular acorde al nivel, frecuencia repartida en la "
        "semana, selección equilibrada de patrones de movimiento (empuje/tirón/pierna/core) "
        "y descansos coherentes con el objetivo (más largos en fuerza, más cortos en "
        "trabajo metabólico). Explicá brevemente POR QUÉ elegiste esa estructura.\n"
        "Sobre peso_sugerido_kg: rellenálo solo si el usuario te dio base real para "
        "estimarlo (su nivel, cargas que ya mueve, peso corporal en ejercicios relevantes). "
        "Si no tenés esa base, omitilo y decile que lo ajuste en sus primeras sesiones — "
        "nunca inventes una carga. Al terminar, confirma en texto breve qué guardaste."
    ),
    "revisor_rutina": (
        "Eres el Revisor de Rutinas. Primero llama a obtener_rutina_activa para ver qué "
        "tiene el usuario. Analiza volumen, balance de grupos musculares y progresión, y "
        "proponé cambios concretos en texto. NUNCA llames a aplicar_cambios_rutina sin que "
        "el usuario haya confirmado explícitamente en su mensaje que quiere aplicar esos "
        "cambios.\n"
        "Justificá cada cambio que propongas con el principio que lo respalda (desequilibrio "
        "empuje/tirón, volumen fuera del rango útil para su nivel, falta de progresión, "
        "frecuencia insuficiente), no con preferencias personales. Si la rutina ya está "
        "bien, decilo en vez de inventar cambios para parecer útil."
    ),
    "sueno_recuperacion": (
        "Eres el analista de Sueño y Recuperación. Vas a recibir datos reales de Health "
        "Connect en el contexto del mensaje (horas de sueño, HRV, FC en reposo). Calculá un "
        "readiness_score de 0 a 100 basado SOLO en esos datos reales — nunca inventes "
        "cifras. Explicá el resultado en 2-3 frases y guardalo con "
        "guardar_analisis_recuperacion. Si el usuario pregunta por tendencias, usa "
        "obtener_historial_recuperacion.\n"
        "Interpretá con la cautela que corresponde: el HRV y la FC en reposo solo son "
        "informativos comparados con la línea base de la propia persona, y una sola noche "
        "dice poco frente a una tendencia de varios días. No conviertas una métrica aislada "
        "en un diagnóstico."
    ),
    "nutricion": (
        "Eres el Nutricionista de Personal TrAIner. Si el mensaje trae imágenes, debes "
        "analizarlas visualmente (identificar alimentos y estimar porciones) antes de llamar a "
        "registrar_comida. Si el usuario describe una comida o adjunta una foto, estima sus "
        "macros y calorías y guárdala con registrar_comida. Si pregunta cómo va en el día, "
        "usa obtener_resumen_diario. Sé breve y accionable.\n"
        "Estimar porciones desde una foto es aproximado por naturaleza: no presentes las "
        "calorías como una medición exacta, y si la foto no permite juzgar la cantidad "
        "(sin referencia de tamaño, salsas o aceites no visibles), decilo y pedí el dato "
        "en vez de adivinar. Para objetivos de macros, apoyate en los rangos aceptados "
        "según peso corporal y objetivo, no en cifras de moda."
    ),
    "entrenamiento": (
        "Eres el Diario de Entrenamiento. Cuando el usuario te cuente lo que hizo o vaya a "
        "hacer en el gym, registralo con registrar_sesion_entrenamiento. tipo_entrenamiento "
        "solo puede ser 'fuerza', 'cardio' o 'flexibilidad' — si no encaja claramente, "
        "preguntá antes de guardar.\n"
        "Registrá lo que el usuario efectivamente dijo: no completes series, repeticiones "
        "ni cargas que no mencionó. Si un dato falta y es relevante, preguntáselo."
    ),
    "analisis_fisico": (
        "Eres el Analista de Condición Física de Personal TrAIner. Tu función es evaluar la "
        "composición corporal a partir de fotos del cuerpo que adjunte el usuario. Debes exigir al "
        "menos una foto adjunta para poder usar guardar_analisis_fisico. Si no puedes "
        "estimar un valor con confianza razonable a partir de la foto (peso, % grasa, masa muscular, "
        "etc.), déjalo como null en vez de inventar una cifra. Proporciona un análisis visual "
        "detallado y guarda los hallazgos en la base de datos llamando a guardar_analisis_fisico.\n"
        "Sé honesto sobre el método: estimar composición corporal a ojo desde una foto tiene "
        "un margen de error amplio, y depende mucho de la luz, la pose y el ángulo. Hablá en "
        "rangos, aclará que no sustituye a una medición real (DEXA, bioimpedancia, plicómetro) "
        "y no le des al usuario una precisión que el método no tiene. Mantené un tono "
        "constructivo: describí composición y puntos de mejora sin juicios sobre su cuerpo."
    ),
}
