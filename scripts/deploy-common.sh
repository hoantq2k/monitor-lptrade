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

STACK_NAME="${STACK_NAME:-${STACK_COMMON_NAME:-monitor}}"
MONITORING_NETWORK="${MONITORING_NETWORK:-monitoring}"
TOOLS_NETWORK="${TOOLS_NETWORK:-nw_dmz}"

if [ -z "${MS_TEAMS_WEBHOOK_URL:-}" ] || [ "$MS_TEAMS_WEBHOOK_URL" = "CHANGE_ME_MS_TEAMS_WEBHOOK_URL" ]; then
  echo "Please set MS_TEAMS_WEBHOOK_URL in .env before deploying Alertmanager." >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/.generated"

cat > "$ROOT_DIR/.generated/alertmanager.yml" <<EOF
global:
  resolve_timeout: 5m

route:
  receiver: default
  group_by:
    - alertname
    - job
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

receivers:
  - name: default
    webhook_configs:
      - url: 'http://prometheus_msteams:2000/alertmanager'
        send_resolved: true

inhibit_rules:
  - source_matchers:
      - severity="critical"
    target_matchers:
      - severity="warning"
    equal:
      - alertname
      - instance
EOF

docker network inspect "$MONITORING_NETWORK" >/dev/null 2>&1 || \
  docker network create --driver overlay --attachable "$MONITORING_NETWORK"

if ! docker network inspect "$TOOLS_NETWORK" >/dev/null 2>&1; then
  echo "Required tools network '$TOOLS_NETWORK' was not found. Please create it or deploy the tools stack first." >&2
  exit 1
fi

docker stack deploy \
  --with-registry-auth \
  -c "$ROOT_DIR/docker-stack-exporters.yml" \
  "$STACK_NAME"
