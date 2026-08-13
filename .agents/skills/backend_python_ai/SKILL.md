---
name: backend_python_ai
description: Reglas para el servicio FastAPI de IA — Gemini (google-genai) vía function calling, sin PyTorch/TensorFlow ni Ollama.
---

# Desarrollo del Servicio de IA (Python / FastAPI)

- **Framework real:** FastAPI + Pydantic para validar payloads entrantes desde
  NestJS (`main.py`, `schemas.py`).
- **El "motor de IA" es Gemini en la nube, no un modelo local:** no hay PyTorch,
  TensorFlow ni ninguna inferencia local — `requirements.txt` solo trae `fastapi,
  uvicorn[standard], pydantic, requests, google-genai, python-dotenv, httpx`. El
  chat agentic vive en `chat_engine.py` (cliente `google.genai`, modelo
  `gemini-3.5-flash`, loop de function calling de máx. 5 iteraciones) +
  `chat_tools.py` (tools/executors/prompts por modo). Las tools no calculan nada
  pesado localmente: llaman de vuelta a NestJS vía `nest_client.py` (un wrapper
  fino sobre `requests`).
- **Ollama ya no se usa en este servicio:** el análisis de comida por foto (antes
  `POST /api/ia/analizar-nutricion`, con Ollama local y `model: "gemma4:e4b"`
  hardcodeado) se migró al modo `nutricion` de `chat_engine.py`/Gemini — ver
  `razonamiento_nutricional_mllm/SKILL.md`. `analyze_failure()` (`skills.py`) es
  un algoritmo determinístico en Python puro (pendiente de la curva de FC del
  smartwatch) — no llama a ningún modelo ni a Ollama, pese a lo que digan
  `CLAUDE.md`/`AGENTS.md` (desactualizados en ese punto). No queda ninguna
  referencia a Ollama en `Backend/Python/*.py` — no la reintroduzcas.
- **Errores predecibles:** los endpoints envuelven las excepciones en
  `HTTPException` con código y detalle explícito (`ValueError` → 400, resto →
  500/502) — mantené ese patrón en vez de dejar que una excepción cruda llegue a
  NestJS.

## No implementado (no asumir que existe)

- No hay procesamiento científico/ML pesado (tensores, GPU, hilos separados para no
  bloquear el loop de eventos) — no hace falta esa gestión de memoria/hardware
  porque no hay ningún modelo corriendo localmente; todo el cómputo "IA" ocurre del
  lado de la API de Gemini.
