#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

usage() {
  cat <<'EOF'
usage: scripts/init.sh <prepare|bootstrap>

prepare:
  - create runtime directories
  - generate nginx basic auth file from BASIC_AUTH_USERNAME/BASIC_AUTH_PASSWORD

bootstrap:
  - wait for teslamate to become healthy
  - apply localized default settings to TeslaMate
EOF
}

load_env() {
  if [ ! -f "$ENV_FILE" ]; then
    echo "missing env file: $ENV_FILE" >&2
    exit 1
  fi
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
}

compose() {
  docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" "$@"
}

prepare_runtime() {
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
}

generate_htpasswd() {
  : "${BASIC_AUTH_USERNAME:?BASIC_AUTH_USERNAME is required}"
  : "${BASIC_AUTH_PASSWORD:?BASIC_AUTH_PASSWORD is required}"

  docker run --rm --entrypoint htpasswd httpd:2.4-alpine -nbB "$BASIC_AUTH_USERNAME" "$BASIC_AUTH_PASSWORD" >"$ROOT_DIR/runtime/nginx/htpasswd"
  chmod 600 "$ROOT_DIR/runtime/nginx/htpasswd"
}

wait_for_teslamate() {
  i=0
  until compose exec -T teslamate curl -fsS http://127.0.0.1:4000/health_check >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -ge 60 ]; then
      echo "teslamate did not become healthy within timeout" >&2
      exit 1
    fi
    sleep 5
  done
}

bootstrap_settings() {
  : "${TM_BASE_URL:?TM_BASE_URL is required}"
  : "${GRAFANA_URL:?GRAFANA_URL is required}"
  : "${TM_INIT_LANGUAGE:?TM_INIT_LANGUAGE is required}"
  : "${TM_INIT_UNIT_OF_LENGTH:?TM_INIT_UNIT_OF_LENGTH is required}"
  : "${TM_INIT_UNIT_OF_TEMPERATURE:?TM_INIT_UNIT_OF_TEMPERATURE is required}"
  : "${TM_INIT_UNIT_OF_PRESSURE:?TM_INIT_UNIT_OF_PRESSURE is required}"
  : "${TM_INIT_PREFERRED_RANGE:?TM_INIT_PREFERRED_RANGE is required}"

  compose exec -T postgres psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<EOF
UPDATE settings
SET language = '${TM_INIT_LANGUAGE}',
    unit_of_length = '${TM_INIT_UNIT_OF_LENGTH}',
    unit_of_temperature = '${TM_INIT_UNIT_OF_TEMPERATURE}',
    unit_of_pressure = '${TM_INIT_UNIT_OF_PRESSURE}',
    preferred_range = '${TM_INIT_PREFERRED_RANGE}',
    base_url = '${TM_BASE_URL}',
    grafana_url = '${GRAFANA_URL}',
    theme_mode = 'system',
    updated_at = NOW();
EOF
}

cmd="${1:-}"
case "$cmd" in
  prepare)
    load_env
    prepare_runtime
    generate_htpasswd
    echo "runtime prepared"
    ;;
  bootstrap)
    load_env
    wait_for_teslamate
    bootstrap_settings
    echo "teslamate defaults applied"
    ;;
  *)
    usage
    exit 1
    ;;
esac

