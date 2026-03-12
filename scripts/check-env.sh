#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ENV_FILE="${1:-${ENV_FILE:-$ROOT_DIR/.env}}"

if [ ! -f "$ENV_FILE" ]; then
  echo "missing env file: $ENV_FILE" >&2
  exit 1
fi

python3 - "$ENV_FILE" "$ROOT_DIR" <<'PY'
import sys
from pathlib import Path

env_path = Path(sys.argv[1])
root_dir = Path(sys.argv[2])

values = {}
for raw_line in env_path.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    values[key] = value.strip()

errors = []
warnings = []
placeholder_prefixes = ("change_me_", "replace_with_")

required = [
    "TM_DOMAIN",
    "TM_BASE_URL",
    "GRAFANA_URL",
    "TZ",
    "TLS_MODE",
    "POSTGRES_DB",
    "POSTGRES_USER",
    "POSTGRES_PASSWORD",
    "ENCRYPTION_KEY",
    "SECRET_KEY_BASE",
    "SIGNING_SALT",
    "TESLA_AUTH_HOST",
    "TESLA_API_HOST",
    "TESLA_WSS_HOST",
    "MOSQUITTO_USERNAME",
    "MOSQUITTO_PASSWORD",
    "GRAFANA_ADMIN_USER",
    "GRAFANA_ADMIN_PASSWORD",
    "BASIC_AUTH_USERNAME",
    "BASIC_AUTH_PASSWORD",
    "API_TOKEN",
    "TESLAMATEAPI_ENABLE_COMMANDS",
    "TESLAMATEAPI_API_TOKEN_DISABLE",
]

for key in required:
    value = values.get(key, "")
    if not value:
        errors.append(f"{key} is required")
        continue
    if value.startswith(placeholder_prefixes):
        errors.append(f"{key} still uses placeholder value")

tls_mode = values.get("TLS_MODE", "")
if tls_mode not in {"acme", "manual"}:
    errors.append("TLS_MODE must be acme or manual")
elif tls_mode == "acme":
    acme_email = values.get("ACME_EMAIL", "").strip()
    if not acme_email:
        errors.append("ACME_EMAIL is required when TLS_MODE=acme")
elif tls_mode == "manual":
    fullchain = root_dir / "runtime" / "certs" / "fullchain.pem"
    privkey = root_dir / "runtime" / "certs" / "privkey.pem"
    if not fullchain.exists() or not privkey.exists():
        warnings.append("TLS_MODE=manual requires runtime/certs/fullchain.pem and runtime/certs/privkey.pem")

if len(values.get("ENCRYPTION_KEY", "")) < 32:
    errors.append("ENCRYPTION_KEY must be at least 32 characters")
if len(values.get("SECRET_KEY_BASE", "")) < 64:
    errors.append("SECRET_KEY_BASE should be at least 64 characters")
if len(values.get("API_TOKEN", "")) < 32:
    errors.append("API_TOKEN must be at least 32 characters")

if values.get("TESLAMATEAPI_ENABLE_COMMANDS", "false").lower() != "false":
    warnings.append("TESLAMATEAPI_ENABLE_COMMANDS is not false; this enables remote vehicle commands")
if values.get("TESLAMATEAPI_API_TOKEN_DISABLE", "false").lower() != "false":
    errors.append("TESLAMATEAPI_API_TOKEN_DISABLE must remain false in production")

if not values.get("AMAP_WEB_SERVICE_KEY", "").strip():
    warnings.append("AMAP_WEB_SERVICE_KEY is empty; Chinese address enhancement will fall back and historical fix script will be limited")

if errors:
    print("env validation failed:")
    for item in errors:
      print(f"- {item}")
    if warnings:
      print("warnings:")
      for item in warnings:
        print(f"- {item}")
    sys.exit(1)

print("env validation passed")
if warnings:
    print("warnings:")
    for item in warnings:
        print(f"- {item}")
PY
