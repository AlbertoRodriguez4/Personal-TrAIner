from pydantic import BaseModel, Field
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
