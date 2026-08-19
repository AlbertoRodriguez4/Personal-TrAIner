from pydantic import BaseModel, Field, conlist
from typing import List, Optional
from enum import Enum
from datetime import datetime


# ============================================================
# ENUMS
# ============================================================

class HRVStatus(str, Enum):
    LOW = "low"
    NORMAL = "normal"
    HIGH = "high"


class AdjustmentType(str, Enum):
    REDUCE_VOLUME = "reduce_volume"
    INCREASE_INTENSITY = "increase_intensity"
    SWAP_TO_ACTIVE_RECOVERY = "swap_to_active_recovery"
    TIME_CRUNCH = "time_crunch"


class TargetWidget(str, Enum):
    WORKOUT_DASHBOARD = "workout_dashboard"
    READINESS_RING = "readiness_ring"
    NUTRITION_CHART = "nutrition_chart"


# ============================================================
# MÓDULO 1: Wearables y Biometría — Inputs / Outputs
# ============================================================

class DailyReadinessRequest(BaseModel):
    user_id: str = Field(..., description="Identificador único del usuario")
    date: str = Field(..., description="Fecha en formato ISO 8601 (YYYY-MM-DD)")

    class Config:
        json_schema_extra = {
            "example": {
                "user_id": "usr_abc123",
                "date": "2026-06-24"
            }
        }


class DailyReadinessResponse(BaseModel):
    readiness_score: int = Field(..., ge=0, le=100, description="Puntuación de recuperación 0-100")
    sleep_hours: float = Field(..., ge=0, description="Horas de sueño registradas")
    hrv_status: HRVStatus = Field(..., description="Estado de variabilidad de frecuencia cardíaca")


class ActivityStatsRequest(BaseModel):
    user_id: str = Field(..., description="Identificador único del usuario")
    date: str = Field(..., description="Fecha en formato ISO 8601 (YYYY-MM-DD)")

    class Config:
        json_schema_extra = {
            "example": {
                "user_id": "usr_abc123",
                "date": "2026-06-24"
            }
        }


class ActivityStatsResponse(BaseModel):
    calories_burned: float = Field(..., ge=0, description="Calorías totales quemadas en el día")
    steps: int = Field(..., ge=0, description="Pasos registrados en el día")
    workouts_logged: int = Field(..., ge=0, description="Número de entrenamientos completados")


# ============================================================
# MÓDULO 2: Motor de Entrenamiento — Inputs / Outputs
# ============================================================

class TodaysWorkoutRequest(BaseModel):
    user_id: str = Field(..., description="Identificador único del usuario")
    date: str = Field(..., description="Fecha en formato ISO 8601 (YYYY-MM-DD)")


class ExerciseSet(BaseModel):
    set_number: int = Field(..., ge=1, description="Número de serie")
    target_reps: int = Field(..., ge=1, description="Repeticiones objetivo")
    target_weight: Optional[float] = Field(None, ge=0, description="Peso objetivo en kg")
    rir: Optional[int] = Field(None, ge=0, le=5, description="Repeticiones en Reserva objetivo")
    rest_seconds: int = Field(..., ge=0, description="Tiempo de descanso en segundos")


class Exercise(BaseModel):
    exercise_id: str = Field(..., description="Identificador del ejercicio")
    name: str = Field(..., description="Nombre del ejercicio")
    sets: List[ExerciseSet] = Field(default_factory=list, description="Series planificadas")


class TodaysWorkoutResponse(BaseModel):
    workout_id: str = Field(..., description="Identificador de la rutina")
    exercises: List[Exercise] = Field(default_factory=list, description="Lista de ejercicios del día")


class AdjustWorkoutRequest(BaseModel):
    user_id: str = Field(..., description="Identificador único del usuario")
    workout_id: str = Field(..., description="Identificador de la rutina a modificar")
    adjustment_type: AdjustmentType = Field(..., description="Tipo de ajuste a aplicar")
    reason: str = Field(..., min_length=5, description="Explicación breve del motivo del ajuste")

    class Config:
        json_schema_extra = {
            "example": {
                "user_id": "usr_abc123",
                "workout_id": "wkt_xyz789",
                "adjustment_type": "reduce_volume",
                "reason": "El usuario reporta fatiga acumulada y HRV bajo"
            }
        }


class AdjustWorkoutResponse(BaseModel):
    workout_id: str = Field(..., description="Identificador de la rutina modificada")
    adjustment_applied: AdjustmentType = Field(..., description="Tipo de ajuste aplicado")
    changes_summary: str = Field(..., description="Resumen de los cambios realizados")
    updated_exercises: List[Exercise] = Field(default_factory=list, description="Lista actualizada de ejercicios")


class ExercisePerformed(BaseModel):
    exercise_id: str = Field(..., description="Identificador del ejercicio realizado")
    sets_completed: List[dict] = Field(
        ...,
        description="Lista de series completadas. Cada dict: {set_number, reps, weight_kg, rir_felt}"
    )


class LogWorkoutExecutionRequest(BaseModel):
    user_id: str = Field(..., description="Identificador único del usuario")
    workout_id: str = Field(..., description="Identificador de la rutina ejecutada")
    exercises_performed: List[ExercisePerformed] = Field(
        ...,
        min_length=1,
        description="Lista de ejercicios que el usuario realmente ejecutó"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "user_id": "usr_abc123",
                "workout_id": "wkt_xyz789",
                "exercises_performed": [
                    {
                        "exercise_id": "ex_bench_press",
                        "sets_completed": [
                            {"set_number": 1, "reps": 10, "weight_kg": 60.0, "rir_felt": 2},
                            {"set_number": 2, "reps": 8, "weight_kg": 65.0, "rir_felt": 1},
                            {"set_number": 3, "reps": 6, "weight_kg": 70.0, "rir_felt": 0}
                        ]
                    }
                ]
            }
        }


class LogWorkoutExecutionResponse(BaseModel):
    workout_id: str = Field(..., description="Identificador de la rutina registrada")
    total_volume_kg: float = Field(..., description="Volumen total levantado en kg (series x reps x peso)")
    exercises_logged: int = Field(..., description="Número de ejercicios registrados")
    progressive_overload_notes: Optional[str] = Field(None, description="Notas sobre progresión respecto a la sesión anterior")


# ============================================================
# MÓDULO 3: Interfaz y Notificaciones — Inputs / Outputs
# ============================================================

class TriggerUIRefreshRequest(BaseModel):
    user_id: str = Field(..., description="Identificador único del usuario")
    target_widget: TargetWidget = Field(..., description="Widget del frontend que debe refrescarse")

    class Config:
        json_schema_extra = {
            "example": {
                "user_id": "usr_abc123",
                "target_widget": "workout_dashboard"
            }
        }


class TriggerUIRefreshResponse(BaseModel):
    success: bool = Field(..., description="Indica si la señal fue enviada correctamente")
    widget_refreshed: TargetWidget = Field(..., description="Widget que fue refrescado")
    timestamp: str = Field(..., description="Timestamp ISO 8601 del evento")


class ScheduleNotificationRequest(BaseModel):
    user_id: str = Field(..., description="Identificador único del usuario")
    message_title: str = Field(..., min_length=1, description="Título de la notificación push")
    message_body: str = Field(..., min_length=1, description="Cuerpo del mensaje de la notificación")
    send_at: str = Field(..., description="Fecha y hora de envío en formato ISO 8601")

    class Config:
        json_schema_extra = {
            "example": {
                "user_id": "usr_abc123",
                "message_title": "Hora de entrenar!",
                "message_body": "Tu rutina de pecho te espera. 45 min estimados.",
                "send_at": "2026-06-24T18:00:00Z"
            }
        }


class ScheduleNotificationResponse(BaseModel):
    notification_id: str = Field(..., description="Identificador de la notificación programada")
    scheduled_for: str = Field(..., description="Fecha/hora ISO 8601 programada para el envío")
    status: str = Field(..., description="Estado de la programación: 'scheduled', 'failed'")


# ============================================================
# MÓDULO 4: Telemetría de Serie (HR de smartwatch)
# ============================================================

class SetTelemetryInput(BaseModel):
    uid: str = Field(..., description="ID usuario")
    eid: str = Field(..., description="ID ejercicio")
    dur: int = Field(..., ge=1, description="Duración de la serie en segundos")
    hr: conlist(int, min_length=1) = Field(..., description="Lista de pulsaciones BPM registradas")

    class Config:
        json_schema_extra = {
            "example": {
                "uid": "usr_abc123",
                "eid": "ex_bench_press",
                "dur": 40,
                "hr": [95, 102, 110, 118, 126, 134, 141, 145, 147, 148, 148, 148, 150, 150, 151, 169, 176, 178, 181, 184]
            }
        }

class ChatImage(BaseModel):
    data: str
    mime_type: str = Field(..., alias="mimeType")

    class Config:
        populate_by_name = True


class ChatTurn(BaseModel):
    role: str = Field(..., description="'user' o 'model'")
    text: str

class ChatRequest(BaseModel):
    user_id: str = Field(..., description="UUID del usuario")
    mode: str = Field(..., description="creador_rutina | revisor_rutina | sueno_recuperacion | nutricion | entrenamiento | analisis_fisico")
    message: str
    history: List[ChatTurn] = Field(default_factory=list)
    health_context: Optional[dict] = Field(None, description="Datos crudos de Health Connect, solo para modo sueno_recuperacion")
    images: List[ChatImage] = Field(default_factory=list)

class ChatAction(BaseModel):
    tool: str
    result: dict

class ChatResponse(BaseModel):
    reply: str
    actions_taken: List[ChatAction]


# ============================================================
# MÓDULO 5: Análisis clínico y de físico (una sola pasada, no chat)
# ============================================================

class ClinicalReportRequest(BaseModel):
    user_id: str = Field(..., description="UUID del usuario")
    data: str = Field(..., description="PDF o imagen del informe en base64, sin el prefijo 'data:'")
    mime_type: str = Field(..., description="application/pdf | image/jpeg | image/png | image/webp")
    file_name: Optional[str] = Field(None, description="Nombre original del archivo, solo para mostrarlo en el historial")


class ClinicalManualValue(BaseModel):
    codigo: str = Field(..., description="Nombre o código del biomarcador (se normaliza en el servidor)")
    valor: float
    unidad: Optional[str] = None
    rango_min: Optional[float] = None
    rango_max: Optional[float] = None


class ClinicalManualRequest(BaseModel):
    user_id: str = Field(..., description="UUID del usuario")
    valores: conlist(ClinicalManualValue, min_length=1)
    fecha: Optional[str] = Field(None, description="Fecha de la analítica en AAAA-MM-DD; hoy si falta")


class BodyCompositionRequest(BaseModel):
    """Una medición de composición corporal tecleada a mano.

    Todos los valores son opcionales por diseño: una báscula de casa da peso y
    porcentaje de grasa y nada más, y obligar a rellenar el resto solo
    conseguiría que el usuario se inventase los huecos. El servidor comprueba
    que llegue al menos uno y deriva los que se puedan deducir."""
    user_id: str = Field(..., description="UUID del usuario")
    fecha: Optional[str] = Field(None, description="Fecha de la medición en AAAA-MM-DD; hoy si falta")
    metodo: Optional[str] = Field("dexa", description="dexa | bioimpedancia | plicometria | bascula | otro")
    peso_kg: Optional[float] = None
    porcentaje_grasa: Optional[float] = None
    masa_muscular_kg: Optional[float] = None
    musculo_esqueletico_pct: Optional[float] = None
    masa_osea_kg: Optional[float] = None
    densidad_osea: Optional[float] = Field(None, description="Densidad mineral ósea en g/cm²")
    proteina_kg: Optional[float] = None
    agua_corporal_kg: Optional[float] = None
    agua_corporal_pct: Optional[float] = None
    grasa_subcutanea_pct: Optional[float] = None
    grasa_visceral: Optional[float] = None
    tmb_kcal: Optional[float] = None
    edad_corporal: Optional[float] = None
    peso_ideal_kg: Optional[float] = None
    notas: Optional[str] = None


class PhysiquePhotoInput(BaseModel):
    data: str = Field(..., description="Imagen en base64, ya reescalada por el cliente")
    mime_type: str = Field(..., description="image/jpeg | image/png | image/webp")
    angulo: str = Field("otro", description="frontal | lateral | espalda | otro")


class PhysiqueAnalysisRequest(BaseModel):
    user_id: str = Field(..., description="UUID del usuario")
    photos: conlist(PhysiquePhotoInput, min_length=1) = Field(..., description="Entre 1 y 5 fotos del físico")
    notas: Optional[str] = Field(None, description="Contexto libre que escriba el usuario")


class FoodEstimateRequest(BaseModel):
    """Registro manual de comida (nutricion, sin foto): un nombre + una cantidad.
    La cantidad es SIEMPRE una de las dos formas, nunca ambas — el cliente elige
    entre pestaña 'Gramos' o 'Referencias' y solo manda el campo de esa pestaña."""
    user_id: str = Field(..., description="UUID del usuario")
    nombre_alimento: str = Field(..., min_length=1, description="Ej. 'Pechuga de pollo'")
    cantidad_g: Optional[float] = Field(None, gt=0, description="Modo Gramos")
    referencia_unidad: Optional[str] = Field(
        None,
        description="Modo Referencias: 'palma' | 'puno' | 'punado' | 'pulgar' | 'vaso' | "
        "'cuarto_plato' | 'media_plato' | 'plato_completo'",
    )
    referencia_cantidad: Optional[float] = Field(1.0, gt=0, description="Ej. 2 para '2 puños'")


class FoodSuggestionsRequest(BaseModel):
    """Autocompletado del catálogo local mientras el usuario escribe — ver
    food_lookup.sugerir. No toca USDA/Open Food Facts, solo el catálogo
    propio, así que responde lo bastante rápido para llamarse en cada tecla."""
    query: str = Field(..., min_length=1)

