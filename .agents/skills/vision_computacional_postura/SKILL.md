---
name: vision_computacional_postura
description: Reglas para el análisis físico, estimación de pose mediante CNNs y recuperación de mallas (SAM 3D).
---

# Análisis Físico y Postural (Visión Computacional)

- **Migración a Fotogrametría:** Evita depender de métricas heurísticas imprecisas. Utiliza CNNs para estimación de pose precisa y SAM 3D para la recuperación volumétrica de mallas.
- **Deducciones Volumétricas:** El sistema de IA debe ser capaz de deducir distribuciones de tejido graso (visceral y periférico) a partir de la malla 3D, persiguiendo resultados comparables a validaciones clínicas (DXA).
- **Privacidad Local:** El procesamiento de las fotografías para generar los tensores y características debe realizarse, siempre que sea posible, en el hardware neuronal periférico del móvil. El objetivo es preservar la privacidad del paciente enviando metadatos estructurados al backend, no imágenes crudas.
