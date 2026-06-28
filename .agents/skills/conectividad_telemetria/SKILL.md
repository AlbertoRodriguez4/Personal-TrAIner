---
name: conectividad_telemetria
description: Directrices sobre la comunicación, sincronización y telemetría de sensores usando BLE, MQTT y WebSockets.
---

# Telemetría y Conectividad

Este proyecto maneja múltiples capas de comunicación. Respeta las siguientes directrices dependiendo del contexto:

- **Bluetooth Low Energy (GATT):** Utilizado para sincronización permanente de pulseras en ámbito local. Minimiza la frecuencia de interrogación para conservar el ciclo de vida de la batería del wearable.
- **MQTT (Subida/Uplink):** Protocolo designado para envío robusto de métricas desde la app móvil hacia el backend. Debe tolerar inestabilidades de las redes celulares manteniendo bajo el overhead (paquetes ligeros).
- **WebSockets (Interacción IA):** Conducto Full-Duplex obligatorio para la comunicación entre el usuario y la IA conversacional. Debe garantizar muy baja latencia para permitir interrupciones naturales e inyección inmediata de telemetría visual.
