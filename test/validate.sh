#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

for f in \
  "$ROOT_DIR/docker-compose.yml" \
  "$ROOT_DIR/.env.example" \
  "$ROOT_DIR/.deploy/build.yaml" \
  "$ROOT_DIR/docs/deploy.md" \
  "$ROOT_DIR/docs/upgrade.md" \
  "$ROOT_DIR/docs/rollback.md" \
  "$ROOT_DIR/docs/troubleshooting.md"
do
  [ -s "$f" ] || {
    echo "missing required file: $f" >&2
    exit 1
  }
done

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required for validation" >&2
  exit 1
fi

cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env.validation"
cleanup() {
  rm -f "$ROOT_DIR/.env.validation"
  if [ "${CREATED_ENV_FILE:-0}" = "1" ]; then
    rm -f "$ROOT_DIR/.env"
  fi
}
trap cleanup EXIT

if [ ! -f "$ROOT_DIR/.env" ]; then
  cp "$ROOT_DIR/.env.validation" "$ROOT_DIR/.env"
  CREATED_ENV_FILE=1
fi

mkdir -p \
  "$ROOT_DIR/runtime/postgres" \
  "$ROOT_DIR/runtime/mosquitto/data" \
  "$ROOT_DIR/runtime/mosquitto/log" \
  "$ROOT_DIR/runtime/cn-geocoder" \
  "$ROOT_DIR/runtime/tile-cache" \
  "$ROOT_DIR/runtime/teslamate/import" \
  "$ROOT_DIR/runtime/teslamate/backup" \
  "$ROOT_DIR/runtime/grafana" \
  "$ROOT_DIR/runtime/acme" \
  "$ROOT_DIR/runtime/certs" \
  "$ROOT_DIR/runtime/acme-webroot" \
  "$ROOT_DIR/runtime/nginx" \
  "$ROOT_DIR/runtime/logs/nginx"

touch "$ROOT_DIR/runtime/nginx/htpasswd"

docker compose --env-file "$ROOT_DIR/.env.validation" -f "$ROOT_DIR/docker-compose.yml" config >/dev/null

python3 -m json.tool "$ROOT_DIR/.deploy/build.yaml" >/dev/null

echo "validation passed"
