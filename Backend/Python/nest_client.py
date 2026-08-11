import os
import requests

NEST_BASE_URL = os.environ.get("NEST_BASE_URL", "http://localhost:3000")


class NestApiError(Exception):
    def __init__(self, status_code: int, detail: str):
        self.status_code = status_code
        self.detail = detail
        super().__init__(f"NestJS {status_code}: {detail}")


def _request(method: str, path: str, json: dict | None = None, params: dict | None = None):
    url = f"{NEST_BASE_URL}{path}"
    resp = requests.request(method, url, json=json, params=params, timeout=20)
    if not resp.ok:
        raise NestApiError(resp.status_code, resp.text)
    return resp.json() if resp.content else None


def get(path: str, params: dict | None = None):
    return _request("GET", path, params=params)


def post(path: str, body: dict):
    return _request("POST", path, json=body)


def put(path: str, body: dict):
    return _request("PUT", path, json=body)
