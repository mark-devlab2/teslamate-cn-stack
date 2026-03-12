#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
PLATFORM_REPO="${PLATFORM_REPO:-$ROOT_DIR/../aliyun-deploy-platform}"
OUTPUT_FILE="${1:-${OUTPUT_FILE:-$PLATFORM_REPO/runtime/teslamate-cn/service.env}}"

if [ ! -f "$ENV_FILE" ]; then
  echo "missing env file: $ENV_FILE" >&2
  exit 1
fi

sh "$ROOT_DIR/scripts/check-env.sh" "$ENV_FILE"

mkdir -p "$(dirname "$OUTPUT_FILE")"
cp "$ENV_FILE" "$OUTPUT_FILE"

echo "wrote platform env: $OUTPUT_FILE"
echo "next:"
echo "- run scripts/init.sh prepare on the target host before first edge start"
echo "- keep runtime/certs and runtime/nginx/htpasswd under backup control"
