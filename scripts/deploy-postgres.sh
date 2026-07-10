#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

STACK_NAME="${STACK_NAME:-${STACK_POSTGRES_NAME:-monitor-postgres}}"
MONITORING_NETWORK="${MONITORING_NETWORK:-monitoring}"

docker network inspect "$MONITORING_NETWORK" >/dev/null 2>&1 || \
  docker network create --driver overlay --attachable "$MONITORING_NETWORK"

docker stack deploy \
  --with-registry-auth \
  -c "$ROOT_DIR/docker-stack-postgres-exporter.yml" \
  "$STACK_NAME"
