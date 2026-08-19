---
name: agente_conversacional_rag
description: Lineamientos para los system prompts por modo, el historial conversacional y el catálogo de tools (internas + APIs externas) del AI Coach (chat_engine.py / chat_tools.py). No hay RAG ni audio — ver sección "No implementado".
---

# Dinámica Conversacional del AI Coach

- **System prompting por modo, no por personalidad:** no hay perfiles de entrenador
  (estricto/empático/militar) seleccionables. Hay 6 modos fijos —
  `creador_rutina`, `revisor_rutina`, `sueno_recuperacion`, `nutricion`,
  `entrenamiento`, `analisis_fisico` — cada uno con su propio `SYSTEM_PROMPTS[mode]`
  estático en `Backend/Python/chat_tools.py`. Al tocar el tono o las reglas de un
  modo, editá el prompt de ESE modo puntualmente; no hay un prompt "maestro"
  compartido entre todos (más allá de `BASE_GUIDELINES`, común a los 6).
- **Function calling, no razonamiento libre:** cada modo expone un subconjunto de
  tools en `TOOLS_BY_MODE` (`chat_tools.py`). El loop vive en
  `Backend/Python/chat_engine.py::run_chat`, hasta 5 iteraciones
  (`MAX_TOOL_ITERATIONS`) llamando tools hasta producir texto final. **El
  proveedor que ejecuta ese loop depende del modo, no es siempre Gemini:**
  `creador_rutina`/`revisor_rutina`/`sueno_recuperacion`/`entrenamiento` corren
  contra Groq, `nutricion`/`analisis_fisico` contra Gemini — mecánica de
  enrutamiento, retry y por qué, en `backend_python_ai/SKILL.md` (esta skill
  se queda con el QUÉ hace cada modo, no con el CÓMO se elige proveedor).
  `_function_decl_to_groq_tool` traduce cada `types.FunctionDeclaration` al
  formato de Groq automáticamente: una tool nueva registrada en
  `TOOLS_BY_MODE` funciona en ambos proveedores sin tocar `chat_engine.py`.
- **Memoria = historial de turnos del propio request, nada más:** `history` es una
  lista `[{role, text}]` que el cliente (Flutter) reenvía completa en cada llamada a
  `/api/ia/chat` (`schemas.py::ChatTurn`, `ChatRequest`). No hay persistencia del
  lado del servidor entre requests, ni resumen, ni embeddings — si el cliente no
  reenvía un turno anterior, el modelo no lo "recuerda".
- **Imágenes:** se aceptan como `ChatImage {data, mimeType}`, se decodifican en
  `chat_engine.py` (`base64.b64decode`) y se adjuntan como partes multimodales
  directas al mensaje del usuario — solo llegan a los 2 modos Gemini-only.
  Excepción puntual en `analisis_fisico`: la imagen también se pre-procesa con
  MediaPipe (landmarks de pose) antes de armar el prompt — ver
  `vision_computacional_postura/SKILL.md`. En el resto de modos no hay
  preprocesado ni almacenamiento intermedio de la imagen en el servicio Python.

## Catálogo de tools por modo — internas + APIs externas

Cada modo mezcla tools que escriben/leen datos propios del usuario en NestJS
(vía `nest_client.py`) con tools de consulta a catálogos públicos (APIs
externas de terceros, vía el patrón descrito en `backend_python_ai/SKILL.md`).
Distinción importante para no confundir una con otra al leer `chat_tools.py`:
las internas devuelven/mutan datos DEL usuario (su rutina, su historial); las
externas devuelven datos de REFERENCIA que cualquier usuario vería igual (un
ejercicio del catálogo de wger, los macros de una manzana) y nunca escriben
nada en NestJS directamente — como mucho, alimentan a una tool interna (p. ej.
`registrar_comida`) con cifras más precisas que las que el modelo estimaría de
memoria.

- **`creador_rutina` / `revisor_rutina`:** ambas suman `buscar_ejercicios_wger`
  (catálogo externo, filtra por `grupo_muscular`/`equipamiento` más ampliamente
  que `buscar_ejercicios_catalogo`). Ojo, no son simétricas del todo:
  `calcular_metricas_salud` (IMC/TMB/TDEE, Mifflin-St Jeor, sin llamada de red
  — ver `backend_python_ai/SKILL.md`) solo está en `creador_rutina` (para
  fundamentar volumen/calorías al diseñar), no en `revisor_rutina` — al
  revisar una rutina existente no hace falta recalcularlo.
- **`nutricion`:** suma `buscar_producto_openfoodfacts` (producto envasado),
  `buscar_alimento_usda` (ingrediente crudo individual),
  `estimar_macros_ingredientes` (plato casero con Edamam) y también
  `calcular_metricas_salud` — decisión de cuál tool usar según el caso, detalle
  completo en `razonamiento_nutricional_mllm/SKILL.md`. El modelo las llama
  ANTES de `registrar_comida` para reemplazar una estimación de memoria por una
  cifra real de una base de datos, cuando el alimento es identificable.
- **`sueno_recuperacion`:** suma `buscar_medicamento_openfda` (info de
  etiqueta de medicamentos/suplementos que el usuario mencione, vía OpenFDA).
  El system prompt de este modo tiene una instrucción marcada como
  OBLIGATORIA: cada vez que se use o mencione esta información, aclarar que es
  referencia de etiqueta oficial, no diagnóstico ni recomendación de dosis —
  si tocás este prompt, no debilites ni quites ese disclaimer.
- **`analisis_fisico`:** no suma tools nuevas — la mejora es el preprocesado
  automático con MediaPipe antes del prompt, no una tool que el modelo decida
  llamar (ver `vision_computacional_postura/SKILL.md`).
- **`entrenamiento`:** sin cambios — sigue siendo solo `registrar_sesion_entrenamiento`.

Este catálogo ya está implementado (no es diseño pendiente) — de todos modos,
ante la duda confirmá contra `TOOLS_BY_MODE`/`EXECUTORS` en `chat_tools.py`,
que es la fuente de verdad si esta sección queda desactualizada.

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
- **Selección de tools por relevancia semántica:** `TOOLS_BY_MODE` es un mapeo
  estático por modo, no hay ranking ni filtrado dinámico de qué tools mostrarle
  al modelo — cuantas más tools sume un modo, más grande el catálogo que ve en
  cada llamada. Si un modo crece mucho, es una razón válida para dividirlo, no
  para inventar selección dinámica sin que se pida explícitamente.
