# Desplegar Personal TrAIner en Render (un solo servicio)

El backend entero —NestJS y el servicio Python de IA— va en **una sola imagen**
(`Dockerfile` en la raíz), con Postgres fuera, en Neon.

---

## Por qué uno y no dos

Un contenedor por proceso es lo correcto casi siempre. Aquí no, y por razones
concretas del plan Free de Render:

| Con dos servicios | Con uno |
|---|---|
| NestJS → Python sale a internet y vuelve por el proxy: **el plan Free puede *enviar* peticiones por la red privada, pero no *recibirlas***, así que no hay atajo interno. | Se hablan por `127.0.0.1`. No hay red de por medio. |
| El limitador del proxy va por IP de origen, y la IP de salida de Render **es compartida con otros clientes**: te comes 429 por tráfico que no es tuyo (de ahí los reintentos de `AiService.post`). | No hay proxy que limite nada. |
| Cada servicio **duerme por su cuenta a los 15 min**. El que despierta primero llama al otro dormido y se traga un arranque en frío de ~1 min dentro del turno del usuario. | Un solo arranque en frío, y los dos procesos suben juntos. |
| `INTERNAL_API_KEY` viaja por la red pública en cada llamada. | No sale del contenedor. Python escucha en `127.0.0.1`: desde fuera **no existe**. |
| **1440 h/mes** de instancia entre los dos, con 750 h gratis por workspace. | ~720 h/mes: entra en las 750. |

El despliegue en servidor propio (`docker-compose.yml` + Caddy, ver
[DESPLIEGUE.md](DESPLIEGUE.md)) sigue con los dos Dockerfile de siempre: ahí hay
red interna de verdad y separarlos no cuesta nada.

---

## 1. Crear el servicio

En Render: **New → Web Service** → tu repo.

| Campo | Valor |
|---|---|
| Language / Runtime | **Docker** |
| Root Directory | *(vacío — la raíz del repo)* |
| Dockerfile Path | `./Dockerfile` |
| Health Check Path | `/health` |

El *Root Directory* tiene que ser la raíz porque la imagen necesita
`Backend/Nestjs/` **y** `Backend/Python/` en el mismo contexto de build. El
`.dockerignore` de la raíz es el que evita que en ese contexto viajen también la
app Flutter, el mockup de Lovable y el índice de graft.

## 2. Variables de entorno

```
NODE_ENV=production
DB_HOST=<host de Neon>
DB_PORT=5432
DB_USERNAME=<usuario de Neon>
DB_PASSWORD=<password de Neon>
DB_DATABASE=<base de Neon>
JWT_SECRET=<openssl rand -base64 48>
JWT_EXPIRES_IN=30d
INTERNAL_API_KEY=<openssl rand -base64 32>
GEMINI_API_KEY=<...>
GROQ_API_KEY=<...>
GEMINI_MODEL=gemini-3.5-flash-lite
GEMINI_MODEL_FALLBACK=gemini-3.5-flash
GROQ_MODEL=openai/gpt-oss-120b
GROQ_TPM_LIMIT=8000
OPENFOODFACTS_USER_AGENT=PersonalTrAIner/1.0 (tu-email)
USDA_FDC_API_KEY=<...>
RAPIDAPI_KEY=<...>
OPENFDA_API_KEY=<...>
```

**Las cinco últimas no son opcionales de verdad**, aunque el contenedor arranque
sin ellas. Ninguna revienta: degradan en silencio, que se diagnostica mucho peor
que un fallo.

| Si falta | Qué pasa |
|---|---|
| `GEMINI_MODEL_FALLBACK` | Al agotar la cuota de flash-lite el usuario recibe un 503, en vez del segundo intento contra el modelo de respaldo (`gemini_client.generate`). |
| `RAPIDAPI_KEY` | Edamam se desactiva y `nutricion` pierde el análisis de platos en texto libre. |
| `USDA_FDC_API_KEY` | Cae a `DEMO_KEY`, con un límite que se agota enseguida. |
| `OPENFDA_API_KEY` | Funciona, pero baja de 120.000 a 1.000 req/día. |
| `OPENFOODFACTS_USER_AGENT` | Manda `sin-contacto-configurado`, que es justo lo que la API pide no hacer. |

`AI_PYTHON_NUTRITION_PATH` sale en `Backend/Nestjs/.env.example` pero **el código
no la lee** en ningún sitio: es residuo, no la pongas.

El TLS contra Neon se activa solo mirando el host (`db-ssl.ts`); solo hace falta
`DB_SSL` si alguna vez hay que forzarlo a mano.

**`PORT` no se pone**: lo inyecta Render.

**Borra `AI_PYTHON_URL` y `NEST_BASE_URL` si las tenías.** El entrypoint las pisa
con las de loopback y avisa por el log si venían puestas — si se respetaran, la
llamada volvería a salir a internet y no habríamos arreglado nada.

**Si falta `INTERNAL_API_KEY` el contenedor no arranca**, a propósito: con ella
vacía, `main.py` responde 401 a todo menos `/health` y la app funcionaría entera
salvo la IA, que es el fallo más caro de diagnosticar.

## 3. Migraciones

**En el plan Free no hay Shell.** La pestaña *Shell* del panel es de instancias
de pago, así que el camino de "entrar al contenedor y ejecutar el comando" no
existe aquí. Y las migraciones no corren solas: `synchronize` está en `false` a
propósito (ver `data-source.ts`), porque dejar que TypeORM altere el esquema
solo, contra la base de datos de verdad, es la forma corta de perder una
columna.

La vía que funciona en Free es **correrlas desde tu máquina contra Neon**. La
base de datos es la misma; lo único que cambia es desde dónde se conecta.

Crea `Backend/Nestjs/.env` con las credenciales de Neon (las mismas cinco que
pusiste en el panel de Render — no hacen falta las claves de IA ni
`JWT_SECRET`, que el `data-source` no las lee):

```
DB_HOST=<host de Neon>
DB_PORT=5432
DB_USERNAME=<usuario de Neon>
DB_PASSWORD=<password de Neon>
DB_DATABASE=<base de datos de Neon>
```

No hace falta `DB_SSL`: `db-ssl.ts` activa TLS solo, por el host. Y ese `.env`
está en `.gitignore` — que no es un detalle menor en este repo, ver el aviso de
[DESPLIEGUE.md](DESPLIEGUE.md) sobre credenciales.

Y desde `Backend/Nestjs/`:

```bash
npm run migration:run
```

Ese script va contra `src/` con `ts-node`, que en local sí está (es
devDependency). El registro de migraciones vive en la propia base de datos, así
que lo que se aplique desde aquí queda aplicado para el servicio desplegado.

`migration:run:prod` es el equivalente dentro del contenedor, contra `dist/`,
para cuando haya Shell (plan de pago) o si algún día el `entrypoint` las lanza
al arrancar.

## 4. Comprobar que va

```bash
curl https://<tu-servicio>.onrender.com/health     # -> {"status":"ok"}
```

Y la mitad de Python, desde la *Shell* del servicio (desde fuera no se llega, que
es el punto). **Sin `curl`**: la imagen no lo lleva —ni `curl` ni `wget`— y en la
Shell de Render estás dentro del contenedor, así que el comando de toda la vida
falla con `curl: not found` y parece que la IA no responde cuando lo que falta es
la herramienta. Se usa el Python que ya está instalado:

```bash
python3 -c "import urllib.request;print(urllib.request.urlopen('http://127.0.0.1:8000/health',timeout=10).read().decode())"
```

```
{"status":"ok"}
```

Y en los logs del servicio, al arrancar, tienen que salir las dos mitades:

```
[entrypoint] IA en 127.0.0.1:8000 · API en 0.0.0.0:10000
🚀 Servidor corriendo en el puerto 10000
```

Si solo sale una, el contenedor se cae entero (es lo que hace el `wait -n` del
entrypoint) y Render lo reintenta: mira el log para ver cuál de las dos falló.

## 5. Borrar el servicio Python viejo

Cuando el unificado responda, **borra el servicio Python del panel**. Mientras
siga vivo consume horas de las 750 y, sobre todo, su URL pública sigue aceptando
peticiones de cualquiera que la conozca con la `INTERNAL_API_KEY` que ya estuvo
circulando por internet — rota esa clave al hacer el cambio.

## 6. Y en la app

`API_BASE_URL` no cambia si mantienes el servicio de NestJS: la URL pública sigue
siendo la suya. Si creas uno nuevo en vez de reconfigurar el que hay, recompila:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<tu-servicio>.onrender.com
```

---

## Probarla en local antes de subirla

Merece la pena: un fallo aquí se ve en 2 minutos, y en Render son 10 de build más
un despliegue fallido.

```bash
docker build -t personaltrainer-backend .
```

```bash
docker run --rm -p 3000:3000 --env-file .env.local personaltrainer-backend
```

En `.env.local` van las mismas variables del paso 2 (con las credenciales de Neon,
que la imagen no lleva base de datos dentro). Si el contenedor arranca y
`curl localhost:3000/health` contesta, el `docker exec ... curl
http://127.0.0.1:8000/health` de dentro confirma la otra mitad.

---

## La RAM: medida, no estimada

El plan Free son **512 MB y 0.1 CPU**. Medido sobre esta imagen ya construida,
con las dos mitades arrancadas:

| | |
|---|---|
| Contenedor en reposo, los dos procesos vivos | **~158 MB** (ya incluye OpenCV, que `pose_analysis.py` importa al arrancar) |
| Cargar el `PoseLandmarker` de MediaPipe y analizar una imagen | **+159 MB** |
| Pico esperado | **~320 MB de 512** |

Cabe, y con margen. El landmarker es un singleton (`_landmarker` en
`pose_analysis.py`), así que ese pico se paga una vez por arranque, no por foto.

Lo que sí aprieta es la **CPU: 0.1**. Un análisis de físico con MediaPipe va a
tardar. No es un fallo, es lentitud — pero los timeouts del cliente hay que
mirarlos con eso en mente.

Si algún día la memoria se queda corta (más dependencias, un modelo mayor), por
orden de coste:

1. Mover `import cv2` dentro de la función en `pose_analysis.py` (como ya está
   `import mediapipe`): baja el consumo en reposo, no el del pico.
2. Sacar MediaPipe de esta imagen y dejar el análisis de físico solo con Gemini,
   sin el preprocesado de geometría.
3. Subir de plan. Ojo: *Starter* (7 $/mes) da más CPU y quita el sueño, pero
   **sigue siendo 512 MB**; para más RAM hay que ir a *Standard*. Con la imagen
   unificada eso se paga una vez, no dos.
