---
name: analisis_series_temporales
description: "NO IMPLEMENTADO: no existe análisis predictivo de series temporales en este código. Ver skills.py::analyze_failure para lo único remotamente relacionado (heurística de una sola serie, no predictiva)."
---

# Análisis de Series Temporales — no implementado

No hay ningún modelo de series temporales, predicción ni forecasting en este
repositorio. `Backend/Python/requirements.txt` no incluye ninguna librería de
ML/estadística avanzada (no PyTorch, no TensorFlow, no statsmodels, no Prophet); no
existen Autoformer, Informer, LSTMs ni ninguna arquitectura similar en el código.

Si una tarea pide "detectar tendencias", "predecir sobreentrenamiento" o "analizar
series temporales de salud", tratala como una feature nueva a diseñar desde cero,
no como una extensión de algo existente. Antes de escribir código, confirmá con el
usuario el alcance real (¿qué datos hay disponibles? ¿en qué tabla? ¿con qué
horizonte temporal?), porque hoy no hay ninguna base de la que partir.

## Lo único remotamente relacionado (para contexto, no como enfoque a replicar)

`Backend/Python/skills.py::analyze_failure` (enchufado en `main.py` como
`POST /ai/analyze-set`, invocado desde
`Backend/Nestjs/src/modules/telemetry/service/telemetry.service.ts`) es una
heurística determinística con el módulo estándar `statistics` de Python — **no**
ML, **no** predictiva. Opera sobre una sola serie de pulsaciones (BPM) de un
ejercicio recién hecho: calcula la pendiente de los primeros 10s y el plateau del
último 20% para estimar RIR (repeticiones en reserva) y zona de intensidad. Es de
alcance "una serie, ahora mismo" — no longitudinal, no multi-día, no usa modelos
entrenados. Si algún día se construye una feature de tendencias reales, este es el
único precedente de "análisis de una serie" que existe hoy, y es de una escala
completamente distinta a la de un sistema predictivo.
