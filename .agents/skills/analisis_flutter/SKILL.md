---
name: analisis_flutter
description: Reglas y contexto para cuando se esté escribiendo o analizando código de Flutter en el Frontend.
---

# Desarrollo Frontend (Flutter / Dart)

- **Arquitectura Multiplataforma:** El desarrollo es estricto en código único para iOS/Android para evitar los cuellos de botella de rendimiento típicos de los puentes JavaScript (React Native/Ionic).
- **Rendimiento Gráfico:** Utiliza el motor Impeller predeterminado. El renderizado a nivel de píxel optimizado para GPU es indispensable para garantizar la fluidez en el mapeo en vivo de avatares 3D y análisis de movimiento en tiempo real.
- **Widgets y UI:** Sigue las reglas de diseño para mantener 60/120 fps constantes en las animaciones críticas de la interfaz de entrenamiento. No uses constructores no constantes innecesariamente.
