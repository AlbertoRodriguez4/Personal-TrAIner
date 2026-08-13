---
name: agente_conversacional_rag
description: Lineamientos para los system prompts por modo y el historial conversacional del AI Coach (chat_engine.py / chat_tools.py). No hay RAG ni audio — ver sección "No implementado".
---

# Dinámica Conversacional del AI Coach

- **System prompting por modo, no por personalidad:** no hay perfiles de entrenador
  (estricto/empático/militar) seleccionables. Hay 6 modos fijos —
  `creador_rutina`, `revisor_rutina`, `sueno_recuperacion`, `nutricion`,
  `entrenamiento`, `analisis_fisico` — cada uno con su propio `SYSTEM_PROMPTS[mode]`
  estático en `Backend/Python/chat_tools.py`. Al tocar el tono o las reglas de un
  modo, editá el prompt de ESE modo puntualmente; no hay un prompt "maestro"
  compartido entre todos.
- **Function calling, no razonamiento libre:** cada modo expone un subconjunto de
  tools en `TOOLS_BY_MODE` (`chat_tools.py`). El loop vive en
  `Backend/Python/chat_engine.py::run_chat` — Gemini (`gemini-3.5-flash` vía SDK
  `google-genai`) itera hasta 5 veces (`MAX_TOOL_ITERATIONS`) llamando tools hasta
  producir texto final. Las tools ejecutan HTTP contra NestJS vía `nest_client.py`.
- **Memoria = historial de turnos del propio request, nada más:** `history` es una
  lista `[{role, text}]` que el cliente (Flutter) reenvía completa en cada llamada a
  `/api/ia/chat` (`schemas.py::ChatTurn`, `ChatRequest`). No hay persistencia del
  lado del servidor entre requests, ni resumen, ni embeddings — si el cliente no
  reenvía un turno anterior, el modelo no lo "recuerda".
- **Imágenes:** se aceptan como `ChatImage {data, mimeType}`, se decodifican en
  `chat_engine.py` (`base64.b64decode`) y se adjuntan como partes multimodales
  directas al mensaje del usuario — no hay preprocesado ni almacenamiento
  intermedio de la imagen en el servicio Python.

## No implementado (no asumir que existe)

- **RAG / memoria vectorial:** no hay vector store, embeddings ni base de
  conocimiento indexada en ningún punto del repo. Si una tarea pide "recordar" algo
  entre sesiones, la única vía real hoy es guardar un dato estructurado en Postgres
  vía una tool (como hace `guardar_analisis_recuperacion`) y volver a leerlo con
  otra tool — no inventar una capa de recuperación semántica.
- **Audio full-duplex / voz:** no existe ningún canal de audio, ni entrada ni
  salida — el pipeline es siempre texto + imagen → JSON, por request/response HTTP.
  Trabajo de voz (tipo Moshi/PersonaPlex) sería una feature nueva de punta a punta,
  no una extensión de algo existente.
