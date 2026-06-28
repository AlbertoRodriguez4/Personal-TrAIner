---
name: backend_python_ai
description: Reglas para el desarrollo del motor de IA pesado y procesamiento médico en Python usando FastAPI.
---

# Desarrollo Motor de IA (Python / FastAPI)

- **Alto Rendimiento en API:** Usa FastAPI como marco principal aprovechando Pydantic para la validación estricta de esquemas de datos entrantes desde el orquestador Node.js.
- **Procesamiento Científico y ML:** Emplea integraciones nativas y optimizadas de frameworks como PyTorch o TensorFlow. Asegúrate de ejecutar operaciones pesadas (tensores) en hardware acelerado (GPU) si está disponible, o en hilos separados para no bloquear el loop de eventos de FastAPI.
- **Integración Segura:** Maneja las librerías científicas y médicas con cuidado de memoria, garantizando que el procesamiento masivo de datos no provoque fugas.
- **Respuestas Predictibles:** Estructura de forma coherente el flujo de errores cuando los modelos de Machine Learning devuelvan baja confianza en sus predicciones.
