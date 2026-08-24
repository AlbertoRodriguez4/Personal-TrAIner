import os
import requests

NEST_BASE_URL = os.environ.get("NEST_BASE_URL", "http://localhost:3000")

# NestJS exige token en todos sus endpoints. Este servicio actúa en nombre del
# usuario pero no tiene su token: la petición original la recibió NestJS, que
# solo nos pasa el `user_id`. Así que se identifica con una clave interna
# compartida, y NestJS le permite operar sobre el usuario que le indiquen.
#
# La misma clave protege la dirección inversa: main.py exige este header en
# TODAS sus rutas salvo /health (ver verificar_clave_interna). Eso es lo que
# hace seguro publicar el puerto de este servicio (Hugging Face Spaces, etc.)
# en vez de depender de que viva solo en la red interna de Docker — sin esa
# clave, cualquiera que encuentre la URL podría actuar como cualquier usuario.
INTERNAL_API_KEY = os.environ.get("INTERNAL_API_KEY", "")


def _headers() -> dict:
    return {"X-Internal-Key": INTERNAL_API_KEY} if INTERNAL_API_KEY else {}


class NestApiError(Exception):
    def __init__(self, status_code: int, detail: str):
        self.status_code = status_code
        self.detail = detail
        super().__init__(f"NestJS {status_code}: {detail}")


def _request(method: str, path: str, json: dict | None = None, params: dict | None = None):
    url = f"{NEST_BASE_URL}{path}"
    resp = requests.request(
        method, url, json=json, params=params, headers=_headers(), timeout=20
    )
    if not resp.ok:
        raise NestApiError(resp.status_code, resp.text)
    return resp.json() if resp.content else None


def get(path: str, params: dict | None = None):
    return _request("GET", path, params=params)


def post(path: str, body: dict):
    return _request("POST", path, json=body)


def put(path: str, body: dict):
    return _request("PUT", path, json=body)
