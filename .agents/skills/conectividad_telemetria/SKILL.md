---
name: conectividad_telemetria
description: BLE real (Flutter↔wearable) + REST plano para telemetría (Flutter→NestJS→Python). Sin MQTT ni WebSockets.
---

# Telemetría y Conectividad

- **BLE (Flutter ↔ wearable) — la única capa inalámbrica real:** implementado con
  `flutter_blue_plus` (`pubspec.yaml`) en `ble_service.dart`. Minimizá la
  frecuencia de interrogación como ya indica AGENTS.md para no drenar la batería
  del wearable — esto sigue siendo válido.
- **Del teléfono al backend, todo es REST síncrono, no pub/sub:** el flujo real de
  telemetría de una serie de ejercicio es:
  1. Flutter → `POST /telemetry/hr-set` (`telemetry.controller.ts`)
  2. NestJS reenvía con `fetch()` síncrono → Python `POST /ai/analyze-set`
     (`telemetry.service.ts::analyzeHrSet`)
  3. Python ejecuta `analyze_failure` (heurística determinística sobre la serie de
     BPM) y devuelve JSON
  4. La respuesta sube por la misma cadena hasta Flutter.

  No hay paso intermedio async, cola de mensajes ni conexión persistente — es
  petición/respuesta en cada salto.
- **El chat de IA también es petición/respuesta, no un canal en vivo:** cada
  mensaje a `/api/ia/chat` es un POST independiente; no hay sesión de socket
  abierta entre turnos.

## No implementado (no asumir que existe)

- No hay MQTT (ni broker ni cliente) en ningún punto del repo — no uses esa
  suposición para ingestión de telemetría.
- No hay WebSocket gateway para la IA conversacional ni para ningún otro flujo —
  no hay canal full-duplex de baja latencia hoy.
