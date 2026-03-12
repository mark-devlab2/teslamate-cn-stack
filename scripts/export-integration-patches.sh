#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
PLATFORM_REPO=${PLATFORM_REPO:-/Users/mark/Documents/New project/aliyun-deploy-platform}
OPS_REPO=${OPS_REPO:-/Users/mark/Documents/New project/openclaw-main-config}
OUTPUT_DIR=${OUTPUT_DIR:-"$ROOT_DIR/artifacts/integration-patches"}

require_repo() {
  repo_path=$1
  if [ ! -d "$repo_path/.git" ]; then
    echo "missing git repository: $repo_path" >&2
    exit 1
  fi
}

export_patch() {
  repo_path=$1
  output_path=$2
  shift 2

  mkdir -p "$(dirname "$output_path")"
  git -C "$repo_path" diff -- "$@" >"$output_path"

  if [ ! -s "$output_path" ]; then
    rm -f "$output_path"
    echo "no matching changes in $repo_path"
    return 0
  fi

  echo "wrote patch: $output_path"
}

require_repo "$PLATFORM_REPO"
require_repo "$OPS_REPO"

export_patch \
  "$PLATFORM_REPO" \
  "$OUTPUT_DIR/aliyun-deploy-platform.teslamate-cn.patch" \
  .github/workflows/build-publish.yml \
  .github/workflows/validate-service.yml \
  scripts/render-config.py \
  services/teslamate-cn

export_patch \
  "$OPS_REPO" \
  "$OUTPUT_DIR/openclaw-main-config.teslamate-cn.patch" \
  ops/deploy_targets.yaml \
  ops/ops-watch.env.example \
  ops/watch_targets.yaml \
  scripts/health-check.sh
