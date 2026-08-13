# Personal TrAIner — Guía de contexto para el agente

Este proyecto tiene tres componentes. **No cargues los tres a la vez** salvo que la
tarea explícitamente los cruce (p. ej. un endpoint nuevo que el Flutter consume).
Identifica primero en qué componente cae la tarea y limita la lectura a esa carpeta.

## Estructura y componentes (rutas reales confirmadas)

- **Flutter (frontend)** — `Frontend/personaltrainer/lib/src/` — lee Health
  Connect y el smartwatch Xiaomi/Redmi vía Mi Fitness. Rama activa: `healthconnect`.
  - `lib/src/services/` → `health_service.dart`, `ble_service.dart`,
    `smartwatch_service.dart`, `api_service.dart`
  - `lib/src/features/` → `ai_coach/`, `auth/`, `routine/`, `home/`, `health/`, `onboarding/`
  - `lib/src/models/`, `lib/src/core/`
- **NestJS (backend principal)** — `Backend/Nestjs/src/modules/`
  - Módulos: `ai`, `billing`, `body_analysis`, `clinical_data`, `custom_routine`,
    `daily_summary`, `exercises_catalog`, `identity`, `nutrition`,
    `physical_analysis`, `routine`, `telemetry`, `training_sessions`, `user_profile`
  - `Backend/Nestjs/src/infrastructure/` → config técnica transversal (DB, etc.)
  - **NO leas `Backend/Nestjs/dist/`** — es el build compilado, duplica `src/` en JS.
- **FastAPI (backend de IA)** — `Backend/Python/` (carpeta plana, no hay subcarpetas)
  - `main.py` — entrypoint / endpoints
  - `schemas.py` — modelos pydantic
  - `skills.py` — funciones de IA (nutrition/body/routine analyzers, skills agénticas)
  - Migrando de Ollama/Gemma 4 a Gemini 3.5 Flash (Ollama se mantiene SOLO para
    `analyze_failure()`).

Nota: no encontré `prompt_antigravity.md` ni `design_context.md` /
`flutter_design_context.md` en este clon de `healthconnect` — puede que vivan en
otra rama, fuera del repo, o se hayan renombrado/eliminado. Si siguen en uso,
confirma su ruta exacta antes de que el agente los busque (evita búsquedas a ciegas).

## Archivos clave por tarea típica

### Si la tarea es sobre Health Connect / smartwatch (Flutter)
Lee SOLO:
- `Frontend/personaltrainer/lib/src/services/health_service.dart`
- `Frontend/personaltrainer/lib/src/services/smartwatch_service.dart` (si la tarea
  toca la sincronización Mi Fitness específicamente)
- `Frontend/personaltrainer/lib/src/services/ble_service.dart` (solo si es Bluetooth)
- `Frontend/personaltrainer/lib/src/models/` — solo los modelos de workouts/biometría
- `Frontend/personaltrainer/android/app/src/main/AndroidManifest.xml` (bloque
  `<queries>` y permisos)
- NO leas `lib/src/features/**` salvo que la tarea sea de UI o de un feature concreto.

### Si la tarea es sobre el endpoint de IA (FastAPI)
Lee SOLO:
- `Backend/Python/main.py` (solo el endpoint específico, usa grep para localizarlo)
- `Backend/Python/skills.py` (solo las funciones relevantes, no el archivo completo)
- `Backend/Python/schemas.py` (solo los modelos pydantic que use ese endpoint)
- NO cargues los tres analizadores (nutrition+body+routine) si la tarea es solo uno.

### Si la tarea es sobre NestJS
Lee SOLO el módulo específico dentro de `Backend/Nestjs/src/modules/<modulo>/`
(controller, service, dto de esa ruta). Los módulos relevantes para IA/análisis son
`ai/`, `body_analysis/`, `physical_analysis/`, `nutrition/`, `training_sessions/`.
NO cargues `Backend/Nestjs/dist/` (build compilado, ya excluido por watcher) ni
módulos no relacionados (`billing/`, `identity/`, etc.) salvo que la tarea los toque.

### Si la tarea es sobre diseño UI (Lovable → Flutter)
- Repo `trainer-mind-flow`, carpeta `lovable proyect/src/` en este monorepo si aplica
- Confirma la ruta de `design_context.md` / `flutter_design_context.md` antes de
  leerlos o regenerarlos — no se encontraron en la rama `healthconnect` del repo
  principal, puede que vivan solo en `trainer-mind-flow`.

## Archivos y patrones a NO leer nunca (ruido, no aportan contexto)

- Cualquier archivo generado: `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`
- `pubspec.lock`, `package-lock.json`, `poetry.lock`
- Carpetas de build: `build/`, `dist/`, `.dart_tool/`, `__pycache__/`
- Logs y archivos de debug temporales
- README.md salvo que la tarea sea documentación
- Tests completos al hacer debugging de lógica (lee el test específico, no la suite)

## Reglas de trabajo para minimizar tokens

1. Antes de leer un archivo grande, usa `grep -n` para localizar la sección
   relevante y `sed -n '<start>,<end>p'` para leer solo ese rango. No uses `cat`
   sobre archivos grandes completos. Archivos que YA superan ~250 líneas en este
   repo (léelos siempre por rango, no completos):
   - `Frontend/personaltrainer/lib/src/services/api_service.dart` (~700 líneas)
   - `Frontend/personaltrainer/lib/src/services/ble_service.dart` (~455 líneas)
   - `Backend/Python/main.py` (~400 líneas)
   - `Backend/Python/skills.py` (~375 líneas)
   - `Backend/Python/schemas.py` (~230 líneas)
2. Si una tarea requiere tocar 2+ archivos, decláralos todos al inicio en vez
   de leerlos uno a uno en turnos separados (reduce idas y vueltas).
3. Al depurar el bug de Health Connect (workout records en 0), revisa primero
   los tres sospechosos conocidos antes de explorar código nuevo:
   - `WORKOUT_ROUTE` mal incluido en `_types`
   - `hasPermissions` con falso positivo que salta `requestAuthorization`
   - Falta el intent `androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE` en `<queries>`
4. No regeneres `design_context.md` ni `flutter_design_context.md` "por si acaso";
   solo cuando se confirme que `trainer-mind-flow` cambió.
5. Para sincronizar repos, usa siempre el patrón ya establecido:
   `git fetch origin <branch> && git reset --hard origin/<branch>` — no clones
   completos repetidos en la misma sesión.

<!-- graft:start -->
## Graft — repo context graph

This repo is indexed in `graft/`: small linked markdown nodes that explain each
system and carry exact file:line spans, kept in sync with the code through git.

For ANY task here — understanding how something works, finding where code lives,
or scoping a change — get context from the graph before grepping or opening
source files. Re-ask freely (it's cheap) and reuse literal identifiers you
already have (symbol, error string, file name) as the query. New to this repo?
Run `graft map` first — a token-budgeted orientation (dir clusters, hubs,
hotspots), no LLM, no key.

- Run `graft ask "<your question>" --source` → ranked nodes with the relevant
  code spans inlined (each hit's ≤8-line crux by default; `--full` for whole
  definitions when the crux isn't enough). Match the tool to the task shape:
  for understanding or editing, the top node IS the answer — cite its
  `covers:` file:line spans and edit straight from `--source`. For
  exhaustive tasks ("every occurrence / every caller of this pattern"), ranked
  results are top-N, not complete — run `graft grep "<literal>"` instead
  (exhaustive over indexed files, grouped by enclosing symbol), falling back
  to raw `grep -rn` only for unindexed files.
- `graft skeleton <file>` → every definition's signature + span, ~10× cheaper
  than reading the file; use it to skim an API surface.
- `graft callers <symbol>` gives precomputed, exact edges — who calls this.
  Add `--direction out` for what it calls, or `--depth N` to walk
  transitively for the full blast radius. For structural questions, skip
  ranking and use this directly.
- Or browse: `graft/INDEX.md` lists every node; follow the links.
- Monorepos and folders of multiple repos rank fairly across sub-projects —
  hits carry `[scope/]` labels naming which one they're from. Narrow with
  `graft ask "<task>" --in <scope>/` once you know where you're working.

If a returned span is truncated ("+N more lines"), open the file at that exact
range before finalizing. Only open source files when a node genuinely lacks a
needed detail, and then at the exact file:line the node points to — never
re-read whole files.

After big code changes, refresh the graph with `graft build` (deterministic,
no API key, $0).
<!-- graft:end -->
