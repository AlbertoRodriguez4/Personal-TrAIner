---
name: vision_computacional_postura
description: Reglas para el modo `analisis_fisico` del AI Coach — Gemini razona sobre fotos crudas del cuerpo, ahora apoyado en landmarks de pose de MediaPipe (geometría 2D determinística, no CNN de body-fat ni mesh 3D). Ver sección "No implementado" para los límites reales.
---

# Análisis Físico (modo `analisis_fisico`)

- **Sigue siendo un LLM multimodal mirando la foto — MediaPipe no lo reemplaza,
  lo apuntala con geometría real:** el modo `analisis_fisico`
  (`chat_tools.py::SYSTEM_PROMPTS`) le pide a Gemini que razone visualmente sobre
  la(s) foto(s) adjunta(s) y llame a `guardar_analisis_fisico` con estimaciones —
  `peso_estimado_kg`, `porcentaje_grasa_estimado`, `masa_muscular_estimada_kg`,
  `somatotipo_estimado`, `nivel_fitness_estimado`, etc. — dejando `null` lo que no
  pueda estimar con confianza razonable. Eso se guarda en `BodyAnalysisRecord`
  (`Backend/Nestjs/src/modules/body_analysis/entities/body_analysis_record.entity.ts`),
  sin cambios en ese contrato.
- **`analisis_fisico` es un `IMAGE_MODE`: siempre corre contra Gemini** (nunca
  Groq), con o sin imagen en el mensaje puntual — ver `backend_python_ai/SKILL.md`
  para el enrutamiento y qué pasa si Gemini agota cuota acá (mensaje claro al
  usuario, sin fallback silencioso a otro modelo).

## Preprocesado con MediaPipe Pose (implementado: `pose_analysis.py`)

- **Qué es y qué NO es:** `MediaPipe Tasks` (`mediapipe.tasks.python.vision.PoseLandmarker`,
  paquete `mediapipe`, licencia Apache 2.0) detecta 33 landmarks 2D del
  esqueleto (hombros, caderas, rodillas, etc.) sobre una imagen estática, cada
  uno con score de `visibility`/`presence`, más un set paralelo de landmarks
  "world" (relativos, no una reconstrucción 3D real). **No** es una CNN de
  body-fat, no es un mesh 3D, no mide composición corporal — es geometría de
  esqueleto en 2D, determinística dado el frame. La API vieja
  (`mp.solutions.pose`) está deprecada y removida de versiones recientes de
  `mediapipe`; usar siempre la Tasks API.
- **Corre en CPU, sobre imagen estática (modo `IMAGE`, no `VIDEO`/`LIVE_STREAM`)
  — no hace falta GPU** para una sola foto por turno. Es la única inferencia
  local del servicio Python (ver `backend_python_ai/SKILL.md`); no es un LLM,
  no genera texto, no tiene nada que ver con Gemini/Groq.
- **Versión fijada y probada: `mediapipe==1.0.0`** (`requirements.txt`). Se
  probó en vivo en el Windows de desarrollo de este repo — import +
  `PoseLandmarker.create_from_options` + `detect()` con inferencia real sobre
  una foto de una persona, sin fallos de DLL. Los reportes de crashes de DLL
  en mediapipe/Windows son con otras versiones/builds — no reproducir el
  problema acá no significa que no pueda pasar con otra versión: si se sube
  `mediapipe` alguna vez, repetí esta prueba antes de asumir que sigue andando.
  El modelo (`pose_landmarker_lite.task`, ~5.7MB) se descarga solo la primera
  vez a `Backend/Python/.mediapipe_models/` (gitignored, no se versiona) y
  queda cacheado ahí para las siguientes ejecuciones.
- **Es un paso automático, NO una tool que el modelo decida llamar:** a
  diferencia de las tools de `TOOLS_BY_MODE`, la extracción de landmarks corre
  siempre que el modo sea `analisis_fisico` y el mensaje traiga imágenes —
  durante la construcción de `user_parts` en `_run_chat_gemini`, una vez por
  cada imagen de `images` (si hay más de una foto, cada bloque de métricas se
  etiqueta "foto 1"/"foto 2" para no mezclarlas). Motivo: el propio modo ya
  EXIGE al menos una foto ("Debes exigir al menos una foto adjunta"), así que
  no tiene sentido dejarlo a discreción del modelo; y ahorra una ronda de
  tool-calling completa en un modo que ya corre exclusivamente contra la
  cuota más ajustada (Gemini).
- **Lo que se le pasa a Gemini no son los 33 puntos crudos — son métricas
  derivadas, pocas y con sentido físico:** volcarle al prompt 33 coordenadas
  por foto no ayuda a un LLM tanto como 3-5 métricas ya interpretadas (p. ej.
  diferencia de altura hombro izq/der, diferencia cadera izq/der, alineación
  aproximada del eje hombros-cadera). Estas métricas viajan como contexto
  adicional del mensaje, en el mismo espíritu que `health_context` en
  `sueno_recuperacion` — no como respuesta de una tool, no como campo nuevo de
  `guardar_analisis_fisico`/`BodyAnalysisRecord`.
- **Si un landmark tiene `visibility`/`presence` bajo, esa métrica se omite (no
  se inventa):** mismo principio que ya rige el resto del modo — si la foto no
  permite calcular algo con confianza, se deja fuera en vez de forzar un
  número. Esto es preprocesado determinístico, no reemplaza el criterio de
  Gemini sobre qué tan confiable es su propia estimación.
- **Degradación obligatoria si MediaPipe no detecta a nadie en la foto** (foto
  recortada, ángulo raro, no es una persona): el preprocesado se salta
  silenciosamente y Gemini razona solo sobre la imagen cruda, como hace hoy —
  nunca debe romper el turno ni devolver error al usuario porque la detección
  de pose falló. Mismo principio de "las fuentes de enriquecimiento nunca
  tumban el turno" que las APIs externas por HTTP (`backend_python_ai/SKILL.md`),
  aplicado acá a una dependencia local en vez de una de red.

## Lo que no cambia

- **Las imágenes siguen viajando crudas al backend y a la nube:** el
  preprocesado con MediaPipe pasa ADEMÁS de mandarle la foto completa a
  Gemini, no en lugar de — `ai_coach_page.dart` sigue haciendo
  `base64Encode(bytes)` tal cual, `chat_engine.py` la sigue adjuntando directo
  vía `types.Part.from_bytes`. **No** hay ninguna garantía de privacidad
  "solo metadatos" — sigue siendo un cambio de arquitectura pendiente, no algo
  cumplido por sumar MediaPipe.
- **`posture_evaluation` sigue siendo una entidad distinta sin IA detrás:** el
  módulo `physical_analysis` (`posture_evaluation.entity.ts`,
  `create-posture-evaluation.dto.ts`) sigue siendo un CRUD manual con
  `puntuacion_postura` sin cálculo automático. El preprocesado de MediaPipe de
  `analisis_fisico` **no** alimenta ni reemplaza ese flujo — son módulos
  distintos y este plan no los conecta.

## No implementado (no asumir que existe)

- **Body-fat/composición corporal por CV:** MediaPipe da posiciones de
  articulaciones, no porcentaje de grasa ni masa muscular — esas cifras siguen
  siendo la estimación visual de Gemini (más informada por la geometría, no
  calculada por ella).
- **Mesh 3D, SAM 3D, o cualquier reconstrucción volumétrica:** los landmarks
  "world" de MediaPipe son relativos a la cadera, no una reconstrucción 3D
  real de la escena — no tratarlos como tal.
- **Conteo de repeticiones o tracking en video/tiempo real:** el uso acá es
  `IMAGE` mode sobre una foto estática de `analisis_fisico`, no `VIDEO`/
  `LIVE_STREAM` sobre cámara en vivo — esto último sería una feature de punta a
  punta (probablemente client-side, Flutter/on-device) y no algo que este plan
  cubra.
- **Inferencia on-device (Flutter):** el preprocesado de pose corre en el
  backend Python sobre la imagen ya subida, no en el teléfono — no confundir
  con una futura integración de MediaPipe en el lado cliente (fuera de alcance,
  no se toca código Dart).
