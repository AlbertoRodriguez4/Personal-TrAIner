---
name: backend_python_ai
description: Reglas para el servicio FastAPI de IA — enrutamiento ESTRICTO por modo (Groq openai/gpt-oss-120b para texto, Gemini solo para imagen), retry en ambos proveedores, patrón de integración de APIs externas de terceros. Sin PyTorch/TensorFlow ni Ollama.
---

# Desarrollo del Servicio de IA (Python / FastAPI)

- **Framework real:** FastAPI + Pydantic para validar payloads entrantes desde
  NestJS (`main.py`, `schemas.py`).
- **Dos proveedores de LLM en la nube, ninguno local:** Gemini (`google-genai`) y
  Groq (`groq`). El chat agentic vive en `chat_engine.py` (loop de function
  calling de máx. 5 iteraciones, `MAX_TOOL_ITERATIONS`) + `chat_tools.py`
  (tools/executors/prompts por modo). Las tools de datos internos llaman de
  vuelta a NestJS vía `nest_client.py` (wrapper fino sobre `requests`); las
  tools de APIs externas siguen el patrón descrito más abajo. Única excepción a
  "nada corre localmente": el preprocesado de pose con MediaPipe en el modo
  `analisis_fisico` — es un modelo de landmarks liviano (CPU, TFLite,
  determinístico dado el frame), no un modelo generativo ni de entrenamiento.
  Ver `vision_computacional_postura/SKILL.md`.

## Enrutamiento ESTRICTO por modo — Groq (texto) / Gemini (imagen)

Decisión de arquitectura fija, no un fallback reactivo. `run_chat()` en
`chat_engine.py` decide el proveedor por `mode`, antes de llamar a nada:

- **Groq (`GROQ_MODEL`, default `openai/gpt-oss-120b`) — modos de solo texto:**
  `creador_rutina`, `revisor_rutina`, `sueno_recuperacion`, `entrenamiento`.
  Nunca tocan Gemini, ni siquiera como respaldo — así la cuota diminuta de
  Gemini (15 RPM / 500 RPD en el free tier) queda intacta para lo que de verdad
  la necesita.
- **Gemini (`GEMINI_MODEL`, default `gemini-3.5-flash-lite`) — modos con imagen
  (`IMAGE_MODES`):** `nutricion`, `analisis_fisico`. Nunca caen a Groq (no
  procesa imágenes) ni a ningún otro modelo como sustituto silencioso — ver
  "Al agotar Gemini" más abajo.
- **Por qué no es un fallback reactivo:** la versión anterior intentaba Gemini
  primero siempre y solo usaba Groq si Gemini devolvía 429. Eso seguía gastando
  al menos 1 llamada a Gemini por turno de texto — con 5 RPM, unos pocos turnos
  ya la agotaban. El enrutamiento por modo hace que los 4 modos de texto (la
  mayoría del tráfico conversacional) **jamás** consuman cuota de Gemini.
- **Nunca se mezclan proveedores dentro de un mismo turno:** el historial de
  function-calls de Gemini (`types.Content`/`function_call`/`function_response`)
  no es compatible con el formato de Groq (`tool_calls`/`role: tool`). Cada modo
  usa un único proveedor de punta a punta en cada request.
- **Contrato de salida idéntico en ambos caminos:** `{"reply": str,
  "actions_taken": [{"tool": str, "result": dict}]}` — `main.py` y el frontend
  Flutter no pueden distinguir qué proveedor respondió. `_execute_tool` y
  `EXECUTORS` (`chat_tools.py`) son compartidos por ambos caminos.

## Retry en AMBOS proveedores ante 429

- **Gemini:** `_generate_with_retry` reintenta hasta `RETRY_ATTEMPTS` (3) veces
  con backoff corto (`RETRY_BACKOFF_SECONDS`, 1s/2s) solo ante
  `google.genai.errors.ClientError` con `code == 429` /
  `status == "RESOURCE_EXHAUSTED"` — cualquier otro error (4xx distinto, red)
  sube tal cual, sin reintentar. `_generate_with_model_fallback` añade un
  intento más contra `GEMINI_MODEL_FALLBACK` (env, opcional) antes de rendirse.
  Al agotar todo, levanta `GeminiQuotaExhaustedError`.
- **Groq tiene el mismo tratamiento que Gemini, no solo Gemini:** con el
  enrutamiento estricto, Groq deja de ser un respaldo ocasional y pasa a ser
  el **único** proveedor de 4 de los 6 modos. `_create_groq_completion_with_retry`
  (`chat_engine.py`) reintenta ante `groq.RateLimitError` (429) con el mismo
  `RETRY_ATTEMPTS`/`RETRY_BACKOFF_SECONDS` que Gemini. Jerarquía de
  excepciones: `LLMProviderExhaustedError` es la base, `GeminiQuotaExhaustedError`
  y `GroqQuotaExhaustedError` heredan de ella — `main.py` captura cada una por
  separado porque el mensaje al usuario es distinto (uno menciona la imagen,
  el otro es genérico).
- **Al agotar Gemini en un modo de imagen:** respuesta amigable al usuario (sin
  fallback silencioso a otro modelo) — ver `razonamiento_nutricional_mllm` y
  `vision_computacional_postura` para el mensaje exacto por modo.
  `qwen/qwen3.6-27b` de Groq (modelo en preview, sí procesa imágenes) queda
  **documentado como alternativa explícita, no implementada** — activarla es
  una decisión de producto pendiente, no algo que se dispare solo.

## Variables de entorno: usar `_env()`, nunca `os.environ.get(k, default)` a secas

`os.environ.get("X", "default")` devuelve `""` cuando la variable **existe pero está
vacía** — el default solo aplica si la clave no está. Un `.env` con `GEMINI_MODEL=`
(línea presente, valor vacío) hacía que se llamara a la API con `model=""` → 400
"falta especificar el modelo" en los 2 modos de imagen. El helper `_env(nombre,
default)` (`chat_engine.py`) trata vacío y ausente por igual, y además hace `.strip()`.
Usalo para toda variable nueva: los `.env` reales suelen tener claves vacías como
plantilla.

## MAX_TOOL_ITERATIONS es un presupuesto de trabajo, no solo una guarda

`MAX_TOOL_ITERATIONS` (8) es el techo de pasos de function calling por turno. No es
solo una red contra loops infinitos: **si el modelo lo agota investigando, la acción
que el usuario pidió no se ejecuta**. Pasó de verdad al sumar `buscar_ejercicios_wger`
a `creador_rutina`: con 2 tools de búsqueda y 5 iteraciones, el modelo hacía una
búsqueda por grupo muscular y nunca llegaba a `crear_rutina_personalizada` — el
usuario veía "se alcanzó el límite de pasos" y no se creaba nada. Dos mitigaciones,
ambas necesarias:

- **Presupuesto explícito en el system prompt del modo**: decirle cuántas llamadas
  tiene y que priorice la acción sobre la investigación (ver `creador_rutina`).
  Al sumar tools a un modo, revisá si su prompt necesita esta guía.
- **Cierre forzado sin tools**: al agotar las iteraciones, ambos loops
  (`_run_chat_gemini` y `_run_chat_groq`) hacen una última llamada **sin** `tools`,
  que obliga al modelo a redactar con lo que ya recabó. `LIMITE_PASOS_MSG` queda solo
  como último recurso si también falla ese cierre.

## El techo real de Groq free tier son 8000 TPM, no el contexto del modelo

Verificado contra la API: `openai/gpt-oss-120b` en tier `on_demand` tiene **8000 tokens
por minuto**, y Groq cuenta **entrada + `max_completion_tokens` reservados en la misma
petición** (no el output real). Nada que ver con la ventana de contexto del modelo, que
es mucho mayor. Dos fallos distintos salen de ahí, y ninguno se arregla reintentando lo
mismo — por eso ambos se traducen a `RespuestaDemasiadoGrandeError` → HTTP 413:

- **413 `rate_limit_exceeded` / type `tokens`**: entrada + reserva > 8000. Por eso
  `max_completion_tokens` se calcula por llamada en `_presupuesto_completion()` en vez
  de mandarse fijo: un valor fijo de 5000 revienta en cuanto la conversación acumula
  resultados de tools.
- **400 `tool_use_failed`**: el modelo cortó su propio JSON a medio generar y Groq no
  pudo parsearlo. Pasa con payloads grandes (una rutina de 6 días con notas largas).
  Recuperación implementada: **un** reintento inyectando un mensaje de sistema que le
  pide compactar la salida (notas cortas, menos ítems). Medido: convierte un fallo duro
  en una rutina válida de 30 ejercicios. Si el segundo intento también corta, ahí sí
  sube el 413.

`reasoning_effort="low"` en todas las llamadas a Groq: gpt-oss-120b es un modelo de
razonamiento y sus tokens de "pensamiento" compiten con la salida dentro de esos mismos
8000. Medido: ~600 tokens menos por llamada sin degradar tareas estructuradas (rellenar
el schema de una tool).

## Contratos con el cliente Flutter: valores acordados, no texto libre

Un campo que la app usa como **clave** (no como texto a mostrar) tiene que estar
restringido por `enum` en la `types.Schema` de la tool. Caso real:
`tipo_entrenamiento` viaja sin traducción a `activity_type`
(`RoutineService.createFromAiPayload`) y `routine_builder_page.dart` lo busca con
`firstWhere` en una lista fija de 5 tipos (`gym`, `cardio`, `calistenia`, `yoga`,
`deportes`) **sin `orElse`** → un "Fuerza" o "Hipertrofia" del modelo reventaba la
pantalla con `Bad state: No element`, y de paso escondía el campo de peso (solo se
muestra si el tipo es `gym`). El `enum` en el schema lo ataja del lado del modelo.
Antes de dejar un campo como STRING libre, comprobá si el cliente lo usa para buscar,
comparar o enrutar.

Segundo caso idéntico, más silencioso: `day_of_week`. NestJS lo generaba como
`` `Día ${numero_dia}` `` y `routine_builder_page.dart` filtra el plan semanal con
`_weekDays.where((d) => _selectedDays.contains(d))` sobre Lunes..Domingo — sin match,
la pantalla de edición sale **vacía aunque la rutina esté completa en la BD**, y al
guardar se pierden todos los días. Arreglado con un `dia_semana` (enum Lunes..Domingo)
en el schema de la tool + `RoutineService.createFromAiPayload` usándolo, con fallback
por índice para rutinas viejas. Moraleja: un campo que "solo se muestra" hoy puede ser
una clave de join mañana — si el cliente lo compara con una constante, restringilo.

## Modelos: cuáles usar y cuáles evitar

- **Groq — usar `openai/gpt-oss-120b`.** `llama-3.3-70b-versatile` y
  `qwen/qwen3-32b` están **deprecados oficialmente por Groq** — no configurar
  ninguno de los dos como default ni como valor de ejemplo en `.env.example`,
  bajo ningún concepto.
- **Gemini — `gemini-3.5-flash-lite`** vía `GEMINI_MODEL` (env): 15 RPM / 500 RPD
  en el free tier, frente a los 5 RPM / 20 RPD de `gemini-3.5-flash` (cuotas
  independientes por modelo, no un pozo compartido). `GEMINI_MODEL_FALLBACK`
  opcional para un segundo modelo de respaldo dentro del propio Gemini (no
  confundir con el fallback a Groq, que ya no existe para modos de imagen).
- **Una sola API key por servicio:** nunca rotar múltiples keys de un mismo
  proveedor (Gemini, Groq, o cualquiera de las APIs externas de abajo) para
  eludir su límite de cuota — eso aplica también a las integraciones nuevas.

## APIs externas de terceros — patrón de integración

Las tools que consultan datos internos llaman a NestJS vía `nest_client.py`;
las que consultan catálogos/bases de datos públicas (ejercicios, alimentos,
medicamentos) siguen el mismo espíritu pero contra el servicio externo
correspondiente, cada una en su propio módulo cliente delgado sobre `requests`
(mismo patrón que `nest_client.py`: base URL por env var, timeout corto,
excepción propia con status+detail). Reglas transversales:

- **Nunca rompen el turno de chat si fallan:** son fuentes de enriquecimiento,
  no de persistencia crítica. Un timeout o 5xx de una API externa se captura en
  el propio cliente y el tool devuelve un resultado degradado (p. ej.
  `{"disponible": false}` o una lista vacía) en vez de dejar subir la
  excepción — el modelo sigue el turno con lo que tenga, como ya hace
  `_execute_tool` al capturar cualquier `Exception` del executor.
  Este es el mismo motivo por el que la cuota de Gemini se trató con tanto
  cuidado: una dependencia externa lenta o agotada nunca debe tumbar la
  respuesta completa.
- **Cada integración documenta su propio rate limit** en el módulo cliente (un
  comentario corto basta) — no asumir que "es gratis" significa "sin límite".
- **Registro en `TOOLS_BY_MODE`/`EXECUTORS` igual que las tools internas:** una
  `types.FunctionDeclaration` + función ejecutora en `chat_tools.py`, sin tocar
  `chat_engine.py` — `_function_decl_to_groq_tool` ya convierte cualquier
  declaración nueva al formato Groq automáticamente, así que una tool nueva
  funciona en ambos proveedores sin código adicional, salvo que solo se
  registre en modos de un proveedor (p. ej. una tool de imagen solo tiene
  sentido en `nutricion`/`analisis_fisico`, que son Gemini-only).

### Catálogo de APIs externas implementadas (verificado en vivo, agosto 2026)

| API | Módulo | Auth | Free tier | Modo(s) |
|---|---|---|---|---|
| wger | `wger_client.py` | Ninguna (lectura pública) | Sin límite en ejercicios/categorías/equipamiento/músculos | `creador_rutina`, `revisor_rutina` |
| Open Food Facts | `openfoodfacts_client.py` | Ninguna (solo `User-Agent` descriptivo, env `OPENFOODFACTS_USER_AGENT`) | ~15 req/min lectura, ~10 req/min búsqueda (informal) | `nutricion` |
| USDA FoodData Central | `usda_client.py` | API key gratis (env `USDA_FDC_API_KEY`, si falta usa `DEMO_KEY`) | 1.000 req/hora (30/hora con `DEMO_KEY`) | `nutricion` |
| Edamam Nutrition Analysis | `edamam_client.py` | `X-RapidAPI-Key` (env `RAPIDAPI_KEY`) | 1.000 req/día, 50/min — uso personal/no comercial | `nutricion` |
| OpenFDA | `openfda_client.py` | Ninguna, o env `OPENFDA_API_KEY` para más cupo | 1.000 req/día sin key, 120.000 req/día con key gratis | `sueno_recuperacion` |
| — (cálculo local, no es API) | `health_calculators.py` | N/A | N/A (sin llamada de red) | `creador_rutina`, `nutricion` |

**Edamam es el único cliente sin verificación en vivo:** wger, Open Food Facts,
USDA y OpenFDA se probaron con requests reales contra la API real durante la
implementación; Edamam requiere una `RAPIDAPI_KEY` que no estaba disponible en
ese momento — el contrato (`POST /api/nutrition-details`, body
`{"title", "ingr": [...]}`, campos `totalNutrients.ENERC_KCAL/PROCNT/FAT/CHOCDF`)
está armado con documentación pública, no con una llamada real. Antes de
darlo por cerrado, probalo con una key real — si el shape no coincide, la
tool ya degrada a `{"encontrado": False}` en vez de romper el turno, así que
el peor caso es "no funciona todavía", no un crash.

**Con una sola API key por servicio** (`WGER` no necesita key; una única
`RAPIDAPI_KEY` sirve para Edamam y, si se suma más adelante, ExerciseDB, porque
RapidAPI emite una key por cuenta válida para todas las APIs suscritas en su
marketplace — no confundir con "múltiples keys para eludir cuota", que sigue
prohibido).

**Descartadas explícitamente (no implementar), con motivo:**
- **ExerciseDB (RapidAPI):** cuota gratuita real de solo 690 req/mes (~23/día)
  y el nombre está fragmentado entre 3 productos no relacionados (este listado
  de RapidAPI, el dataset estático `yuhonas/free-exercise-db`, y
  `exercisedb.dev`, cuyos propios docs desaconsejan su tier gratuito para
  producción). Queda como candidata de fase futura solo para GIFs de
  demostración, usada con moderación (no para búsquedas masivas), nunca como
  reemplazo de wger.
- **"Gym-Fit API":** identificada como un producto de un único desarrollador
  indie (RapidAPI, `gymfit-api.com`) cuya documentación oficial devuelve 404
  ("Legacy Developer Portal — shut down") verificado en vivo. Demasiado frágil
  para depender de ella. TMB (Mifflin-St Jeor), TDEE e IMC se calculan
  localmente en Python puro — son fórmulas estándar, no requieren ninguna API.
- **FatSecret:** su tier gratuito (Basic, 5.000 req/día) es sólido en volumen
  pero los datos localizados fuera de EE.UU. — incluida España — están
  documentados como "premium feature" sujeta a revisión de elegibilidad;
  sumale el overhead de OAuth2 client-credentials frente a Open Food Facts (sin
  auth) y Edamam (ya integrado). Queda documentada como alternativa de fase 2,
  no implementada.
- **HealthData.gov / portal de salud de la UE:** confirmado que son catálogos
  de datasets (CKAN / DCAT de metadatos), no APIs de consulta puntual — no
  encajan en el patrón "una pregunta del chat → una respuesta estructurada" que
  necesita el tool-calling. Fuera de alcance como tools; no hay sustituto
  porque no resuelven el mismo problema que OpenFDA.
- **OpenPose:** mantenimiento parado desde 2020, requiere GPU/CUDA, build
  C++/CMake no trivial en Windows, y licencia CMU no-comercial que bloquearía
  un uso más amplio de la app sin acuerdo aparte. MediaPipe Pose gana en todos
  los ejes para este caso de uso (una foto, sin GPU) — ver
  `vision_computacional_postura/SKILL.md`.

## Ollama (histórico — no reintroducir)

- El análisis de comida por foto (antes `POST /api/ia/analizar-nutricion`, con
  Ollama local y `model: "gemma4:e4b"` hardcodeado) se migró al modo
  `nutricion` de `chat_engine.py` — ver `razonamiento_nutricional_mllm/SKILL.md`.
  `analyze_failure()` (`skills.py`) es un algoritmo determinístico en Python
  puro (curva de FC del smartwatch) — no llama a ningún modelo ni a Ollama,
  pese a lo que digan `CLAUDE.md`/`AGENTS.md` (desactualizados en ese punto). No
  queda ninguna referencia a Ollama en `Backend/Python/*.py` — no la
  reintroduzcas.

## Errores predecibles

- Los endpoints envuelven las excepciones en `HTTPException` con código y
  detalle explícito (`ValueError` → 400, cuota agotada → 503, resto → 500) —
  mantené ese patrón. Las APIs externas de terceros son la excepción a "subí la
  excepción": esas se degradan dentro del tool, como se explica arriba, para no
  convertir una fuente de enriquecimiento en un punto de fallo del turno
  completo.

## No implementado (no asumir que existe)

- No hay entrenamiento ni fine-tuning de ningún modelo, ni tensores/GPU en este
  servicio — la única inferencia local es el preprocesado de pose de MediaPipe
  (liviano, CPU, no generativo; ver `vision_computacional_postura/SKILL.md`),
  todo el razonamiento en lenguaje natural sigue siendo 100% Gemini/Groq en la
  nube.
- No hay múltiples API keys por servicio para eludir límites de cuota (ni en
  Gemini/Groq ni en ninguna API externa nueva).
- No hay fallback a `qwen/qwen3.6-27b` implementado — solo documentado como
  opción futura explícita.
