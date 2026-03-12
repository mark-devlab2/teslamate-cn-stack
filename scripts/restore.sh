#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
BACKUP_DIR="${1:-}"
RESTORE_CONFIG="${RESTORE_CONFIG:-0}"

usage() {
  echo "usage: scripts/restore.sh <backup_dir>" >&2
}

if [ -z "$BACKUP_DIR" ]; then
  usage
  exit 1
fi

if [ ! -d "$BACKUP_DIR" ]; then
  echo "backup dir not found: $BACKUP_DIR" >&2
  exit 1
fi

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

compose down

mkdir -p "$ROOT_DIR/runtime"

if [ -f "$BACKUP_DIR/runtime-support.tar.gz" ]; then
  tar -xzf "$BACKUP_DIR/runtime-support.tar.gz" -C "$ROOT_DIR/runtime"
fi

if [ "$RESTORE_CONFIG" = "1" ] && [ -f "$BACKUP_DIR/config.tar.gz" ]; then
  tar -xzf "$BACKUP_DIR/config.tar.gz" -C "$ROOT_DIR"
fi

compose up -d postgres

i=0
until compose exec -T postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -ge 60 ]; then
    echo "postgres did not become ready within timeout" >&2
    exit 1
  fi
  sleep 5
done

cat "$BACKUP_DIR/postgres.dump" | compose exec -T postgres sh -c '
  cat >/tmp/restore.dump
  pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --no-owner --no-privileges /tmp/restore.dump
  rm -f /tmp/restore.dump
'

compose up -d

echo "restore completed"

