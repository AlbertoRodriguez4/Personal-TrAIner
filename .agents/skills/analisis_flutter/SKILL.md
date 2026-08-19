---
name: analisis_flutter
description: Reglas y mapa de archivos reales para cuando se esté escribiendo o analizando código de Flutter en el Frontend.
---

# Desarrollo Frontend (Flutter / Dart)

- **Dónde mirar primero:** `lib/src/services/` (`health_service.dart` — Health
  Connect, `smartwatch_service.dart` — sync Mi Fitness, `ble_service.dart` —
  Bluetooth crudo, `api_service.dart` — cliente HTTP hacia NestJS) y
  `lib/src/features/` (`ai_coach/`, `auth/`, `routine/`, `home/`, `health/`,
  `onboarding/`). No cargues `lib/src/features/**` completo salvo que la tarea sea
  de un feature concreto — ver AGENTS.md para el mapa completo del repo.
- **Entrada visual real:** una foto suelta capturada o elegida con `image_picker`
  (cámara o galería), codificada en base64 en el cliente
  (`ai_coach_page.dart::_pickImage`, `base64Encode(bytes)`) y enviada como parte de
  un mensaje de chat. No hay cámara en vivo, streaming de video ni procesamiento de
  imagen en el dispositivo — la imagen cruda viaja tal cual al backend.
- **Lint real:** `analysis_options.yaml` solo incluye
  `package:flutter_lints/flutter.yaml` — no hay reglas custom de rendimiento (fps)
  ni de const-constructors específicas del proyecto. Seguí las reglas estándar de
  `flutter_lints` (`flutter analyze`); no asumas presupuestos de fps que no están
  configurados en ningún lado.
- **Dependencias reales relevantes para IA/salud:** `health` (Health Connect),
  `flutter_blue_plus` (BLE), `image_picker`, `fl_chart` (gráficos), `provider`
  (estado). Antes de sugerir una librería nueva para algo "visual" o "3D", confirmá
  en `pubspec.yaml` que no exista ya algo parecido — no la asumas presente.

## No implementado (no asumir que existe)

- No hay motor de avatares 3D, mapeo corporal en vivo ni análisis de movimiento en
  tiempo real — ni como paquete en `pubspec.yaml` ni como código propio. Elementos
  de UI que parecen sugerirlo (p. ej. el widget `_MeshFigure` en `home_page.dart`)
  son decorativos: un ícono rotado sobre un `CustomPainter`, sin datos de visión
  por computadora detrás.
