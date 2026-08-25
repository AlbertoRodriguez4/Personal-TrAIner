# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Read [AGENTS.md](AGENTS.md) first.** It has hard rules for which files to load per task type and how to
avoid burning tokens on this repo (grep-then-range-read on large files, don't load all 3 components at
once, etc.). Those rules are load-bearing — follow them before reading anything below.

## What this is

Personal TrAIner: a Flutter fitness/AI-coaching app (Android, targets Health Connect + a Xiaomi/Redmi
smartwatch via Mi Fitness) backed by a NestJS API and a FastAPI service that does the AI coaching work
via Gemini and Groq. Active branch: `healthconnect`.

There is also a `lovable proyect/` folder (React + Vite + Tailwind) — a **visual mockup only**, synced
from Lovable, not production code. It has its own `AGENTS.md`; don't mix its patterns into the Flutter app.

## Repo layout

```
Frontend/personaltrainer/   Flutter app (lib/src/{features,services,models,core})
Backend/Nestjs/             Main API — TypeORM + PostgreSQL, modular by domain
Backend/Python/             FastAPI AI service — flat, no subfolders
lovable proyect/            React design reference (not shipped)
iniciar_proyecto.bat/.ps1   Boots all 3 services at once (Windows)
```

## Running things

**All at once (Windows):** double-click `iniciar_proyecto.bat`, or `.\iniciar_proyecto.ps1` from
PowerShell. Requires Node 18+, Python 3.10+ (`py` launcher), Flutter SDK, PostgreSQL running.
Opens 3 terminals: Python (8000), NestJS (3000), Flutter (Chrome).

**NestJS** (`Backend/Nestjs/`):
```
npm run start:dev              # watch mode, port 3000
npm run build
npm run migration:generate     # writes to src/infrastructure/postgres/migrations/
npm run migration:run
```
No test script / no `.spec.ts` files exist in this module yet — don't go looking for a test suite here.

**Python AI service** (`Backend/Python/`):
```
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```
No test suite here either.

**Flutter** (`Frontend/personaltrainer/`):
```
flutter pub get
flutter run
flutter test                        # test/health_test.dart, test/configure_test.dart
flutter test test/health_test.dart  # single file
flutter analyze                     # flutter_lints, see analysis_options.yaml
```

**Lovable mockup** (`lovable proyect/`):
```
npm run dev / build / lint / typecheck
```

## Architecture

**Request flow:** Flutter → NestJS (`Backend/Nestjs/src/modules/`) for CRUD/persistence (Postgres via
TypeORM) → NestJS's `ai/` module `fetch()`s the Python FastAPI service for anything AI-related.
Separately, the Python service calls back into NestJS via `Backend/Python/nest_client.py` (a thin HTTP
client) so the AI chat can read/write real user data — this is the tool-execution path for the agentic
coach. `chat_engine.py` runs the chat loop, `chat_tools.py` defines what the model can call.

**NestJS modules** (`src/modules/`): `ai`, `billing`, `body_analysis`, `clinical_data`, `daily_summary`,
`exercises_catalog`, `identity`, `nutrition`, `physical_analysis`, `recovery`, `routine`, `supplements`,
`telemetry`, `training_sessions`, `user_profile`. Each follows controller/service/entities/dto.
`src/infrastructure/`
holds cross-cutting config (Postgres data-source, an unused InfluxDB scaffold). Never read
`Backend/Nestjs/dist/` — it's the compiled build, duplicates `src/` in JS.

**Body data (the AI's memory of the user's body).** Three pipelines in `Backend/Python/`,
in this order of importance — the order matters, it's baked into the prompt:

- `body_composition.py` — **the main one**. Weight, BMI, body-fat %, fat mass, lean mass,
  muscle mass, FFMI. It's where calories, macros and the bulk-vs-recomp call come from, and
  it's the only *measured* signal (photos estimate, blood says something else). Deliberately
  **calls no LLM**: the numbers come from a device and the classification from cited tables
  (ACE, WHO, Kouri 1995 for FFMI) in `clinical_reference.clasificar_composicion`. Stored in
  `Densitometrias_DEXA` — the table name is historical; it holds any method (`metodo`:
  dexa/bioimpedancia/plicometria/bascula/otro).
  **Every metric is nullable.** A home scale gives weight and a percentage; a DEXA gives ten
  fields. `DexaScanService.derivar()` fills in whatever is deducible (every kg ↔ % pair —
  fat, muscle, protein, water — plus lean mass, BMI, FFMI) so the history is homogeneous —
  never derive these in the client or the prompt, or the same number ends up defined twice.
  **Always order by `(fecha_escaneo DESC, fecha_registro DESC)`.** `fecha_escaneo` is a
  `date` with no time, so two measurements on the same day tie and Postgres returns them in
  whatever order it likes — weigh yourself twice, correct the entry, and the coach keeps
  reading the first one.
  The real minimum for the whole app is **weight + height**, and those live on `Usuarios`,
  not here.
- `clinical_analysis.py` — PDF/photo of a lab report → Gemini extracts *literally* (pass 1,
  temp 0) → normalized against `clinical_reference.py` and enriched via `medlineplus_client.py`
  (NIH/NLM MedlinePlus Connect, LOINC-keyed, no API key) → Gemini writes the report (pass 2,
  no document present). Persists to `Informes_Clinicos` + `Biomarcadores_Clinicos`. The two
  passes are the point: interpretation can only lean on the contrasted block it was handed.
  Also serves the manual-entry form (`analizar_valores_manuales`), so typed values get the
  same treatment.
  Pass 1 *also* extracts a `composicion_corporal` block when the document is a DEXA/InBody,
  and hands it to `body_composition.desde_documento` **before** redacting, so the report is
  written against the new numbers. A document with composition but no blood markers returns
  the composition reading and skips the clinical report entirely — there's no analytic to
  write about.
- `physique_analysis.py` — physique photos → `pose_analysis` geometry + ACE/WHO/ISSN norms →
  structured record + photos. If the model sets `fotos_analizables: false`, NOTHING is saved:
  a guessed `grupos_musculares_retrasados` would silently steer every routine after it.
- `clinical_reference.py` is the offline half: 33 biomarkers with LOINC, reference range, its
  cited source, and why it matters for building a physique. **The lab's own printed range
  always wins** over this table. Adding a marker means adding its synonyms too, or Spanish lab
  reports will split its time series across several codes.
  `normalizar_codigo`'s partial match needs **word boundaries and a 3-char minimum**
  (`LONGITUD_MINIMA_ALIAS_PARCIAL`). Plain substring matching turned a Fitdays scale report
  into fake blood work: "Masa Esquelética" → calcium (the *ca* in esqueléti-**ca**), "Cantidad
  de proteína" → sodium (the *na* in proteí-**na**), kg stored as if they were mg/dL, and the
  coach then discussed a calcium deficit nobody measured. Chemical symbols only match as a
  whole name.

**Pulso always reads that profile.** `ai_profile.py` fetches `GET /ai-context/:userId` (NestJS
aggregates identity + profile + composition + physique + clinical) and `chat_engine.run_chat`
prepends it to the system prompt in **every** mode — not a tool, because as a tool the model
wouldn't call it when recommending macros or editing a routine. Keep this block small: measured
at ~700 tokens with a full profile, and Groq's 8000 TPM counts input + reserved output, so it
competes directly with the routine JSON.

Two things about that block are load-bearing:
- **Composition goes first and is labelled the main datum**, and the closing paragraph spells
  out the hierarchy (measured composition > visual estimate > blood). Buried at the end, the
  model reasoned about an eyeballed body-fat % while holding a DEXA. For the same reason the
  photo section drops its estimated %/lean mass when a real measurement exists — otherwise the
  model averages the two.
- **`completitud` has two levels.** `faltantes` is only weight and height, and *blocks*: without
  them there's no calorie to compute. Everything else (composition, sex, age, photos, blood) is
  `recomendados` and must not block the chat — a half-filled profile that answers beats a
  complete one the user never fills in. With minimums but no composition, the block still
  forbids assuming body-fat % or lean mass.

**Nutrition targets aren't fixed once set.** `ajustar_metas_nutricionales` (nutrition mode's tool set,
`chat_tools.py`) lets Pulso rewrite `meta_kcal`/`meta_proteinas_g`/`meta_carbohidratos_g`/`meta_grasas_g`
on its own initiative whenever newer data (a fresh composition measurement, a stated goal change)
makes the stored targets stale — it's not gated behind the user asking first, unlike routine changes
in `revisor_rutina`. It POSTs to `/user-profiles` (upsert), not PUT, so it also works for a user with
no profile row yet. The system prompt requires Pulso to always say what changed and why in the same
turn — silently rewriting a number the user's diary is measured against would be confusing.

**Never use `simple-array` for AI-written sentences.** TypeORM serializes it to one comma-joined
`text` column, so any element containing a comma comes back split into several. Confirmed in
production data. Use `jsonb` (see migration `1787000000001-ArraysTextoLibreAJsonb`). It's still
fine for enum-ish word lists (`angulos_fotos`, `grupos_musculares_*`).

**Registration and the profile screen.** Sign-up is `register_flow_page.dart`, five steps:
account → weight/height/birthdate → recommended extras → Health Connect → tour → create. **The
account is created at the last step, not the first** — abandoning halfway leaves nothing behind.
The trade-off is that a duplicate email only surfaces at the end. `auth_card.dart` is login-only;
it pushes the flow.

`profile_setup_page.dart` (reached from the Home avatar) is the one place to edit everything that
isn't a measurement, and it *reuses the same fields* via
`features/profile/presentation/widgets/profile_fields.dart` — keep the option lists there, in
`ProfileOptions`, or sign-up and editing drift apart. Body composition shows read-only with a link
to Clinic; the progress ring is driven by `completitud.recomendados` from `/ai-context/:userId`,
matched **by the exact backend strings** (`_recomendados` in that file). Change a string in
`ai_context.service.ts` and the checkmark silently stops lighting up.

`PUT /users/:id` takes `UpdateUserDto`, which deliberately **omits the password**: `update()`
writes the DTO straight to the table, so a password arriving here would be stored unhashed next
to the bcrypt hashes from registration.

**Clinic adds data, Salud (Home tab) shows it.** `clinic_import_page.dart` is only entry points
(register composition, upload a document, manual blood values) — it has no history view. The combined
history (composition measurements + blood reports, with delete) is
`features/health/presentation/widgets/health_records_history.dart`, embedded in Home's Salud tab
alongside real composition/posture cards sourced from `/dexa-scans` and `/body-analysis`. Don't add a
second history view inside Clinic; extend the shared widget instead.

**Auth: JWT global, con comprobación de pertenencia.** `JwtAuthGuard` está
registrada como `APP_GUARD`, así que **una ruta nueva nace protegida** — sin token
devuelve 401. Solo `@Public()` la exime (registro, login, google-login, y nada más).
La guarda hace además lo que ningún servicio hacía de forma consistente: compara el
`userId` que venga en params/query/body —y el `:id` de `/users/:id`, que se llama
distinto y es el que más se olvida— contra el `sub` del token, y devuelve 403 si no
coinciden. Un token válido no basta para leer los datos de otro.

El servicio Python no tiene el token del usuario (NestJS solo le pasa el `user_id`),
así que se identifica con `INTERNAL_API_KEY` y se salta la comprobación de
pertenencia. En el despliegue de una sola VM (`docker-compose.yml`, ver
[DESPLIEGUE.md](DESPLIEGUE.md)) eso es seguro porque su puerto no se publica
(`expose`, no `ports`; igual con Postgres). Si Python vive en un host propio
en vez de la red interna de Docker (ver [DESPLIEGUE_HIBRIDO.md](DESPLIEGUE_HIBRIDO.md),
p. ej. Hugging Face Spaces), lo que lo protege es que `main.py` exige la
misma `INTERNAL_API_KEY` como header en todas sus rutas salvo `/health`
(middleware `verificar_clave_interna`) — sin eso, publicar su puerto
convierte la clave en una llave maestra para cualquiera que la vea.

`JWT_SECRET` no tiene valor por defecto a propósito: si falta, el arranque falla en
vez de quedarse firmando tokens con un secreto conocido.

**Despliegue:** ver [DESPLIEGUE.md](DESPLIEGUE.md). Docker Compose con Caddy
delante (HTTPS obligatorio: Android bloquea el HTTP en claro). La URL del backend
en Flutter se fija al compilar con `--dart-define=API_BASE_URL=...`; sin él, el
default depende de `kReleaseMode` — release apunta al backend desplegado y debug a
la IP de la LAN. El reparto es deliberado: un default equivocado en release falla en
el móvil de quien instala la APK, sin logs y lejos; en debug falla en tu portátil.
**El manifest de release necesita `INTERNET` escrito a mano.** Flutter solo lo declara
en `android/app/src/debug/` y `profile/`, que no entran en la APK final: en debug todo
va y en release falla cada petición, así que el fallo aparece justo al instalar la APK,
lejos y sin logs. Igual de invisible: **nada de lo que hay antes de `runApp` puede
lanzar**. Sin primer frame el sistema deja a la vista el fondo de `NormalTheme`
(`values-night/styles.xml` → `Theme.Black.NoTitleBar`), que es negro liso — idéntico a
un móvil que no arranca. Por eso `main.dart` envuelve cada paso de inicialización y
sustituye `ErrorWidget.builder`, que en release es un rectángulo gris sin texto.

`Image.network` no pasa por `ApiService._request`, así
que necesita `ApiService.imageHeaders` a mano o las fotos dan 401. Las migraciones
en producción van con `migration:run:prod` (contra `dist/`): `ts-node` es
devDependency y no está en la imagen final.

**Ownership pattern (pre-JWT, aún vigente en los servicios).** Además de la guarda global, los
servicios siguen recibiendo el `userId` explícito como
query/body param on every request (e.g. `GET /routine/user/:userId`, `PATCH /routine/:id?userId=...`) and
services verify ownership by comparing it against the row's `userId` before mutating. When adding a new
user-scoped endpoint, follow this exact pattern (explicit `userId` param + ownership check in the
service), matching `nutrition`, `training_sessions`, and `routine`. Routines were global/unscoped until a
recent fix added `userId` + ownership checks — don't reintroduce an entity that's missing `userId`.

**Health Connect (Flutter):** `lib/src/services/health_service.dart` handles Health Connect,
`smartwatch_service.dart` handles Mi Fitness-specific sync, `ble_service.dart` is raw Bluetooth. Known
sharp edges:
- Xiaomi/Redmi devices via Mi Fitness write only granular sleep stages (`SLEEP_DEEP`, `SLEEP_REM`,
  `SLEEP_LIGHT`, `SLEEP_AWAKE`), never generic `SLEEP_ASLEEP`/`SLEEP_IN_BED`. Total sleep = sum of
  deep+rem+light (stages are sequential, non-overlapping).
- `READ_HEALTH_DATA_HISTORY` must be declared in `AndroidManifest.xml` *and*
  `requestHealthDataHistoryAuthorization()` called in code — either alone is not enough.
- The `androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE` intent-filter must be on `.MainActivity`
  specifically, not any other activity.
- If workout records come back empty, check in this order: `WORKOUT_ROUTE` missing from `_types`,
  `hasPermissions` false-positive short-circuiting `requestAuthorization`, missing rationale intent-filter.
- Deduping sleep records must collapse **per overlapping cluster**, never the whole list to one
  record. Mi Fitness resyncs the whole night on every watch sync, leaving several overlapping copies
  per stage — but the stages themselves (`SLEEP_DEEP`/`SLEEP_REM`/`SLEEP_LIGHT`) are legitimately
  several *non-overlapping* segments spread across the night. `_collapseOverlapping()` sorts by
  `dateFrom` and merges only records whose windows actually intersect, keeping the latest `dateTo` per
  cluster. An earlier version (`_latestRecordOnly`) kept a single record for the *entire* list — it
  fixed the resync duplication but silently broke sleep detection, since it discarded almost every
  real stage segment and left detected sleep at a few minutes.

**Training sessions carry real metrics, not just the plan.** `TrainingSession` (`Sesiones_Entrenamiento`)
has `duracion_minutos`, `calorias_kcal`, `frecuencia_cardiaca_media/max`, `distancia_km`, and `origen`
(`manual` narrated in chat, `app` tracked live via the BLE band in `workout_session_page.dart`,
`health_connect` synced from a device-recorded workout). `origen_id` (the workout's `dateFrom` ISO
string, for `health_connect`) is what makes `HealthService.syncWorkoutsToBackend()` idempotent — it
runs on every Inicio load and skips whatever's already synced. `GET /training-sessions/:id/analysis`
compares a session's metrics against the mean of *all* the user's completed sessions regardless of
type or origin — trying to segment "cardio vs. cardio" would leave that mean computed over 1-2 rows
almost always.

**Mapa muscular (pestaña Entrenar).** `GET /training-sessions/user/:userId/muscle-load?dias=N`
reparte las sesiones **completadas** del rango entre 16 grupos musculares y devuelve volumen,
intensidad y fatiga de una vez; la tarjeta (`routine/presentation/widgets/muscle_heatmap_card.dart`)
pinta las vistas anterior y posterior con la rampa de esfuerzo ya existente. Puntos que no se ven
en el código:
- **El vocabulario de músculos está escrito dos veces**: `MUSCULOS` en
  `training_sessions/muscle_map.ts` y las claves de `body_map_paths.dart`. No hay nada que las
  ate — un id que solo exista en un lado se pinta siempre en gris, sin error.
- **El reparto va en tres escalones**: nombre del ejercicio (patrones) → `grupo_muscular` del
  catálogo → `tipo_entrenamiento`. Los patrones casan por **palabra completa** sobre el nombre sin
  tildes, y gana el que case con más claves: así "curl femoral" son isquios y no bíceps. Con
  `includes` a secas volvería el problema de `clinical_reference.normalizar_codigo`.
- **Una sesión rastreada en vivo guarda una fila por serie** (`serie: 3`), no `series: 4`. Detectar
  "no declara series" mirando solo `series > 1` daba por estimable una sesión de 12 series contadas
  y la sustituía por las 7,5 que salen de su duración — de ahí `declaraSeries()`, que acepta las dos
  formas.
- **El color se normaliza contra el volumen semanal recomendado** (`SERIES_SEMANA`, Schoenfeld),
  no contra el máximo del propio usuario: escalar contra uno mismo pinta igual una semana floja
  y una brutal, porque el máximo baja con ella.
- **La fatiga usa vida media por músculo** (`VIDA_MEDIA_HORAS`, 24-60 h). Es lo único que la
  distingue del volumen: sin decaimiento serían la misma columna con otro nombre.
- **`intensidad` es nullable y viaja con `cobertura_intensidad`.** Solo hay señal de esfuerzo si la
  sesión trae RIR (rastreada en vivo) o FC media + fecha de nacimiento. Sin señal se pinta gris, no
  frío: quien no lleva pulsómetro no ha entrenado suave.

**Groq's 8000 TPM is a hard ceiling on the whole conversation.** It counts input +
`max_completion_tokens` *reserved* in the same request, so an oversized request is rejected with
413 before generating anything. `_ajustar_a_presupuesto()` (`chat_engine.py`) is what keeps that
from happening: it trims the oldest droppable messages until the request fits, and only then picks
the completion budget. **Never reintroduce a fixed floor on `max_completion_tokens`** — the previous
version did `max(1200, ...)`, which mathematically guarantees a 413 once input passes ~6800 tokens.
That's what broke routine creation/review, where the tool-call argument carries the whole plan.
Three things feed that budget and each has its own cap:
- The app sends the **entire** chat history every turn. `_history_to_groq_messages` keeps only the
  last `MAX_TURNOS_HISTORIAL` turns, truncated — routine replies are long by design (the prompt
  demands a per-exercise justification), so an uncapped history alone blows the budget.
- Tool results are truncated to `MAX_CHARS_RESULTADO_TOOL` on the way *back to the model only* —
  `actions_taken` still carries the full result to the app, which needs it to render.
- The tools themselves return slimmed payloads: `buscar_ejercicios_catalogo` drops UUIDs and
  descriptions, `obtener_rutina_activa` drops per-day/per-exercise UUIDs and timestamps (keeping
  `routine_id`, which `aplicar_cambios_rutina` needs). Measured: 878→417 and 1581→829 tokens.
Anything added to `BASE_GUIDELINES` or a system prompt is paid on *every* request in every mode —
check it isn't already said by `ai_profile.bloque_prompt`, which is appended right after.

**Camera needs a `<queries>` entry, not a permission.** `AndroidManifest.xml` must declare the
`android.media.action.IMAGE_CAPTURE` intent under `<queries>`. Android 11+ package-visibility
filtering otherwise hides every camera app, `startActivityForResult` throws
`ActivityNotFoundException`, and image_picker reports `no_available_camera` — gallery keeps working,
which makes it look like a permissions problem when it isn't. `image_picker_android` does **not**
declare it in its own manifest. Do not add `android.permission.CAMERA`: declaring it would force a
runtime permission request the plugin doesn't otherwise need.

**AI service:** Two LLM providers, split strictly by mode — never mixed within a turn. Image modes
(`nutricion`, `analisis_fisico`) always go to Gemini (`google-genai`, default model
`gemini-3.5-flash-lite`); the other four text modes always go to Groq (`openai/gpt-oss-120b`). No
Ollama/local model anywhere. When touching `chat_engine.py`, never default Groq to
`llama-3.3-70b-versatile` or `qwen/qwen3-32b` — both deprecated; `openai/gpt-oss-120b` is the current
recommended replacement. `analyze_failure()` (`skills.py`) is a separate deterministic heuristic
(Python `statistics` module on heart-rate curves), not AI-based.

## Google Sign-In

`google_sign_in` is a dependency but OAuth client IDs (Web/Android/iOS) require manual setup in Google
Cloud Console — this cannot be automated by an agent. Android additionally needs a SHA-1 fingerprint from
`cd android && ./gradlew signingReport`. If a task involves Sign-In, flag the manual step rather than
trying to complete it in code.
