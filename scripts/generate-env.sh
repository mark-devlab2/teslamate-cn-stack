#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SOURCE_FILE="${SOURCE_FILE:-$ROOT_DIR/.env.example}"
OUTPUT_FILE="${1:-${OUTPUT_FILE:-$ROOT_DIR/.env}}"

if [ ! -f "$SOURCE_FILE" ]; then
  echo "missing source env file: $SOURCE_FILE" >&2
  exit 1
fi

python3 - "$SOURCE_FILE" "$OUTPUT_FILE" <<'PY'
import secrets
import sys
from pathlib import Path

source_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])

placeholder_prefixes = ("change_me_", "replace_with_")
generated_values = {
    "POSTGRES_PASSWORD": secrets.token_urlsafe(24),
    "ENCRYPTION_KEY": secrets.token_hex(32),
    "SECRET_KEY_BASE": secrets.token_hex(64),
    "SIGNING_SALT": secrets.token_hex(16),
    "MOSQUITTO_PASSWORD": secrets.token_urlsafe(24),
    "GRAFANA_ADMIN_PASSWORD": secrets.token_urlsafe(24),
    "BASIC_AUTH_PASSWORD": secrets.token_urlsafe(20),
    "API_TOKEN": secrets.token_hex(24),
}

manual_fields = [
    "ACME_EMAIL",
    "AMAP_WEB_SERVICE_KEY",
]

if output_path.exists():
    lines = output_path.read_text(encoding="utf-8").splitlines()
else:
    lines = source_path.read_text(encoding="utf-8").splitlines()

generated = []
for index, line in enumerate(lines):
    if not line or line.lstrip().startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    if key not in generated_values:
        continue
    normalized = value.strip()
    if normalized and not normalized.startswith(placeholder_prefixes):
        continue
    lines[index] = f"{key}={generated_values[key]}"
    generated.append(key)

output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"wrote env file: {output_path}")
if generated:
    print("generated secrets:")
    for key in generated:
        print(f"- {key}")
else:
    print("generated secrets: none")

print("manual fields still require review:")
for key in manual_fields:
    print(f"- {key}")
PY
