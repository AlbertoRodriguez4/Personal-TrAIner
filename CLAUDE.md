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

**Never use `simple-array` for AI-written sentences.** TypeORM serializes it to one comma-joined
`text` column, so any element containing a comma comes back split into several. Confirmed in
production data. Use `jsonb` (see migration `1787000000001-ArraysTextoLibreAJsonb`). It's still
fine for enum-ish word lists (`angulos_fotos`, `grupos_musculares_*`).

**No auth middleware yet.** There's no JWT guard / session layer — `userId` is passed explicitly as a
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
