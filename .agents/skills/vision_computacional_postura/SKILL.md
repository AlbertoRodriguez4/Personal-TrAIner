---
name: vision_computacional_postura
description: Reglas para el modo `analisis_fisico` del AI Coach — Gemini razona directamente sobre fotos crudas del cuerpo (sin CV/CNN/mesh, sin procesamiento on-device).
---

# Análisis Físico (modo `analisis_fisico`)

- **No es un pipeline de visión por computadora — es un LLM multimodal mirando la
  foto directamente:** no hay CNNs de pose, no hay SAM 3D, no hay reconstrucción de
  malla en ningún punto del repo. El modo `analisis_fisico`
  (`chat_tools.py::SYSTEM_PROMPTS`) le pide a Gemini que razone visualmente sobre
  la(s) foto(s) adjunta(s) y llame a `guardar_analisis_fisico` con estimaciones —
  `peso_estimado_kg`, `porcentaje_grasa_estimado`, `masa_muscular_estimada_kg`,
  `somatotipo_estimado`, `nivel_fitness_estimado`, etc. — dejando `null` lo que no
  pueda estimar con confianza razonable. Eso se guarda en `BodyAnalysisRecord`
  (`Backend/Nestjs/src/modules/body_analysis/entities/body_analysis_record.entity.ts`).
- **Las imágenes viajan crudas al backend y a la nube — no hay procesamiento
  on-device:** `ai_coach_page.dart` hace `base64Encode(bytes)` de la foto tal cual
  fue tomada/elegida; `chat_engine.py` la decodifica y la adjunta directo al
  mensaje enviado a la API de Gemini (`types.Part.from_bytes`). **No** hay ninguna
  garantía de privacidad "solo metadatos" hoy — si el producto necesita esa
  garantía, es un cambio de arquitectura pendiente, no algo ya cumplido.
- **`posture_evaluation` es una entidad distinta y no tiene IA detrás:** el módulo
  `physical_analysis` (`posture_evaluation.entity.ts`,
  `create-posture-evaluation.dto.ts`) es un CRUD que guarda dos URLs de imagen
  (`imagen_frontal_url`, `imagen_lateral_url`) y un `puntuacion_postura` numérico —
  hoy no hay ningún proceso automático que calcule ese puntaje; hay que setearlo
  manualmente o desde otro flujo que lo provea. No confundir con `body_analysis`
  (el módulo que sí alimenta Gemini).

## No implementado (no asumir que existe)

- Estimación de pose por CNN, recuperación de malla 3D (SAM 3D o similar),
  deducción de distribución de grasa visceral/periférica desde geometría 3D, e
  inferencia on-device — nada de esto existe. Si se pide, es una feature nueva de
  visión por computadora de punta a punta, no una extensión de `analisis_fisico`.
