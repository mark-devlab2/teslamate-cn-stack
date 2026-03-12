#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
WINDOW_START=""
WINDOW_END=""
SKIP_BACKUP=0

usage() {
  cat <<'EOF'
usage: scripts/fix-addresses.sh [--window-start ISO8601] [--window-end ISO8601] [--skip-backup]

默认模式：
- 修复空地址 / 无效地址引用
- 触发 TeslaMate 历史记录补地址
- 刷新现有地址内容

窗口模式：
- 在给定时间窗内，将中国范围内记录的地址引用清空后重算
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --window-start)
      WINDOW_START="$2"
      shift 2
      ;;
    --window-end)
      WINDOW_END="$2"
      shift 2
      ;;
    --skip-backup)
      SKIP_BACKUP=1
      shift 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

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

missing_count() {
  compose exec -T postgres psql -At -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<'EOF'
SELECT
  (SELECT count(*) FROM drives WHERE start_address_id IS NULL OR end_address_id IS NULL) +
  (SELECT count(*) FROM charging_processes WHERE address_id IS NULL);
EOF
}

if [ "$SKIP_BACKUP" != "1" ]; then
  "$ROOT_DIR/scripts/backup.sh" >/dev/null
fi

before="$(missing_count)"

cat "$ROOT_DIR/scripts/sql/fix_empty_addresses.sql" | compose exec -T postgres psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"

if [ -n "$WINDOW_START" ] && [ -n "$WINDOW_END" ]; then
  compose exec -T postgres psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<EOF
UPDATE drives d
SET start_address_id = NULL
FROM positions p
WHERE d.start_position_id = p.id
  AND d.start_date >= '${WINDOW_START}'::timestamptz
  AND d.start_date <= '${WINDOW_END}'::timestamptz
  AND p.latitude BETWEEN 18 AND 54.5
  AND p.longitude BETWEEN 73 AND 135.1;

UPDATE drives d
SET end_address_id = NULL
FROM positions p
WHERE d.end_position_id = p.id
  AND d.end_date IS NOT NULL
  AND d.end_date >= '${WINDOW_START}'::timestamptz
  AND d.end_date <= '${WINDOW_END}'::timestamptz
  AND p.latitude BETWEEN 18 AND 54.5
  AND p.longitude BETWEEN 73 AND 135.1;

UPDATE charging_processes c
SET address_id = NULL
FROM positions p
WHERE c.position_id = p.id
  AND c.start_date >= '${WINDOW_START}'::timestamptz
  AND c.start_date <= '${WINDOW_END}'::timestamptz
  AND p.latitude BETWEEN 18 AND 54.5
  AND p.longitude BETWEEN 73 AND 135.1;
EOF
fi

compose exec -T teslamate bin/teslamate eval "TeslaMate.Repair.trigger_run(); Process.sleep(:timer.seconds(20))"
compose exec -T teslamate bin/teslamate eval "TeslaMate.Locations.refresh_addresses(\"${TM_INIT_LANGUAGE}\")"

after="$(missing_count)"

echo "missing_before=$before"
echo "missing_after=$after"

if [ -z "${AMAP_WEB_SERVICE_KEY:-}" ]; then
  echo "warning: AMAP_WEB_SERVICE_KEY is empty, address repair fell back to upstream geocoder behavior" >&2
fi
