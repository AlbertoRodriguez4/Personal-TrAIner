from datetime import datetime, timezone
from typing import Dict, Any
import json
import requests

from schemas import (
    SetTelemetryInput,
    DailyReadinessRequest,
    DailyReadinessResponse,
    ActivityStatsRequest,
    ActivityStatsResponse,
    TodaysWorkoutRequest,
    TodaysWorkoutResponse,
    AdjustWorkoutRequest,
    AdjustWorkoutResponse,
    LogWorkoutExecutionRequest,
    LogWorkoutExecutionResponse,
    TriggerUIRefreshRequest,
    TriggerUIRefreshResponse,
    ScheduleNotificationRequest,
    ScheduleNotificationResponse,
)


# ============================================================
# MÓDULO 1: Wearables y Biometría
# ============================================================

async def get_daily_readiness(request: DailyReadinessRequest) -> DailyReadinessResponse:
    """
    Obtiene la puntuación de recuperación (readiness) del usuario basada en datos del smartwatch.

    Esta skill consulta los biomarcadores nocturnos y matutinos del usuario — incluyendo
    horas de sueño, variabilidad de la frecuencia cardíaca (HRV) y frecuencia cardíaca
    en reposo (RHR) — para calcular un score consolidado de 0 a 100 que indica qué tan
    preparado está el cuerpo para entrenar.

    El agente LLM debe invocar esta skill:
      - Al inicio de cada día, antes de recomendar cualquier entrenamiento.
      - Cuando el usuario pregunte si debería entrenar fuerte o tomarlo con calma.
      - Antes de ejecutar `adjust_workout_prescription` para fundamentar la decisión.

    Args:
        request (DailyReadinessRequest):
            - user_id (str): Identificador único del usuario.
            - date (str): Fecha de consulta en formato ISO 8601 (YYYY-MM-DD).

    Returns:
        DailyReadinessResponse:
            - readiness_score (int): Puntuación 0-100. <40 = no entrenar, 40-70 = moderado, >70 = pleno.
            - sleep_hours (float): Horas de sueño efectivas registradas por el wearable.
            - hrv_status (HRVStatus): Estado del HRV — "low" (fatiga), "normal", "high" (supercompensación).

    Raises:
        HTTPException: Si el wearable no tiene datos para la fecha solicitada.
        HTTPException: Si el user_id no existe en el sistema.

    Example:
        >>> req = DailyReadinessRequest(user_id="usr_abc123", date="2026-06-24")
        >>> resp = await get_daily_readiness(req)
        >>> resp.readiness_score
        72
    """
    raise NotImplementedError("TODO: Conectar con el servicio de wearables (Garmin/Apple Health/Oura API)")


async def get_activity_stats(request: ActivityStatsRequest) -> ActivityStatsResponse:
    """
    Recupera las estadísticas de actividad física del usuario para un día específico.

    Consulta la base de datos de telemetría para obtener un resumen de la actividad
    diaria: calorías quemadas (activas + BMR), pasos contabilizados por el acelerómetro
    del smartwatch, y número de entrenamientos formalmente registrados.

    El agente LLM debe invocar esta skill:
      - Para contextualizar el gasto energético del día antes de dar recomendaciones nutricionales.
      - Cuando el usuario pregunte "¿cuánto me moví hoy?".
      - Para verificar si ya completó su entrenamiento diario antes de sugerir otro.

    Args:
        request (ActivityStatsRequest):
            - user_id (str): Identificador único del usuario.
            - date (str): Fecha de consulta en formato ISO 8601 (YYYY-MM-DD).

    Returns:
        ActivityStatsResponse:
            - calories_burned (float): Calorías totales quemadas en el día.
            - steps (int): Pasos registrados.
            - workouts_logged (int): Cantidad de entrenamientos completados ese día.

    Raises:
        HTTPException: Si no hay datos de actividad para la fecha solicitada.
    """
    raise NotImplementedError("TODO: Conectar con el servicio de actividad (MongoDB collection: daily_activity)")


# ============================================================
# MÓDULO 2: Motor de Entrenamiento (Core)
# ============================================================

async def get_todays_workout(request: TodaysWorkoutRequest) -> TodaysWorkoutResponse:
    """
    Obtiene la rutina de entrenamiento programada para el día indicado.

    Recupera de la base de datos la planificación del entrenamiento que corresponde
    a la fecha solicitada, incluyendo la lista completa de ejercicios con sus series,
    repeticiones objetivo, carga prescrita, RIR (Repeticiones en Reserva) y tiempos
    de descanso entre series.

    El agente LLM debe invocar esta skill:
      - Cuando el usuario pregunte "¿qué me toca entrenar hoy?".
      - Antes de mostrar la rutina en el dashboard de Flutter.
      - Como paso previo a `adjust_workout_prescription` para conocer el plan original.

    Args:
        request (TodaysWorkoutRequest):
            - user_id (str): Identificador único del usuario.
            - date (str): Fecha en formato ISO 8601 (YYYY-MM-DD).

    Returns:
        TodaysWorkoutResponse:
            - workout_id (str): Identificador de la rutina.
            - exercises (List[Exercise]): Lista de ejercicios, cada uno con:
                - exercise_id, name
                - sets: lista de ExerciseSet con target_reps, target_weight, rir, rest_seconds.

    Raises:
        HTTPException: Si no hay rutina programada para esa fecha.
    """
    raise NotImplementedError("TODO: Conectar con PostgreSQL (tabla: workout_plans)")


async def adjust_workout_prescription(request: AdjustWorkoutRequest) -> AdjustWorkoutResponse:
    """
    Modifica la rutina de entrenamiento programada basándose en el estado del usuario.

    Aplica un ajuste algorítmico a la rutina existente según el tipo de modificación
    solicitado. Los ajustes disponibles son:
      - "reduce_volume": Reduce series y/o repeticiones (ideal para fatiga acumulada).
      - "increase_intensity": Sube cargas y baja repeticiones (para días de alta readiness).
      - "swap_to_active_recovery": Reemplaza la rutina por movilidad/cardio suave.
      - "time_crunch": Condensa la rutina eliminando accesorios y priorizando compuestos.

    El agente LLM debe invocar esta skill:
      - Cuando `get_daily_readiness` arroje un score < 40 y el usuario quiera entrenar igual.
      - Cuando el usuario diga "tengo poco tiempo hoy" o "solo tengo 30 minutos".
      - Cuando haya evidencia de sobreentrenamiento en las métricas biométricas.

    Args:
        request (AdjustWorkoutRequest):
            - user_id (str): Identificador único del usuario.
            - workout_id (str): Identificador de la rutina a modificar.
            - adjustment_type (AdjustmentType): Tipo de ajuste a aplicar.
            - reason (str): Explicación breve del motivo (mín. 5 caracteres).

    Returns:
        AdjustWorkoutResponse:
            - workout_id (str): ID de la rutina modificada.
            - adjustment_applied (AdjustmentType): Tipo de ajuste que se aplicó.
            - changes_summary (str): Resumen legible de los cambios realizados.
            - updated_exercises (List[Exercise]): Lista actualizada de ejercicios.

    Raises:
        HTTPException: Si el workout_id no corresponde al usuario.
        HTTPException: Si el adjustment_type no es válido.
    """
    raise NotImplementedError("TODO: Implementar lógica de ajuste por tipo en el motor de entrenamiento")


async def log_workout_execution(request: LogWorkoutExecutionRequest) -> LogWorkoutExecutionResponse:
    """
    Registra lo que el usuario realmente ejecutó en el gimnasio para calcular sobrecarga progresiva.

    Persiste en la base de datos el rendimiento real del usuario: ejercicios completados,
    series efectivas, peso utilizado y RIR percibido. Estos datos alimentan el algoritmo
    de progresión que calculará las cargas del próximo entrenamiento similar.

    El agente LLM debe invocar esta skill:
      - Inmediatamente después de que el usuario termine su entrenamiento.
      - Cuando el usuario reporte manualmente lo que levantó ("hoy hice 60kg x 10 en press banca").
      - Para mantener el historial de progresión actualizado.

    Args:
        request (LogWorkoutExecutionRequest):
            - user_id (str): Identificador único del usuario.
            - workout_id (str): Identificador de la rutina ejecutada.
            - exercises_performed (List[ExercisePerformed]): Lista de ejercicios realizados, cada uno con:
                - exercise_id (str): ID del ejercicio.
                - sets_completed (List[dict]): Series con {set_number, reps, weight_kg, rir_felt}.

    Returns:
        LogWorkoutExecutionResponse:
            - workout_id (str): ID de la rutina registrada.
            - total_volume_kg (float): Volumen total = SUM(series * reps * peso).
            - exercises_logged (int): Número de ejercicios registrados.
            - progressive_overload_notes (str|None): Notas sobre progresión vs sesión anterior.

    Raises:
        HTTPException: Si el workout_id no corresponde al usuario.
        HTTPException: Si exercises_performed está vacía.
    """
    raise NotImplementedError("TODO: Implementar cálculo de volumen y comparación con sesión anterior (PostgreSQL)")


# ============================================================
# MÓDULO 3: Interfaz y Notificaciones (Conexión con Flutter)
# ============================================================

async def trigger_ui_refresh(request: TriggerUIRefreshRequest) -> TriggerUIRefreshResponse:
    """
    Envía una señal al frontend Flutter para que actualice un widget específico.

    Utiliza WebSockets o MQTT para notificar al cliente Flutter que debe refrescar
    un componente visual concreto. Esto permite que el agente de IA controle
    dinámicamente lo que el usuario ve en pantalla sin necesidad de que el usuario
    haga pull-to-refresh o navegue a otra pantalla.

    El agente LLM debe invocar esta skill:
      - Después de ajustar una rutina con `adjust_workout_prescription`, para refrescar
        el "workout_dashboard" y que el usuario vea los cambios al instante.
      - Cuando llega un nuevo score de readiness, para actualizar el "readiness_ring".
      - Tras registrar datos nutricionales, para refrescar el "nutrition_chart".

    Args:
        request (TriggerUIRefreshRequest):
            - user_id (str): Identificador único del usuario (para enrutar al WebSocket correcto).
            - target_widget (TargetWidget): Widget a refrescar. Valores permitidos:
                "workout_dashboard", "readiness_ring", "nutrition_chart".

    Returns:
        TriggerUIRefreshResponse:
            - success (bool): True si la señal se envió correctamente.
            - widget_refreshed (TargetWidget): Widget que fue refrescado.
            - timestamp (str): Timestamp ISO 8601 del evento de refresco.

    Raises:
        HTTPException: Si el usuario no tiene una conexión WebSocket activa.
    """
    raise NotImplementedError("TODO: Implementar envío de señal vía WebSocket/MQTT al cliente Flutter")


async def schedule_smart_notification(request: ScheduleNotificationRequest) -> ScheduleNotificationResponse:
    """
    Programa una notificación push (FCM/APNs) para el usuario en un momento específico.

    Registra una notificación en la cola de mensajería para ser enviada en la fecha/hora
    indicada. Soporta tanto Firebase Cloud Messaging (Android) como APNs (iOS).
    El agente puede programar recordatorios contextuales basados en los hábitos del usuario.

    El agente LLM debe invocar esta skill:
      - Para recordatorios de hidratación ("Bebe agua, llevas 3h sin hidratarte").
      - Para motivación pre-entreno ("Tu rutina de espalda te espera en 30 min").
      - Para alertas de recuperación ("Tu HRV bajó un 20%, considera descanso activo mañana").
      - Para recordatorios de nutrición post-entreno ("Ventana anabólica: toma tus proteínas").

    Args:
        request (ScheduleNotificationRequest):
            - user_id (str): Identificador único del usuario.
            - message_title (str): Título de la notificación (mín. 1 carácter).
            - message_body (str): Cuerpo del mensaje (mín. 1 carácter).
            - send_at (str): Fecha y hora de envío en formato ISO 8601 completo
              (ej: "2026-06-24T18:00:00Z").

    Returns:
        ScheduleNotificationResponse:
            - notification_id (str): ID único de la notificación programada.
            - scheduled_for (str): Fecha/hora ISO 8601 para la que fue programada.
            - status (str): Estado — "scheduled" si fue aceptada, "failed" si hubo error.

    Raises:
        HTTPException: Si send_at es una fecha en el pasado.
        HTTPException: Si el usuario no tiene tokens FCM/APNs registrados.
    """
    raise NotImplementedError("TODO: Implementar cola de notificaciones con FCM/APNs (Redis + Celery o similar)")


# ============================================================
# MÓDULO 4: Telemetría de Serie — Detección de fallo muscular
# ============================================================

def analyze_failure(data: SetTelemetryInput) -> dict:
    """
    Algoritmo determinístico de detección de fatiga muscular basado en la
    derivada de la curva de pulsaciones del smartwatch.

    Métricas fisiológicas:
      - Pendiente de ataque (primeros 10s): subida brusca = carga pesada.
      - Plateau cardiovascular: aplanamiento del pulso en la zona alta
        durante el último 20% de la serie = aproximación al fallo.
      - Estimación de RIR y clase de intensidad/zona.
    """
    hr = [int(x) for x in data.hr]
    n = len(hr)
    if n < 3:
        return {
            "rir_estimado": 4,
            "pendiente_ataque": 0.0,
            "plateau_index": 0.0,
            "zona": "Desconocida",
            "feedback": "Datos insuficientes para análisis.",
        }

    import statistics

    delta = data.dur / max(n - 1, 1)

    # 1) Pendiente de ataque: BPM ganados por segundo en los primeros 10s
    window = max(2, int(round(10.0 / delta)))
    seg10 = hr[: min(window, n)]
    pendiente_ataque = 0.0
    if len(seg10) >= 2:
        pendiente_ataque = (seg10[-1] - seg10[0]) / ((len(seg10) - 1) * delta)

    # 2) Plateau cardiovascular: std-dev del último 20% en la zona alta
    tail_k = max(2, int(round(n * 0.20)))
    tail = hr[n - tail_k:]
    pico = max(hr)
    media_tail = statistics.fmean(tail)
    std_tail = statistics.pstdev(tail) if len(tail) > 1 else 0.0
    # Índice normalizado: alto = pla¬teo marcado (cerca del pico y plano)
    denom = (pico if pico > 0 else 1)
    plateau_index = (media_tail / denom) * (1.0 - min(std_tail / 6.0, 1.0))

    # 3) Derivada media en el último tercio (aplanamiento = fallo)
    tail_der = []
    for i in range(max(n - tail_k, 1), n - 1):
        tail_der.append((hr[i + 1] - hr[i]) / delta)
    der_final = statistics.fmean(tail_der) if tail_der else 0.0

    # 4) Estimación de RIR por heurística combinada
    if plateau_index >= 0.95 and der_final <= 0.4:
        rir = 0
    elif plateau_index >= 0.90 and der_final <= 0.9:
        rir = 1
    elif plateau_index >= 0.85:
        rir = 2
    elif pendiente_ataque >= 1.5:
        rir = 3
    else:
        rir = 4

    # 5) Clasificación de zona/intensidad (FCM por defecto 190)
    fcm = 190
    pct_pico = pico / fcm
    if pct_pico >= 0.95:
        zona = "Z5 M\u00e1xima"
    elif pct_pico >= 0.88:
        zona = "Z4 Umbral"
    elif pct_pico >= 0.80:
        zona = "Z3 Tempo"
    elif pct_pico >= 0.70:
        zona = "Z2 Aer\u00f3bica"
    else:
        zona = "Z1 Recuperaci\u00f3n"

    # 6) Feedback textual conciso
    if rir == 0:
        feedback = "Fallo muscular alcanzado: plateau cardiovascular claro en el \u00faltimo tramo."
    elif rir <= 2:
        feedback = f"Intensidad alta (RIR {rir}); cercano al fallo, carga adecuada para hipertrofia."
    elif pendiente_ataque >= 2.0:
        feedback = f"Pendiente de ataque elevada ({pendiente_ataque:.1f} bpm/s): serie pesada, RIR {rir}."
    else:
        feedback = f"Serie subm\u00e1xima (RIR {rir}); podr\u00edas subir carga o repeticiones."

    return {
        "rir_estimado": int(rir),
        "pendiente_ataque": round(pendiente_ataque, 3),
        "plateau_index": round(plateau_index, 3),
        "pico_bpm": int(pico),
        "media_bpm": int(statistics.fmean(hr)),
        "zona": zona,
        "feedback": feedback,
    }
