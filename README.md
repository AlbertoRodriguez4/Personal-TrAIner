# Personal TrAIner

Entrenador personal con IA para Android: crea rutinas, interpreta analíticas y
composición corporal, registra comidas y lee tu sueño y tus entrenamientos
directamente del reloj.

No es un chatbot con un prompt bonito. **Pulso**, el coach, tiene acceso real a
tus datos: lee tu última medición de composición corporal, tus biomarcadores y
tus sesiones, y puede escribir en la base de datos — crear una rutina, ajustar
tus macros o registrar una comida — a través de un conjunto de herramientas
acotado por modo.

---

## Qué hace

| Módulo | Qué resuelve |
|---|---|
| **Composición corporal** | DEXA, bioimpedancia o báscula. Sube el informe y se extrae solo; los campos que faltan se derivan (IMC, masa grasa, masa magra, FFMI) |
| **Analítica de sangre** | PDF o foto → biomarcadores normalizados y contrastados contra MedlinePlus (NIH) y rangos de referencia citados |
| **Rutinas** | Creación y revisión con justificación por ejercicio, apoyada en un catálogo real |
| **Nutrición** | Foto del plato o entrada manual, con macros de Open Food Facts / USDA / Edamam |
| **Entrenamientos** | Sincronizados de Health Connect o medidos en vivo con banda BLE, con comparación contra tu media |
| **Sueño y recuperación** | Fases de sueño, HRV y FC en reposo desde Health Connect |
| **Análisis del físico** | Fotos por ángulo → geometría de pose (MediaPipe) + normas ACE/OMS/ISSN |
| **Recordatorios** | Avisos locales de entreno (solo los días de tu rutina), pesada semanal y cierre del diario de comidas |

### Dos decisiones de diseño que explican el resto

**La composición corporal manda.** Es el único dato *medido* — las fotos estiman
y la sangre habla de otra cosa. De ahí salen las calorías, los macros y la
decisión entre superávit y recomposición, así que va la primera en el contexto
que lee la IA, etiquetada como dato principal, y el prompt fija la jerarquía
explícitamente. Enterrada al final, el modelo razonaba sobre un porcentaje de
grasa calculado a ojo teniendo un DEXA delante.

**Lo mínimo es peso y altura.** Todo lo demás es opcional. Un perfil a medias
que responde vale más que uno completo que el usuario nunca rellena, así que
solo esos dos campos bloquean; el resto se pide como recomendación.

---

## Arquitectura

```
┌─────────────────┐     HTTPS      ┌──────────────────┐
│  Flutter        │ ─────────────► │  NestJS          │
│  (Android)      │  JWT           │  API + Postgres  │
└─────────────────┘                └────────┬─────────┘
        │                                   │ ▲
        │ Health Connect                    ▼ │ clave interna
        │ BLE (banda FC)             ┌──────────────────┐
        ▼                            │  FastAPI         │
   ┌──────────┐                      │  Gemini + Groq   │
   │ Reloj    │                      └──────────────────┘
   └──────────┘
```

- **`Frontend/personaltrainer/`** — App Flutter. Health Connect, Bluetooth para
  la banda de frecuencia cardíaca, y toda la UI.
- **`Backend/Nestjs/`** — API REST con TypeORM sobre PostgreSQL, modular por
  dominio. Es la única pieza expuesta a internet.
- **`Backend/Python/`** — Servicio de IA. Orquesta Gemini (modos con imagen) y
  Groq (modos de texto), y llama de vuelta a NestJS para leer y escribir datos
  del usuario.

El servicio de IA **nunca se expone**: vive en la red interna y solo NestJS le
habla. Se identifica con una clave interna que le permite operar en nombre del
usuario, porque recibe el `user_id` pero no su token.

---

## Puesta en marcha (desarrollo)

Necesitas Node 18+, Python 3.10+, el SDK de Flutter y PostgreSQL corriendo.

```bash
git clone https://github.com/AlbertoRodriguez4/Personal-TrAIner.git
cd Personal-TrAIner
```

**1. Variables de entorno.** Copia las plantillas y rellénalas:

```bash
cp Backend/Nestjs/.env.example Backend/Nestjs/.env
cp Backend/Python/.env.example Backend/Python/.env
```

Genera los secretos de autenticación (`JWT_SECRET` e `INTERNAL_API_KEY` tienen
que coincidir entre los dos `.env`):

```bash
openssl rand -base64 48   # JWT_SECRET
openssl rand -base64 32   # INTERNAL_API_KEY
```

Necesitas además una clave de [Gemini](https://aistudio.google.com/apikey) y
otra de [Groq](https://console.groq.com/keys); las dos tienen tier gratuito.

**2. Base de datos.**

```bash
cd Backend/Nestjs && npm install && npm run migration:run
```

**3. Arrancar los tres servicios.** En Windows, `iniciar_proyecto.bat` los abre
de golpe (ver [README_EJECUCION.md](README_EJECUCION.md)). A mano:

```bash
cd Backend/Python  && pip install -r requirements.txt && uvicorn main:app --reload --port 8000
cd Backend/Nestjs  && npm run start:dev
cd Frontend/personaltrainer && flutter run
```

> La app apunta por defecto a una IP de red local. Para compilarla contra otro
> backend: `flutter build apk --release --dart-define=API_BASE_URL=https://tu-servidor`

---

## Despliegue

Docker Compose con Caddy delante (HTTPS automático, obligatorio porque Android
bloquea el tráfico en claro). Guía completa en **[DESPLIEGUE.md](DESPLIEGUE.md)**.

```bash
cp .env.produccion.example .env   # y rellenarlo
docker compose up -d --build
docker compose exec api npm run migration:run:prod
```

---

## Seguridad

- Autenticación **JWT** con guarda global: una ruta nueva nace protegida.
- La guarda comprueba además **pertenencia**: un token válido no basta, el
  `userId` de la petición tiene que ser el del token o devuelve 403.
- Contraseñas con bcrypt. El DTO de edición de usuario **excluye** la contraseña
  a propósito, para que no pueda escribirse sin hashear.
- Ni PostgreSQL ni el servicio de IA publican puerto fuera de la red interna.

Son datos de salud: si vas a desplegarlo, genera secretos nuevos y no reutilices
los de desarrollo.

---

## Tests

```bash
cd Frontend/personaltrainer && flutter test && flutter analyze
cd Backend/Nestjs && npm run build
```

---

## Documentación

| Documento | Contenido |
|---|---|
| [DESPLIEGUE.md](DESPLIEGUE.md) | Desplegar en un servidor propio, paso a paso |
| [README_EJECUCION.md](README_EJECUCION.md) | Arrancar los tres servicios en Windows |
| [CLAUDE.md](CLAUDE.md) | Arquitectura, decisiones de diseño y trampas conocidas |
| [AGENTS.md](AGENTS.md) | Convenciones para trabajar en el repo |

---

## Estado

Proyecto personal en desarrollo activo. La app se compila e instala como APK;
no está publicada en Play Store.

El inicio de sesión con Google requiere configurar credenciales OAuth propias en
Google Cloud Console (client IDs y huella SHA-1); sin eso, el registro por
correo funciona con normalidad.
