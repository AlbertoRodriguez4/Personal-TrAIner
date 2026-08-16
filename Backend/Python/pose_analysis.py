"""Preprocesado de pose para `analisis_fisico` — MediaPipe Tasks API
(PoseLandmarker), CPU, sobre imagen estática. Corre ANTES del prompt a
Gemini, no es una tool (ver vision_computacional_postura/SKILL.md): el modo
ya exige foto siempre, así que no tiene sentido dejarlo a discreción del
modelo, y ahorra una ronda de tool-calling en el modo más sensible a cuota.

Extrae landmarks y devuelve solo métricas derivadas con sentido físico
(simetría hombros/cadera, alineación del eje) — nunca los 33 puntos crudos,
y nunca un número si el landmark no es confiable (visibility baja). Si
MediaPipe no detecta a nadie en la foto, devuelve None en silencio: Gemini
razona solo sobre la imagen cruda, como si esto no existiera.

Verificado en vivo (import + inferencia real con modelo descargado, sobre una
foto real de una persona) contra mediapipe==1.0.0 en Windows — ver
requirements.txt y vision_computacional_postura/SKILL.md sobre el riesgo de
DLL en otras versiones."""
import urllib.request
from pathlib import Path

import cv2
import numpy as np

MODEL_DIR = Path(__file__).parent / ".mediapipe_models"
MODEL_PATH = MODEL_DIR / "pose_landmarker_lite.task"
MODEL_URL = (
    "https://storage.googleapis.com/mediapipe-models/pose_landmarker/"
    "pose_landmarker_lite/float16/latest/pose_landmarker_lite.task"
)

VISIBILITY_MINIMA = 0.5  # por debajo de esto, la métrica que dependa de ese landmark no se reporta

# Índices del esqueleto estándar de 33 puntos de MediaPipe Pose (BlazePose).
HOMBRO_IZQ, HOMBRO_DER = 11, 12
CADERA_IZQ, CADERA_DER = 23, 24

_landmarker = None  # singleton perezoso — crear el modelo es costoso, se reusa entre requests


def _asegurar_modelo() -> str:
    if not MODEL_PATH.exists():
        MODEL_DIR.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(MODEL_URL, MODEL_PATH)
    return str(MODEL_PATH)


def _obtener_landmarker():
    global _landmarker
    if _landmarker is None:
        from mediapipe.tasks.python import BaseOptions
        from mediapipe.tasks.python.vision import PoseLandmarker, PoseLandmarkerOptions, RunningMode

        options = PoseLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=_asegurar_modelo()),
            running_mode=RunningMode.IMAGE,
            num_poses=1,
        )
        _landmarker = PoseLandmarker.create_from_options(options)
    return _landmarker


def _visible(landmark) -> bool:
    return (landmark.visibility or 0) >= VISIBILITY_MINIMA


def extraer_metricas_pose(imagen_bytes: bytes) -> dict | None:
    """None si no se detecta a nadie en la foto, si los landmarks clave no
    son confiables, o si algo falla — nunca levanta, es un preprocesado de
    enriquecimiento, no un paso obligatorio del turno."""
    try:
        import mediapipe as mp

        arr = np.frombuffer(imagen_bytes, np.uint8)
        img_bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if img_bgr is None:
            return None
        img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=img_rgb)

        resultado = _obtener_landmarker().detect(mp_image)
    except Exception:
        return None

    if not resultado.pose_landmarks:
        return None

    landmarks = resultado.pose_landmarks[0]
    metricas = {}

    if _visible(landmarks[HOMBRO_IZQ]) and _visible(landmarks[HOMBRO_DER]):
        metricas["diferencia_altura_hombros"] = round(
            abs(landmarks[HOMBRO_IZQ].y - landmarks[HOMBRO_DER].y), 3
        )

    if _visible(landmarks[CADERA_IZQ]) and _visible(landmarks[CADERA_DER]):
        metricas["diferencia_altura_cadera"] = round(
            abs(landmarks[CADERA_IZQ].y - landmarks[CADERA_DER].y), 3
        )

    if all(_visible(landmarks[i]) for i in (HOMBRO_IZQ, HOMBRO_DER, CADERA_IZQ, CADERA_DER)):
        centro_hombros_x = (landmarks[HOMBRO_IZQ].x + landmarks[HOMBRO_DER].x) / 2
        centro_cadera_x = (landmarks[CADERA_IZQ].x + landmarks[CADERA_DER].x) / 2
        metricas["desalineacion_eje_hombros_cadera"] = round(abs(centro_hombros_x - centro_cadera_x), 3)

    if not metricas:
        return None

    metricas["nota"] = (
        "Coordenadas normalizadas (0-1) relativas al encuadre de la foto, no medidas "
        "físicas absolutas. Diferencias pequeñas (<0.02) pueden ser ruido del ángulo de "
        "cámara/pose, no asimetría corporal real — no las sobre-interpretes."
    )
    return metricas
