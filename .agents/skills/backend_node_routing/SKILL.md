---
name: backend_node_routing
description: Reglas para el backend de orquestación NestJS — REST plano hacia el servicio Python de IA, sin WebSockets ni MQTT.
---

# Desarrollo Backend (NestJS / TypeScript)

- **Patrón real por módulo:** cada módulo en `Backend/Nestjs/src/modules/<modulo>/`
  sigue controller/service/entities/dto. El controller expone rutas planas
  (`@Controller`, `@Post`, `@Get`, `@Put`, `@Delete`); el service valida con
  `class-validator`/DTOs y persiste vía TypeORM/Postgres.
- **Cómo se llama a Python:** los módulos `ai/` y `telemetry/` (y cualquiera que
  necesite IA) llaman al servicio FastAPI con `fetch()` síncrono — un `POST` con
  JSON, esperar la respuesta, devolverla o mapear el error a una excepción Nest
  (`BadGatewayException` si `!response.ok`). Ver `ai.service.ts::chat` y
  `telemetry.service.ts::analyzeHrSet` como referencia exacta del patrón. La URL
  base sale de `ConfigService` (`AI_PYTHON_URL`, default `http://127.0.0.1:8000`).
- **Sin auth middleware:** no hay JWT/guard/sesión. `userId` viaja explícito como
  query/body param en cada endpoint user-scoped, y el service verifica ownership
  comparándolo contra la fila antes de mutar — replicá este patrón exacto en
  endpoints nuevos (ver también `nutrition`, `training_sessions`, `routine`).
- **Tipado:** usá TypeScript y DTOs con `class-validator` para las cargas
  entrantes — esto sí es una convención real y consistente en todo `src/modules/`.

## No implementado (no asumir que existe)

- No hay WebSocket gateway (`@nestjs/websockets`/`socket.io`) ni cliente/broker
  MQTT en `package.json` ni en el código — no hay "arquitectura basada en eventos"
  más allá del async/await normal de Node. Toda comunicación
  NestJS↔Python↔Flutter es petición/respuesta HTTP simple, sin canal persistente.
