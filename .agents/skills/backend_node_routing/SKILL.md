---
name: backend_node_routing
description: Reglas para el desarrollo del backend de enrutamiento y orquestación con Node.js y TypeScript.
---

# Desarrollo Backend (Orquestación con Node.js / TypeScript)

- **Arquitectura Basada en Eventos:** Aprovecha al máximo la naturaleza asíncrona de Node.js. Asegura que los flujos de datos intensivos (streaming continuo) no bloqueen el I/O.
- **Tipado Fuerte:** Usa TypeScript rigurosamente para modelar las cargas útiles de eventos y garantizar la integridad de los datos entre microservicios.
- **Protocolos de Streaming:** Implementa gestores eficientes para mantener conexiones de WebSockets (para interacciones en tiempo real con la IA) y clientes MQTT para la ingesta de telemetría de dispositivos móviles/wearables.
- **Microservicios:** Define fronteras claras de delegación; Node.js debe manejar el enrutamiento y la alta concurrencia, pasando las cargas de cálculo pesado al motor Python de IA.
