#!/usr/bin/env bash
# Arranca los dos procesos del backend dentro del mismo contenedor y ata su
# suerte: si cualquiera de los dos muere, se cae el contenedor entero.
#
# Eso último es lo importante. Un contenedor "vivo" con la mitad muerta es peor
# que uno caído: el healthcheck del hosting sigue en verde porque contesta
# NestJS, así que nadie reinicia nada y el fallo aparece de uno en uno, como
# errores sueltos de IA en el móvil.
set -uo pipefail

PORT="${PORT:-3000}"
IA_PORT="${IA_PORT:-8000}"

# Estas dos URL no son configurables a propósito. En esta imagen los dos
# procesos comparten el localhost, y si se quedan puestas en el panel del
# hosting apuntando a la URL pública de la otra mitad —que es como estaban
# cuando eran dos servicios— la llamada vuelve a salir a internet y a pasar por
# el proxy, que es justo lo que esta imagen viene a quitar. Se avisa y se pisa.
for var in AI_PYTHON_URL NEST_BASE_URL; do
  valor="${!var:-}"
  if [[ -n "$valor" ]]; then
    echo "[entrypoint] Ignoro $var=$valor — aquí las dos mitades hablan por 127.0.0.1." >&2
  fi
done

export AI_PYTHON_URL="http://127.0.0.1:${IA_PORT}"
export NEST_BASE_URL="http://127.0.0.1:${PORT}"

# Variables sin las que arrancar no sirve de nada. Se comprueban aquí, juntas y
# antes de lanzar nada, porque el precio de juntar los dos procesos es que un
# fallo de configuración de la mitad de IA ahora tira el backend entero: sin
# esto, una GEMINI_API_KEY que falte sale como un traceback de Python de treinta
# líneas al final del log, debajo del arranque normal de NestJS.
#
# Aborta en vez de seguir con lo que haya:
#   - INTERNAL_API_KEY: sin ella main.py contesta 401 a todo menos /health, así
#     que la app funcionaría entera salvo la IA — el fallo más caro de
#     diagnosticar de los tres.
#   - GEMINI_API_KEY / GROQ_API_KEY: `gemini_client.py` y `groq_client.py`
#     construyen su cliente al importarse, no en la primera petición.
faltan=()
for var in INTERNAL_API_KEY GEMINI_API_KEY GROQ_API_KEY; do
  [[ -z "${!var:-}" ]] && faltan+=("$var")
done
if (( ${#faltan[@]} > 0 )); then
  echo "[entrypoint] Faltan variables de entorno obligatorias: ${faltan[*]}. Aborto." >&2
  exit 1
fi

echo "[entrypoint] IA en 127.0.0.1:${IA_PORT} · API en 0.0.0.0:${PORT}"

( cd /app/ia && exec uvicorn main:app --host 127.0.0.1 --port "$IA_PORT" --workers 1 ) &
pid_ia=$!

( cd /app/api && exec node dist/main ) &
pid_api=$!

terminar() {
  kill -TERM "$pid_ia" "$pid_api" 2>/dev/null || true
}
trap terminar TERM INT

codigo=0
# `wait -n` vuelve en cuanto cae el PRIMERO de los dos, no cuando caen los dos.
wait -n || codigo=$?

echo "[entrypoint] Un proceso ha terminado (código $codigo); tumbo el contenedor." >&2
terminar
wait 2>/dev/null || true
exit "$codigo"
