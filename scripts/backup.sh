#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups/$STAMP}"

if [ ! -f "$ENV_FILE" ]; then
  echo "missing env file: $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

compose() {
  docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml" "$@"
}

mkdir -p "$BACKUP_DIR"

compose exec -T postgres pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc >"$BACKUP_DIR/postgres.dump"

tar -czf "$BACKUP_DIR/grafana.tar.gz" -C "$ROOT_DIR/runtime" grafana
tar -czf "$BACKUP_DIR/runtime-support.tar.gz" -C "$ROOT_DIR/runtime" cn-geocoder tile-cache mosquitto certs nginx 2>/dev/null || true
tar -czf "$BACKUP_DIR/config.tar.gz" -C "$ROOT_DIR" docker-compose.yml .env .deploy docker scripts docs

compose images >"$BACKUP_DIR/images.txt" || true

cat >"$BACKUP_DIR/manifest.txt" <<EOF
created_at=$STAMP
postgres_db=$POSTGRES_DB
postgres_user=$POSTGRES_USER
domain=$TM_DOMAIN
tls_mode=$TLS_MODE
EOF

echo "$BACKUP_DIR"

