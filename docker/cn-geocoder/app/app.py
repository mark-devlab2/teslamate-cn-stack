import json
import os
import sqlite3
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path

import requests
from flask import Flask, Response, jsonify, request


APP_USER_AGENT = "teslamate-cn-geocoder/1.0"
DEFAULT_PROVIDER = os.getenv("CN_GEOCODER_PROVIDER", "amap").strip().lower() or "amap"
AMAP_KEY = os.getenv("AMAP_WEB_SERVICE_KEY", "").strip()
NOMINATIM_FALLBACK_BASE_URL = (
    os.getenv("NOMINATIM_FALLBACK_BASE_URL", "https://nominatim.openstreetmap.org").rstrip("/")
)
DB_PATH = Path(os.getenv("GEOCODER_DB_PATH", "/data/geocoder-cache.sqlite3"))
HTTP_TIMEOUT = float(os.getenv("GEOCODER_TIMEOUT_SECONDS", "10"))
SYNTHETIC_TYPE = "relation"

session = requests.Session()
session.headers.update({"User-Agent": APP_USER_AGENT})

app = Flask(__name__)


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def db() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with closing(db()) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS geocoder_cache (
              synthetic_id INTEGER PRIMARY KEY AUTOINCREMENT,
              provider_key TEXT NOT NULL UNIQUE,
              synthetic_type TEXT NOT NULL,
              wgs84_lat REAL NOT NULL,
              wgs84_lon REAL NOT NULL,
              payload_json TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
            """
        )
        conn.commit()


def in_china(lat: float, lon: float) -> bool:
    return 18.0 <= lat <= 54.5 and 73.0 <= lon <= 135.1


def proxy_nominatim(path: str, params: dict) -> Response:
    upstream = f"{NOMINATIM_FALLBACK_BASE_URL}{path}"
    headers = {"Accept-Language": request.headers.get("Accept-Language", "zh-CN")}
    resp = session.get(upstream, params=params, headers=headers, timeout=HTTP_TIMEOUT)
    return Response(resp.content, status=resp.status_code, content_type=resp.headers.get("Content-Type", "application/json"))


def amap_convert(lat: float, lon: float) -> tuple[float, float]:
    resp = session.get(
        "https://restapi.amap.com/v3/assistant/coordinate/convert",
        params={"locations": f"{lon},{lat}", "coordsys": "gps", "key": AMAP_KEY},
        timeout=HTTP_TIMEOUT,
    )
    resp.raise_for_status()
    body = resp.json()
    if body.get("status") != "1" or not body.get("locations"):
        raise ValueError(body.get("info") or "amap coordinate convert failed")
    converted_lon, converted_lat = body["locations"].split(",", 1)
    return float(converted_lat), float(converted_lon)


def amap_reverse(gcj_lat: float, gcj_lon: float) -> dict:
    resp = session.get(
        "https://restapi.amap.com/v3/geocode/regeo",
        params={
            "location": f"{gcj_lon},{gcj_lat}",
            "extensions": "all",
            "radius": "1000",
            "roadlevel": "0",
            "key": AMAP_KEY,
        },
        timeout=HTTP_TIMEOUT,
    )
    resp.raise_for_status()
    body = resp.json()
    if body.get("status") != "1":
        raise ValueError(body.get("info") or "amap reverse geocode failed")
    return body.get("regeocode") or {}


def first_non_empty(*values):
    for value in values:
        if value is None:
            continue
        if isinstance(value, list):
            for item in value:
                if isinstance(item, dict):
                    candidate = item.get("name") or item.get("value")
                else:
                    candidate = item
                if candidate:
                    return candidate
            continue
        if value:
            return value
    return None


def provider_key_for(regeo: dict, wgs84_lat: float, wgs84_lon: float) -> str:
    component = regeo.get("addressComponent") or {}
    street = component.get("streetNumber") or {}
    key_parts = [
        component.get("adcode") or "",
        regeo.get("formatted_address") or "",
        street.get("street") or "",
        street.get("number") or "",
        f"{round(wgs84_lat, 6):.6f}",
        f"{round(wgs84_lon, 6):.6f}",
    ]
    return "amap:" + "|".join(key_parts)


def normalize_amap_payload(regeo: dict, wgs84_lat: float, wgs84_lon: float, synthetic_id: int) -> dict:
    component = regeo.get("addressComponent") or {}
    street = component.get("streetNumber") or {}
    neighborhood = component.get("neighborhood") or {}
    building = component.get("building") or {}
    city_value = component.get("city")
    if isinstance(city_value, list):
        city_value = city_value[0] if city_value else ""

    name = first_non_empty(
        street.get("street"),
        building.get("name"),
        neighborhood.get("name"),
        component.get("township"),
        regeo.get("formatted_address"),
    )

    return {
        "place_id": synthetic_id,
        "licence": "AMap Web Service via teslamate-cn-stack",
        "osm_type": SYNTHETIC_TYPE,
        "osm_id": synthetic_id,
        "lat": str(wgs84_lat),
        "lon": str(wgs84_lon),
        "display_name": regeo.get("formatted_address") or "Unknown",
        "name": name,
        "namedetails": {"name": name} if name else {},
        "address": {
            "house_number": street.get("number") or None,
            "road": first_non_empty(street.get("street"), neighborhood.get("name")),
            "neighbourhood": first_non_empty(neighborhood.get("name"), component.get("township")),
            "city": first_non_empty(city_value, component.get("district"), component.get("province")),
            "county": component.get("district") or None,
            "postcode": component.get("adcode") or None,
            "state": component.get("province") or None,
            "state_district": first_non_empty(city_value, component.get("district")),
            "country": component.get("country") or "中国",
        },
        "extratags": {
            "countrycode": "cn",
            "adcode": component.get("adcode") or "",
            "township": component.get("township") or "",
        },
        "raw": regeo,
    }


def upsert_payload(provider_key: str, wgs84_lat: float, wgs84_lon: float, payload: dict) -> dict:
    now = now_iso()
    with closing(db()) as conn:
        row = conn.execute(
            "SELECT synthetic_id FROM geocoder_cache WHERE provider_key = ?",
            (provider_key,),
        ).fetchone()
        if row:
            synthetic_id = int(row["synthetic_id"])
            payload["place_id"] = synthetic_id
            payload["osm_id"] = synthetic_id
            conn.execute(
                """
                UPDATE geocoder_cache
                SET wgs84_lat = ?, wgs84_lon = ?, payload_json = ?, updated_at = ?
                WHERE synthetic_id = ?
                """,
                (wgs84_lat, wgs84_lon, json.dumps(payload, ensure_ascii=False), now, synthetic_id),
            )
        else:
            cursor = conn.execute(
                """
                INSERT INTO geocoder_cache (
                  provider_key, synthetic_type, wgs84_lat, wgs84_lon, payload_json, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    provider_key,
                    SYNTHETIC_TYPE,
                    wgs84_lat,
                    wgs84_lon,
                    json.dumps(payload, ensure_ascii=False),
                    now,
                    now,
                ),
            )
            synthetic_id = cursor.lastrowid
            payload["place_id"] = synthetic_id
            payload["osm_id"] = synthetic_id
            conn.execute(
                "UPDATE geocoder_cache SET payload_json = ? WHERE synthetic_id = ?",
                (json.dumps(payload, ensure_ascii=False), synthetic_id),
            )
        conn.commit()
    return payload


def fetch_cached_payload(osm_id: int, osm_type: str) -> dict | None:
    if osm_type != SYNTHETIC_TYPE:
        return None
    with closing(db()) as conn:
        row = conn.execute(
            "SELECT payload_json FROM geocoder_cache WHERE synthetic_id = ?",
            (osm_id,),
        ).fetchone()
    if row is None:
        return None
    return json.loads(row["payload_json"])


def reverse_with_amap(lat: float, lon: float) -> dict:
    if not AMAP_KEY:
        raise RuntimeError("AMAP_WEB_SERVICE_KEY is not configured")
    gcj_lat, gcj_lon = amap_convert(lat, lon)
    regeo = amap_reverse(gcj_lat, gcj_lon)
    if not regeo or not regeo.get("formatted_address"):
        return {"error": "Unable to geocode"}
    payload = normalize_amap_payload(regeo, lat, lon, 0)
    return upsert_payload(provider_key_for(regeo, lat, lon), lat, lon, payload)


@app.route("/healthz")
def healthz():
    return jsonify(
        {
            "status": "ok",
            "provider": DEFAULT_PROVIDER,
            "amapConfigured": bool(AMAP_KEY),
            "fallbackBaseUrl": NOMINATIM_FALLBACK_BASE_URL,
        }
    )


@app.route("/reverse")
def reverse_lookup():
    lat = request.args.get("lat", type=float)
    lon = request.args.get("lon", type=float)
    if lat is None or lon is None:
        return jsonify({"error": "lat/lon are required"}), 400

    if DEFAULT_PROVIDER == "amap" and AMAP_KEY and in_china(lat, lon):
        try:
            payload = reverse_with_amap(lat, lon)
            return jsonify(payload)
        except Exception as exc:  # pragma: no cover - best effort fallback
            if NOMINATIM_FALLBACK_BASE_URL:
                return proxy_nominatim("/reverse", request.args.to_dict(flat=True))
            return jsonify({"error": str(exc)}), 502

    if NOMINATIM_FALLBACK_BASE_URL:
        return proxy_nominatim("/reverse", request.args.to_dict(flat=True))
    return jsonify({"error": "Unable to geocode"})


@app.route("/lookup")
def lookup():
    osm_ids = request.args.get("osm_ids", "").strip()
    if not osm_ids:
        return jsonify([]), 200

    ids = [item.strip() for item in osm_ids.split(",") if item.strip()]
    payloads = []
    missing = []
    for item in ids:
        osm_type_code = item[:1]
        osm_id = item[1:]
        type_map = {"R": "relation", "W": "way", "N": "node"}
        osm_type = type_map.get(osm_type_code, SYNTHETIC_TYPE)
        try:
            numeric_id = int(osm_id)
        except ValueError:
            continue
        payload = fetch_cached_payload(numeric_id, osm_type)
        if payload is None:
            missing.append(item)
            continue
        payloads.append(payload)

    if missing and NOMINATIM_FALLBACK_BASE_URL:
        return proxy_nominatim("/lookup", request.args.to_dict(flat=True))
    return jsonify(payloads)


init_db()
