# Desplegar Personal TrAIner en Hugging Face Spaces + Koyeb + Neon

Alternativa a [DESPLIEGUE.md](DESPLIEGUE.md) (una sola VM en Oracle): aquí cada
pieza vive en un proveedor gratuito distinto. Sin servidor propio que
mantener, pero con un cambio de arquitectura real: **el servicio Python deja
de vivir en una red privada y pasa a tener una URL pública**. Eso rompía un
supuesto de seguridad que estaba escrito en el propio código (`nest_client.py`,
`jwt-auth.guard.ts`): sin arreglarlo, cualquiera que encontrara la URL de
Python podría leer o escribir los datos de cualquier usuario con solo saber
su `user_id`. **Ya está arreglado** (commit de esta sesión): NestJS ahora
manda un header `X-Internal-Key` en cada llamada a Python, y Python rechaza
con 401 cualquier petición a `/api/ia/*` o `/ai/*` que no lo traiga — solo
`/health` queda abierto, para el monitor de la sección 4.

Piezas: **Hugging Face Spaces** (Python/IA, Docker) + **Koyeb** (NestJS) +
**Neon** (Postgres) + **UptimeRobot/cron-job.org** (evitar cold start).

---

## 0. Orden recomendado

Neon primero (Koyeb necesita sus credenciales) → Hugging Face (para tener su
URL) → Koyeb (necesita la URL de HF) → pegar la URL de Koyeb de vuelta en el
secreto de HF → monitores → APK. Los dos servicios se necesitan mutuamente
(cada uno llama al otro), así que hay una vuelta atrás inevitable en el paso 3.

---

## 1. Neon (PostgreSQL)

1. Cuenta gratis en [neon.tech](https://neon.tech), **Create project**.
2. El dashboard te da una cadena `postgresql://usuario:contraseña@host/basededatos?sslmode=require`.
   Guárdala — de ahí salen `DB_HOST`, `DB_USERNAME`, `DB_PASSWORD`, `DB_DATABASE`
   (el puerto es 5432).
3. Free tier: 500 MB. Para este proyecto (sin fotos/PDFs en la propia tabla,
   esos van aparte) sobra de largo para empezar.

No hace falta crear tablas a mano: las migraciones (`npm run migration:run:prod`)
se corren una vez desde tu PC apuntando a Neon, en el paso 3.

---

## 2. Hugging Face Spaces (FastAPI / IA)

1. Cuenta en [huggingface.co](https://huggingface.co) → **New Space**.
2. **SDK: Docker**. Visibilidad: **Private** (no necesita ser público — solo
   le habla NestJS — y así no queda listado ni indexado).
3. La plantilla vacía trae su propio `README.md`/`Dockerfile`: se sustituyen
   por los de `Backend/Python/` (el `README.md` ya tiene el frontmatter que
   pide HF — `sdk: docker`, `app_port: 8000` — y el `Dockerfile` ya expone
   8000, no hace falta tocar ninguno de los dos).
4. Tu Space tiene una URL fija y predecible desde que lo creas, aunque el
   contenido aún esté vacío: `https://<tu-usuario>-<nombre-space>.hf.space`.
   Apúntala — la necesitas para el paso 3.
5. En **Settings → Repository secrets** del Space, añade (mismos valores que
   tu `.env` local de `Backend/Python`, ver `.env.example`):
   - `GEMINI_API_KEY`, `GROQ_API_KEY`
   - `NEST_BASE_URL` → la URL de Koyeb (paso 3 — vuelve aquí a rellenarlo
     cuando la tengas)
   - `INTERNAL_API_KEY` → genera una con `openssl rand -base64 32`. **Tiene
     que ser idéntica** a la que pongas en Koyeb.
   - El resto de `.env.example` (USDA/OpenFoodFacts/etc.) si las usas.
6. El **hardware gratuito** (2 vCPU / 16 GB) es el que ya viene seleccionado
   por defecto al crear un Space Docker — no confundir con los tiers de pago
   (GPU), que no hacen falta aquí.

---

## 3. Koyeb (NestJS)

1. Cuenta en [koyeb.com](https://www.koyeb.com), conecta tu cuenta de GitHub
   cuando lo pida (autoriza la Koyeb GitHub App sobre este repo).
2. **Create Service → GitHub** → selecciona el repo. Como es un monorepo:
   - **Work directory / Dockerfile path**: `Backend/Nestjs`
   - Build: Dockerfile (Koyeb lo detecta solo al fijar el work directory)
3. Variables de entorno (Koyeb las llama "Environment variables" en el
   formulario del servicio):
   - `DB_HOST`, `DB_PORT=5432`, `DB_USERNAME`, `DB_PASSWORD`, `DB_DATABASE` → de Neon
   - `DB_SSL=true` → **obligatorio** contra Neon, si no la conexión falla
   - `JWT_SECRET` → `openssl rand -base64 48`
   - `JWT_EXPIRES_IN=30d`
   - `INTERNAL_API_KEY` → la misma que pusiste en el Space de HF
   - `AI_PYTHON_URL` → la URL del Space del paso 2
   - No hace falta fijar `PORT`: Koyeb lo inyecta solo y `main.ts` ya lo lee
     de `process.env.PORT`.
4. Free tier: 512 MB — de sobra, NestJS no carga MediaPipe (eso es cosa de
   Python).
5. Al desplegar, Koyeb te da una URL `https://<algo>.koyeb.app`. **Vuelve al
   paso 2.5 y pon esa URL como `NEST_BASE_URL` en los secretos del Space.**

### ¿Y si prefieres Render en vez de Koyeb?

Mismos datos, formulario equivalente: **New → Web Service**, conecta el repo,
**Root Directory: `Backend/Nestjs`**, Render detecta el Dockerfile solo. El
resto (variables de entorno, `DB_SSL=true`, la URL resultante) es idéntico.

---

## 4. Migraciones (una vez, desde tu PC)

Con las credenciales de Neon en `Backend/Nestjs/.env` (`DB_SSL=true` incluido):

```bash
cd Backend/Nestjs
npm run migration:run:prod
```

---

## 5. Evitar el cold start

Free tier de Koyeb/Render *y* de Hugging Face Spaces suspenden el contenedor
tras un rato sin tráfico — el primer request tras eso tarda mucho (arranque
en frío) o directamente falla si la app tarda demasiado en levantar.

En [uptimerobot.com](https://uptimerobot.com) o [cron-job.org](https://cron-job.org)
(gratis, sin tarjeta), crea dos monitores HTTP GET cada 10 minutos:
- `https://<tu-app>.koyeb.app/health`
- `https://<tu-usuario>-<space>.hf.space/health`

Ambos ya existen y son públicos a propósito (ver el aviso del principio de
este documento) — no necesitan cabecera ni autenticación.

---

## 6. Compilar la app

Igual que en el otro despliegue, pero apuntando a la URL de Koyeb:

```bash
cd Frontend/personaltrainer
flutter build apk --release --dart-define=API_BASE_URL=https://<tu-app>.koyeb.app
```

---

## Si algo falla

| Síntoma | Causa habitual |
|---|---|
| NestJS no arranca / error de conexión a BD | Falta `DB_SSL=true`, o la cadena de Neon cambió (revisa el dashboard) |
| Python responde 401 a todo | `INTERNAL_API_KEY` no coincide entre el Space y Koyeb — tiene que ser carácter por carácter la misma |
| La primera petición del día tarda ~30-60s | Cold start — confirma que los monitores de UptimeRobot/cron-job.org están activos y en verde |
| El Space de HF no arranca | Revisa los "Logs" del Space — el error más común es una var de entorno que falta (`GEMINI_API_KEY`/`GROQ_API_KEY`) |
| `docker compose`/Oracle y esto a la vez | No hay conflicto: son despliegues independientes, cada uno con su propio dominio/URL. La app solo habla con la que compiles en `API_BASE_URL` |
