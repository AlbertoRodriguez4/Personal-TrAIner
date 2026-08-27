# Imagen única con el backend entero: NestJS (la parte pública) y el servicio
# Python de IA, en el mismo contenedor.
#
# Por qué junto y no dos servicios, que es lo "correcto" en Docker: porque en un
# hosting gratuito los dos servicios separados no pueden hablarse por la red
# interna (en Render, un web service del plan Free puede *enviar* peticiones
# privadas pero no *recibirlas*), así que la llamada NestJS → Python tiene que
# salir a internet y volver a entrar por el proxy. Eso trae tres problemas de
# golpe: el limitador del proxy va por IP de origen y en Render esa IP es
# compartida con otros clientes (429 por tráfico ajeno, ver AiService.post),
# cada servicio duerme por su cuenta a los 15 minutos —así que el primero en
# despertar llama a uno dormido y se come el arranque en frío entero dentro del
# turno del usuario— y la INTERNAL_API_KEY viaja por la red pública.
#
# Con los dos procesos aquí dentro, Python escucha SOLO en 127.0.0.1: no es que
# esté protegido desde fuera, es que no existe desde fuera.
#
# El despliegue en servidor propio (docker-compose.yml + Caddy) sigue usando los
# dos Dockerfile de siempre, que ahí sí hay red interna de verdad.

# ── Etapa 1: compilar NestJS ────────────────────────────────────────────────
FROM node:20-bookworm-slim AS build-api
WORKDIR /build
COPY Backend/Nestjs/package*.json ./
RUN npm ci
COPY Backend/Nestjs/ ./
RUN npm run build

# ── Etapa 2: imagen final ───────────────────────────────────────────────────
# Se parte de la de Node y se le añade Python, y no al revés, porque bookworm
# trae de serie Python 3.11 — que es justo la versión que pide mediapipe (ver
# Backend/Python/Dockerfile) — mientras que meter Node 20 en python:3.11-slim
# obliga a tirar de NodeSource.
FROM node:20-bookworm-slim AS runtime

ENV NODE_ENV=production \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# libgl1/libglib2.0-0 son de OpenCV, que mediapipe arrastra. Sin ellas la imagen
# construye bien y el proceso muere al importar, no al instalar.
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        python3-venv \
        libgl1 \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# venv y no `pip install` a pelo: Debian 12 marca su Python como
# externally-managed (PEP 668) y pip se niega a tocarlo.
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv "$VIRTUAL_ENV"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

WORKDIR /app

# Las dependencias primero y el código después, en los dos lenguajes: así un
# cambio en el código no invalida la caché del `pip install` (que compila
# mediapipe/numpy y es lo que se lleva la mayor parte del build).
COPY Backend/Python/requirements.txt ./ia/requirements.txt
RUN pip install --no-cache-dir -r ia/requirements.txt

COPY Backend/Nestjs/package*.json ./api/
RUN npm --prefix ./api ci --omit=dev && npm cache clean --force

COPY --from=build-api /build/dist ./api/dist
COPY Backend/Python/ ./ia/

# El modelo de pose se baja aquí y no en la primera petición: en un hosting que
# duerme el contenedor, esa descarga se repetiría en cada arranque en frío,
# dentro del turno de un usuario que ya está esperando con la foto hecha.
ADD https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/latest/pose_landmarker_lite.task \
    /app/ia/.mediapipe_models/pose_landmarker_lite.task
RUN chmod 644 /app/ia/.mediapipe_models/pose_landmarker_lite.task

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
# El `sed` no sobra: si el script llega con finales de línea CRLF (un checkout en
# Windows con el `core.autocrlf` que trae Git por defecto, o cualquier editor
# despistado), el contenedor muere con
# `/usr/bin/env: 'bash\r': No such file or directory` y sin una sola línea de log
# de la aplicación — parece que no arranca la imagen entera, no un script.
RUN sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh \
 && chmod +x /usr/local/bin/docker-entrypoint.sh

# PORT lo pisa el hosting (Render lo inyecta); IA_PORT no sale del contenedor.
ENV PORT=3000 \
    IA_PORT=8000

EXPOSE 3000
CMD ["/usr/local/bin/docker-entrypoint.sh"]
