---
title: Personal TrAIner IA
emoji: 🏋️
colorFrom: blue
colorTo: green
sdk: docker
app_port: 8000
pinned: false
---

Servicio FastAPI de IA de Personal TrAIner (coaching, análisis clínico/físico,
nutrición). No es un Space de uso público: solo lo llama el backend NestJS del
proyecto, autenticado con `INTERNAL_API_KEY` (ver `main.py` y `nest_client.py`).

Variables de entorno necesarias: copia `.env.example` a `.env` en el propio
panel de "Settings → Repository secrets" del Space (nunca lo subas al repo).
