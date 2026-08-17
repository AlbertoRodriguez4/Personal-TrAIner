from google.genai import types
import nest_client as nest
import wger_client
import openfoodfacts_client
import usda_client
import edamam_client
import openfda_client
from health_calculators import calcular_metricas_salud


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
            # OJO: esto viaja tal cual a `activity_type` en la BD (RoutineService
            # .createFromAiPayload no lo traduce) y la app Flutter lo usa como CLAVE para
            # buscar el tipo de actividad en una lista fija de 5. Un valor fuera de esa
            # lista ("Fuerza", "Hipertrofia") rompe la pantalla de rutina con
            # "Bad state: No element" y además esconde el campo de peso (solo se muestra
            # si el tipo es 'gym'). Por eso está restringido por enum: no lo aflojes.
            "tipo_entrenamiento": types.Schema(
                type="STRING",
                enum=["gym", "cardio", "calistenia", "yoga", "deportes"],
                description=(
                    "OBLIGATORIO uno exacto de: 'gym' (pesas/máquinas, incluye fuerza e "
                    "hipertrofia), 'cardio', 'calistenia' (peso corporal), 'yoga' "
                    "(yoga/pilates/flexibilidad), 'deportes'. En minúsculas y sin "
                    "variantes: no uses 'Fuerza', 'Hipertrofia' ni 'Full Body'."
                ),
            ),
            "numero_dias": types.Schema(type="INTEGER", description="Entre 1 y 7"),
            "dias_entrenamiento": types.Schema(
                type="ARRAY",
                items=types.Schema(
                    type="OBJECT",
                    properties={
                        "numero_dia": types.Schema(type="INTEGER"),
                        # La app Flutter renderiza el plan semanal cruzando este valor
                        # contra su lista fija de días (Lunes..Domingo). Si no coincide,
                        # la rutina se guarda pero la pantalla de edición sale VACÍA y
                        # al guardar se pierden los días. Por eso es enum y obligatorio.
                        "dia_semana": types.Schema(
                            type="STRING",
                            enum=["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"],
                            description=(
                                "Día real de la semana en que toca esta sesión, exactamente como "
                                "en la lista (con tilde y mayúscula inicial). Repartí los días de "
                                "entrenamiento a lo largo de la semana dejando descanso entre "
                                "sesiones del mismo grupo muscular (ej. para 3 días: Lunes, "
                                "Miércoles, Viernes), no los pongas todos seguidos."
                            ),
                        ),
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
                                            "Carga sugerida en kg. SIEMPRE hay que enviarlo: usa 0 cuando sea "
                                            "peso corporal o cuando no tengas base real para estimar la carga "
                                            "(nivel del usuario, cargas que ya mueve). El 0 deja el campo "
                                            "editable en la app para que el usuario ponga su peso real; "
                                            "omitirlo lo deja vacío. Nunca inventes una cifra: ante la duda, 0."
                                        ),
                                    ),
                                    "notas": types.Schema(type="STRING"),
                                },
                                required=["nombre", "series", "repeticiones", "descanso_segundos", "peso_sugerido_kg"],
                            ),
                        ),
                    },
                    required=["numero_dia", "dia_semana", "nombre_dia", "grupo_muscular", "ejercicios"],
                ),
            ),
            "notas_adicionales": types.Schema(type="STRING"),
        },
        required=["nombre_rutina", "tipo_entrenamiento", "numero_dias", "dias_entrenamiento"],
    ),
)

def _resumir_rutina(rutina: dict) -> dict:
    """Condensa la rutina completa que devuelve NestJS (cada ejercicio con series, reps,
    peso y notas) a lo mínimo para confirmar el guardado. El plan detallado ya está en los
    argumentos que el propio modelo generó para llamar a esta tool, así que reenviar la
    rutina entera acá lo duplica dentro de la conversación — eso es lo que hace que la
    llamada siguiente a Groq (redactar la respuesta) supere las 8000 TPM del tier gratuito
    y devuelva 413, aun cuando el guardado en sí ya salió bien."""
    dias = rutina.get("days") or []
    return {
        "guardado": True,
        "id": rutina.get("id"),
        "nombre": rutina.get("name"),
        "tipo_entrenamiento": rutina.get("activity_type"),
        "dias": [
            {
                "dia_semana": d.get("day_of_week"),
                "enfoque": d.get("focus"),
                "num_ejercicios": len(d.get("exercises") or []),
            }
            for d in dias
        ],
    }


def crear_rutina_personalizada(user_id: str, **kwargs) -> dict:
    body = {"userId": user_id, "activa": True, **kwargs}
    rutina = nest.post("/api/routines/ai", body)
    return _resumir_rutina(rutina)


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
    rutina = nest.put(f"/api/routines/{routine_id}/ai?userId={user_id}", {"dias_entrenamiento": dias_entrenamiento})
    return _resumir_rutina(rutina)


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
            "tipo_comida": types.Schema(
                type="STRING",
                description="Uno de: desayuno, comida, snack, cena, otro. Inferilo del "
                "mensaje del usuario o de la hora del día si no lo dice explícitamente.",
            ),
        },
        required=["fecha_registro", "calorias_consumidas", "proteinas_g", "carbohidratos_g", "grasas_g"],
    ),
)

def registrar_comida(user_id: str, **kwargs) -> dict:
    return nest.post("/nutrition-logs", {"userId": user_id, **kwargs})


estimar_comida_decl = types.FunctionDeclaration(
    name="estimar_comida",
    description=(
        "Reporta una estimación de macros/calorías de una comida SIN guardarla todavía. "
        "Úsala siempre que analices una foto o descripción de comida por primera vez: la "
        "app le muestra esta estimación al usuario y es la app la que la guarda cuando él "
        "la confirme con un botón, no esta llamada."
    ),
    parameters=types.Schema(
        type="OBJECT",
        properties={
            "nombre_alimento": types.Schema(type="STRING", description="Nombre corto y descriptivo del plato/alimento identificado"),
            "calorias_consumidas": types.Schema(type="INTEGER"),
            "proteinas_g": types.Schema(type="NUMBER"),
            "carbohidratos_g": types.Schema(type="NUMBER"),
            "grasas_g": types.Schema(type="NUMBER"),
            "notas": types.Schema(type="STRING"),
            "tipo_comida": types.Schema(
                type="STRING",
                description="Uno de: desayuno, comida, snack, cena, otro. Inferilo del "
                "mensaje del usuario o de la hora del día si no lo dice explícitamente.",
            ),
        },
        required=["nombre_alimento", "calorias_consumidas", "proteinas_g", "carbohidratos_g", "grasas_g"],
    ),
)

def estimar_comida(user_id: str, **kwargs) -> dict:
    return kwargs


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
# DIVISIÓN 7 — APIs externas (catálogos públicos, no datos del usuario)
# ============================================================
# Todas degradan a {"encontrado": False, ...} si la fuente externa no tiene
# match o falla — nunca levantan, son enriquecimiento, no persistencia
# crítica (ver backend_python_ai/SKILL.md).

calcular_metricas_decl = types.FunctionDeclaration(
    name="calcular_metricas_salud",
    description=(
        "Calcula IMC, TMB (metabolismo basal, fórmula Mifflin-St Jeor) y TDEE (gasto "
        "calórico diario total) a partir de peso, altura, edad, sexo y nivel de "
        "actividad. Fórmulas estándar, sin llamada externa. Úsala para fundamentar "
        "volumen/calorías sugeridas en vez de estimarlas de memoria."
    ),
    parameters=types.Schema(
        type="OBJECT",
        properties={
            "peso_kg": types.Schema(type="NUMBER"),
            "altura_cm": types.Schema(type="NUMBER"),
            "edad": types.Schema(type="INTEGER"),
            "sexo": types.Schema(type="STRING", description="'masculino' | 'femenino'"),
            "nivel_actividad": types.Schema(
                type="STRING",
                description="'sedentario' | 'ligero' | 'moderado' | 'activo' | 'muy_activo' (default 'moderado')",
            ),
        },
        required=["peso_kg", "altura_cm", "edad", "sexo"],
    ),
)
# calcular_metricas_salud se importa directo de health_calculators — ya tiene
# la firma (user_id, **kwargs) que espera _execute_tool, sin wrapper.


buscar_ejercicios_wger_decl = types.FunctionDeclaration(
    name="buscar_ejercicios_wger",
    description=(
        "Busca ejercicios en wger, un catálogo abierto más amplio que el propio, "
        "filtrando por grupo muscular y/o equipamiento disponible. Complementa a "
        "buscar_ejercicios_catalogo cuando este no alcanza — no lo reemplaza."
    ),
    parameters=types.Schema(
        type="OBJECT",
        properties={
            "grupo_muscular": types.Schema(
                type="STRING",
                description="Ej. 'pecho', 'espalda', 'piernas', 'hombros', 'brazos', 'abdomen', 'pantorrillas', 'cardio'",
            ),
            "equipamiento": types.Schema(
                type="STRING",
                description="Ej. 'mancuernas', 'barra', 'polea', 'peso corporal', 'banda elastica', 'kettlebell'",
            ),
        },
    ),
)

def buscar_ejercicios_wger(user_id: str, grupo_muscular: str | None = None, equipamiento: str | None = None) -> dict:
    return {"ejercicios": wger_client.buscar_ejercicios(grupo_muscular, equipamiento)}


buscar_producto_off_decl = types.FunctionDeclaration(
    name="buscar_producto_openfoodfacts",
    description=(
        "Busca un producto ENVASADO (nombre/marca leídos de la etiqueta en la foto, o "
        "código de barras) en Open Food Facts para obtener sus macros reales por 100g "
        "y su Nutri-Score/NOVA, en vez de estimarlos de memoria. Úsala solo cuando la "
        "comida sea un producto con marca identificable — no para platos caseros."
    ),
    parameters=types.Schema(
        type="OBJECT",
        properties={"consulta": types.Schema(type="STRING", description="Nombre+marca del producto, o código de barras")},
        required=["consulta"],
    ),
)

def buscar_producto_openfoodfacts(user_id: str, consulta: str) -> dict:
    producto = openfoodfacts_client.buscar_producto(consulta)
    return {"producto": producto} if producto else {"encontrado": False, "motivo": "sin match en Open Food Facts"}


buscar_alimento_usda_decl = types.FunctionDeclaration(
    name="buscar_alimento_usda",
    description=(
        "Busca el perfil nutricional preciso de un INGREDIENTE CRUDO/individual (ej. "
        "'chicken breast raw', 'brown rice cooked' — en inglés da mejores resultados) "
        "en USDA FoodData Central. Úsala cuando identifiques un ingrediente simple con "
        "confianza, en vez de estimar sus macros de memoria."
    ),
    parameters=types.Schema(
        type="OBJECT",
        properties={"nombre_alimento": types.Schema(type="STRING")},
        required=["nombre_alimento"],
    ),
)

def buscar_alimento_usda(user_id: str, nombre_alimento: str) -> dict:
    alimento = usda_client.buscar_alimento(nombre_alimento)
    return {"alimento": alimento} if alimento else {"encontrado": False, "motivo": "sin match en USDA FoodData Central"}


estimar_macros_edamam_decl = types.FunctionDeclaration(
    name="estimar_macros_ingredientes",
    description=(
        "Envía una lista de líneas de ingrediente en lenguaje natural (ej. ['2 huevos "
        "revueltos', '2 rebanadas de pan integral']) y devuelve el macro combinado de "
        "la comida completa. Úsala para PLATOS CASEROS con varios ingredientes mezclados, "
        "en vez de sumar estimaciones a mano."
    ),
    parameters=types.Schema(
        type="OBJECT",
        properties={"ingredientes": types.Schema(type="ARRAY", items=types.Schema(type="STRING"))},
        required=["ingredientes"],
    ),
)

def estimar_macros_ingredientes(user_id: str, ingredientes: list) -> dict:
    macros = edamam_client.estimar_macros(ingredientes)
    return {"macros": macros} if macros else {"encontrado": False, "motivo": "Edamam no disponible o sin match"}


buscar_medicamento_decl = types.FunctionDeclaration(
    name="buscar_medicamento_openfda",
    description=(
        "Busca información de la etiqueta OFICIAL de la FDA (indicaciones, "
        "advertencias, interacciones) de un medicamento o suplemento que el usuario "
        "haya mencionado. Es SOLO información de referencia — nunca un diagnóstico ni "
        "una recomendación de dosis, y hay que decírselo siempre al usuario."
    ),
    parameters=types.Schema(
        type="OBJECT",
        properties={"nombre": types.Schema(type="STRING", description="Nombre del medicamento/suplemento, en español o inglés")},
        required=["nombre"],
    ),
)

def buscar_medicamento_openfda(user_id: str, nombre: str) -> dict:
    info = openfda_client.buscar_medicamento(nombre)
    return {"medicamento": info} if info else {"encontrado": False, "motivo": "sin match en OpenFDA"}


# ============================================================
# Registro por división — qué tools se exponen en cada modo
# ============================================================

TOOLS_BY_MODE = {
    "creador_rutina": [
        crear_rutina_decl, buscar_ejercicios_decl, buscar_ejercicios_wger_decl, calcular_metricas_decl,
    ],
    "revisor_rutina": [
        obtener_rutina_activa_decl, aplicar_cambios_rutina_decl, buscar_ejercicios_decl, buscar_ejercicios_wger_decl,
    ],
    "sueno_recuperacion": [guardar_recuperacion_decl, historial_recuperacion_decl, buscar_medicamento_decl],
    "nutricion": [
        estimar_comida_decl, registrar_comida_decl, resumen_diario_decl,
        buscar_producto_off_decl, buscar_alimento_usda_decl, estimar_macros_edamam_decl, calcular_metricas_decl,
    ],
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
    "estimar_comida": estimar_comida,
    "obtener_resumen_diario": obtener_resumen_diario,
    "registrar_sesion_entrenamiento": registrar_sesion_entrenamiento,
    "guardar_analisis_fisico": guardar_analisis_fisico,
    # APIs externas (División 7)
    "calcular_metricas_salud": calcular_metricas_salud,
    "buscar_ejercicios_wger": buscar_ejercicios_wger,
    "buscar_producto_openfoodfacts": buscar_producto_openfoodfacts,
    "buscar_alimento_usda": buscar_alimento_usda,
    "estimar_macros_ingredientes": estimar_macros_ingredientes,
    "buscar_medicamento_openfda": buscar_medicamento_openfda,
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
    "- Los datos del usuario (Health Connect, su rutina, sus comidas, su análisis del físico "
    "y sus analíticas clínicas) son la fuente de verdad sobre él. No los contradigas con "
    "supuestos ni rellenes con cifras inventadas lo que no esté en el contexto.\n"
    "- Cuando tengas esos datos, ÚSALOS y citálos al justificar lo que recomendás. Si no los "
    "tenés, decilo abiertamente y pedile que los rellene, en vez de dar por personalizado un "
    "consejo genérico.\n"
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
        "ejercicios en vez de inventar nombres poco comunes, y buscar_ejercicios_wger "
        "cuando necesites variedad adicional por grupo muscular o equipamiento que el "
        "catálogo propio no cubra. Si el usuario te da peso/altura/edad/sexo, usa "
        "calcular_metricas_salud para fundamentar volumen y calorías sugeridas en su "
        "TDEE real en vez de una estimación genérica.\n"
        "PRESUPUESTO DE PASOS — importante: tenés un máximo de 8 llamadas a funciones por "
        "turno, y si las gastás investigando NO se crea la rutina y el usuario se queda "
        "sin nada. Haz como mucho 2 búsquedas en total (no una por cada grupo muscular: "
        "ya conocés los ejercicios básicos de sobra) y dedicá el resto a llamar a "
        "crear_rutina_personalizada, que es lo que el usuario realmente pidió. Ante la "
        "duda entre buscar una vez más o crear la rutina, creá la rutina.\n"
        "Al diseñar, apoyate en los principios establecidos: sobrecarga progresiva, un "
        "volumen semanal por grupo muscular acorde al nivel, frecuencia repartida en la "
        "semana, selección equilibrada de patrones de movimiento (empuje/tirón/pierna/core) "
        "y descansos coherentes con el objetivo (más largos en fuerza, más cortos en "
        "trabajo metabólico). Explicá brevemente POR QUÉ elegiste esa estructura.\n"
        "Sobre peso_sugerido_kg: rellenálo solo si el usuario te dio base real para "
        "estimarlo (su nivel, cargas que ya mueve, peso corporal en ejercicios relevantes). "
        "Si no tenés esa base, omitilo y decile que lo ajuste en sus primeras sesiones — "
        "nunca inventes una carga.\n"
        "Al terminar de llamar a crear_rutina_personalizada, tu respuesta final tiene que "
        "incluir, en este orden:\n"
        "1. El PLANTEAMIENTO: objetivo, estructura semanal y por qué elegiste esa estructura.\n"
        "2. Un desglose día por día en el que, POR CADA EJERCICIO, digas el nombre y en una "
        "línea corta (máximo 12 palabras) POR QUÉ lo elegiste para esta persona. Esto es "
        "obligatorio, no opcional: el usuario tiene que poder leer la justificación de cada "
        "ejercicio de su rutina.\n"
        "3. La razón de cada elección tiene que anclarse en algo REAL de su perfil siempre "
        "que lo tengas: sus grupos musculares retrasados, su prioridad de entrenamiento, su "
        "nivel, su objetivo, su equipamiento o una limitación clínica suya. Si un ejercicio "
        "está solo por el patrón de movimiento, dilo así ('empuje horizontal base') en vez de "
        "inventarle un motivo personalizado.\n"
        "Si el perfil trae **grupos musculares retrasados** o una **prioridad de "
        "entrenamiento**, la rutina TIENE que reflejarlos: más volumen o frecuencia en esos "
        "grupos, y colocados al principio de la sesión. Y tienes que explicarlo.\n"
        "No repitas series/repeticiones/peso de cada ejercicio: eso el usuario ya lo ve y lo "
        "edita en la pantalla de la rutina. Lo que no puede ver ahí es el porqué."
    ),
    "revisor_rutina": (
        "Eres el Revisor de Rutinas. Primero llama a obtener_rutina_activa para ver qué "
        "tiene el usuario. Analiza volumen, balance de grupos musculares y progresión, y "
        "proponé cambios concretos en texto. NUNCA llames a aplicar_cambios_rutina sin que "
        "el usuario haya confirmado explícitamente en su mensaje que quiere aplicar esos "
        "cambios. Si proponés reemplazar o sumar un ejercicio, podés usar "
        "buscar_ejercicios_wger para ofrecer alternativas reales en vez de inventar "
        "nombres.\n"
        "Justificá cada cambio que propongas con el principio que lo respalda (desequilibrio "
        "empuje/tirón, volumen fuera del rango útil para su nivel, falta de progresión, "
        "frecuencia insuficiente), no con preferencias personales. Si la rutina ya está "
        "bien, decilo en vez de inventar cambios para parecer útil.\n"
        "Cruza SIEMPRE la rutina actual con su perfil real: si tiene grupos musculares "
        "retrasados o una prioridad de entrenamiento registrada y la rutina no los ataca, ese "
        "es el primer cambio que tenés que proponer, citando el dato. Si tiene valores "
        "clínicos fuera de rango que condicionan la carga (CK alta, anemia, PCR elevada), "
        "tenelo en cuenta al proponer volumen, y derivá a un profesional en vez de "
        "interpretarlos vos.\n"
        "Al terminar de llamar a aplicar_cambios_rutina, confirma en un resumen breve día "
        "por día (enfoque y cantidad de ejercicios) qué quedó, sin repetir cada serie/"
        "repetición/peso — el usuario ya lo ve editable en la pantalla de la rutina."
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
        "en un diagnóstico.\n"
        "Si el usuario menciona un medicamento o suplemento (ej. melatonina, ibuprofeno, "
        "algo que esté tomando para dormir o para el dolor), podés consultar "
        "buscar_medicamento_openfda para traer indicaciones/advertencias/interacciones "
        "oficiales de la FDA como referencia. ES OBLIGATORIO: cada vez que uses o menciones "
        "esa información, aclará explícitamente que es información de referencia de la "
        "etiqueta oficial, NO un consejo médico ni una recomendación de dosis, y que no "
        "sustituye a un profesional de la salud — nunca la presentes como una indicación "
        "tuya. Si el resultado trae es_posible_combinacion en true, aclará que las "
        "advertencias corresponden a un producto combinado, no necesariamente al "
        "ingrediente puro que preguntó el usuario."
    ),
    "nutricion": (
        "Eres el Nutricionista de Personal TrAIner. Si el mensaje trae imágenes, debes "
        "analizarlas visualmente (identificar alimentos y estimar porciones) antes de reportar "
        "nada. Si el usuario describe una comida o adjunta una foto, estima sus macros y "
        "calorías y repórtalo con estimar_comida, incluyendo siempre nombre_alimento y "
        "tipo_comida (desayuno/comida/snack/cena/otro, inferido del mensaje o de la hora "
        "actual). NO uses registrar_comida en esta primera pasada — es la app la que "
        "guarda de verdad la comida cuando el usuario confirma la estimación con un botón, "
        "nunca la des por guardada en tu respuesta de texto. Usa registrar_comida "
        "únicamente si el usuario ya confirmó por escrito en un mensaje posterior que "
        "quiere guardar una estimación que le diste antes en la conversación. Si "
        "pregunta cómo va en el día, usa obtener_resumen_diario. Sé breve y accionable.\n"
        "Antes de estimar, contrastá tu lectura visual contra una base de datos real cuando "
        "el alimento sea identificable, en vez de estimar todo de memoria: si es un producto "
        "ENVASADO con marca/etiqueta legible, usa buscar_producto_openfoodfacts (nombre+marca "
        "o código de barras); si es un INGREDIENTE CRUDO individual (ej. una pechuga de pollo "
        "a la plancha), usa buscar_alimento_usda; si es un PLATO CASERO con varios "
        "ingredientes mezclados, usa estimar_macros_ingredientes con una línea de texto por "
        "ingrediente. Si ninguna de las tres encuentra un match confiable, seguí con tu "
        "propia estimación, dejándola explícita como tal.\n"
        "Estimar porciones desde una foto es aproximado por naturaleza: no presentes las "
        "calorías como una medición exacta, y si la foto no permite juzgar la cantidad "
        "(sin referencia de tamaño, salsas o aceites no visibles), decilo y pedí el dato "
        "en vez de adivinar. Para objetivos de macros, apoyate en los rangos aceptados "
        "según peso corporal y objetivo, no en cifras de moda.\n"
        "Cuando recomiendes calorías o macros, partí SIEMPRE del perfil real del usuario: "
        "su composición corporal estimada, su objetivo y sus analíticas. Explicitá el dato en "
        "el que te apoyás ('con ~18 % de grasa y objetivo de ganar masa…'). Si tiene valores "
        "clínicos fuera de rango que afectan a la alimentación (glucosa o HbA1c altas, "
        "triglicéridos altos, ferritina o vitamina D bajas, función renal reducida), ajustá la "
        "recomendación en consecuencia y decí por qué — pero sin diagnosticar: eso lo valora "
        "un profesional. Con la función renal reducida en particular, no propongas ingestas "
        "proteicas altas sin remitir a un médico."
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
        "constructivo: describí composición y puntos de mejora sin juicios sobre su cuerpo.\n"
        "Para un seguimiento estructurado con historial, el usuario tiene el apartado "
        "**Físico** (Inicio → salud), donde sube fotos por ángulo y se le guarda la evolución. "
        "Recomendáselo si te pide comparar con análisis anteriores."
    ),
}
