---
name: razonamiento_nutricional_mllm
description: Reglas para el modo `nutricion` — razonamiento visual con Gemini sobre fotos de comida, guardando calorías/macros cuantificados. Único punto de entrada para comida-por-foto (chat del AI Coach y botón de cámara de Nutrición).
---

# Razonamiento Nutricional Visual (modo `nutricion`)

- **Modelo real: Gemini, no GPT-4V ni Claude.** El razonamiento visual sobre fotos
  de comida lo hace `gemini-3.5-flash` vía `google-genai`
  (`Backend/Python/chat_engine.py`), en el modo `nutricion` de
  `chat_tools.py::SYSTEM_PROMPTS`.
- **La salida es cuantitativa, no una clasificación semántica:** el prompt del
  modo pide explícitamente estimar calorías y macros a partir de la imagen o
  descripción y guardarlos con la tool `registrar_comida`
  (`chat_tools.py::registrar_comida_decl`), que persiste
  `calorias_consumidas, proteinas_g, carbohidratos_g, grasas_g, notas` en
  `NutritionLog`
  (`Backend/Nestjs/src/modules/nutrition/entities/nutrition_log.entity.ts`). Si
  ajustás este flujo, mantené ese contrato de campos — es lo que consume el resto
  de la app (resúmenes diarios, gráficos, etc.).
- **UX real — sí es "sacar una foto y listo", desde DOS pantallas:** el usuario
  adjunta una foto desde `image_picker`, se envía en base64 dentro del mensaje de
  chat, y el modelo la analiza en el mismo turno sin pasos intermedios de
  formulario. Dos puntos de entrada llaman a
  `ApiService.sendChatMessage(mode: 'nutricion', ...)` con el mismo payload
  `{data, mimeType}`: la pantalla de chat del AI Coach (`ai_coach_page.dart`) y el
  botón de cámara de la pantalla de Nutrición
  (`home_page.dart::_NutritionScreenState._takePhoto`). Antes este último pasaba
  por un endpoint aparte con Ollama local (`POST /api/ia/analizar-nutricion`,
  eliminado) — hoy ambos caminos terminan en este mismo modo. Esta parte del
  objetivo original (reducir la fricción de loguear comidas a mano) sí está
  lograda — mantenela al tocar este modo.
- **El modelo puede no guardar nada en el turno:** a diferencia del viejo endpoint
  de Ollama (que siempre guardaba o tiraba error), acá guardar queda a criterio del
  modelo — puede pedir una aclaración en vez de llamar a `registrar_comida` (ej.
  foto poco clara). `home_page.dart` maneja ese caso leyendo `actions_taken`: si
  viene vacío, muestra el `reply` del modelo en un SnackBar en vez de la tarjeta de
  macros. No guardar silenciosamente es comportamiento esperado, no un bug — tenelo
  en cuenta si tocás el system prompt del modo.
- **`obtener_resumen_diario`** trae lo consumido en el día vs. objetivos de
  macros — usalo para preguntas tipo "¿cómo voy hoy?" en vez de recalcular a mano.

## No implementado (no asumir que existe)

- No hay clasificación de nivel de procesamiento (NOVA) ni ningún campo o lógica
  relacionada — no la menciones como parte del análisis si tocás este modo.
