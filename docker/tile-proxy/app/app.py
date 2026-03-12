import mimetypes
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests
from flask import Flask, Response, abort, send_file


APP_USER_AGENT = "teslamate-cn-tile-proxy/1.0"
PRIMARY_TEMPLATE = os.getenv("TILE_URL_TEMPLATE", "https://tile.openstreetmap.org/{z}/{x}/{y}.png").strip()
FALLBACK_TEMPLATE = os.getenv("TILE_FALLBACK_URL_TEMPLATE", "").strip()
CACHE_DIR = Path(os.getenv("TILE_CACHE_DIR", "/data/cache"))
CACHE_TTL_SECONDS = int(os.getenv("TILE_CACHE_TTL_SECONDS", "2592000"))
CACHE_CONTROL = os.getenv("TILE_CACHE_CONTROL", "public,max-age=2592000,stale-while-revalidate=86400")
HTTP_TIMEOUT = float(os.getenv("TILE_TIMEOUT_SECONDS", "10"))

session = requests.Session()
session.headers.update({"User-Agent": APP_USER_AGENT})

app = Flask(__name__)


def is_fresh(path: Path) -> bool:
    if not path.exists():
        return False
    expires_at = datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc) + timedelta(seconds=CACHE_TTL_SECONDS)
    return expires_at > datetime.now(timezone.utc)


def resolve_upstream(template: str, z: int, x: int, y: int) -> str:
    return template.format(z=z, x=x, y=y)


def fetch_tile(url: str) -> tuple[bytes, str]:
    resp = session.get(url, timeout=HTTP_TIMEOUT)
    resp.raise_for_status()
    content_type = resp.headers.get("Content-Type", "image/png")
    return resp.content, content_type


def cache_paths(z: int, x: int, y: int) -> tuple[Path, Path]:
    base = CACHE_DIR / str(z) / str(x)
    base.mkdir(parents=True, exist_ok=True)
    return base / f"{y}.tile", base / f"{y}.content_type"


@app.route("/healthz")
def healthz():
    return {
        "status": "ok",
        "primaryTemplate": PRIMARY_TEMPLATE,
        "fallbackTemplate": FALLBACK_TEMPLATE,
    }


@app.route("/tiles/<int:z>/<int:x>/<int:y>.png")
def tile(z: int, x: int, y: int):
    if z < 0 or z > 22:
        abort(404)
    tile_path, content_type_path = cache_paths(z, x, y)
    if is_fresh(tile_path) and content_type_path.exists():
        content_type = content_type_path.read_text(encoding="utf-8").strip() or mimetypes.guess_type(tile_path.name)[0] or "image/png"
        response = send_file(tile_path, mimetype=content_type, conditional=True)
        response.headers["Cache-Control"] = CACHE_CONTROL
        return response

    errors = []
    for template in [PRIMARY_TEMPLATE, FALLBACK_TEMPLATE]:
        if not template:
            continue
        try:
            body, content_type = fetch_tile(resolve_upstream(template, z, x, y))
            tile_path.write_bytes(body)
            content_type_path.write_text(content_type, encoding="utf-8")
            response = Response(body, mimetype=content_type)
            response.headers["Cache-Control"] = CACHE_CONTROL
            return response
        except Exception as exc:  # pragma: no cover - best effort proxy
            errors.append(str(exc))
            continue

    return {"error": "tile fetch failed", "details": errors}, 502

