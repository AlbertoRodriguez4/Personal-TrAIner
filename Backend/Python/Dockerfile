# python:3.11-slim (no 3.13): mediapipe todavía no publica ruedas para las
# versiones más nuevas, y sin rueda el build intenta compilar desde fuente y
# falla. En arm64 (Oracle Ampere) esto importa más aún.
FROM python:3.11-slim

WORKDIR /app

# Dependencias de sistema de OpenCV, que mediapipe arrastra. Sin libGL el
# `import mediapipe` revienta en tiempo de ejecución, no de instalación — es
# decir, la imagen construye bien y el servicio muere al primer análisis.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgl1 \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000
# Un solo worker a propósito: mediapipe carga su modelo de pose en memoria y
# cada worker duplicaría ese consumo. Para un usuario sobra de largo.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
