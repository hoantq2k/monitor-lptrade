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

if [ -z "${ALERTMANAGER_TELEGRAM_BOT_TOKEN:-}" ] || [ "$ALERTMANAGER_TELEGRAM_BOT_TOKEN" = "CHANGE_ME_TELEGRAM_BOT_TOKEN" ]; then
  echo "Please set ALERTMANAGER_TELEGRAM_BOT_TOKEN in .env before deploying Alertmanager." >&2
  exit 1
fi

if [ -z "${ALERTMANAGER_TELEGRAM_CHAT_ID:-}" ] || [ "$ALERTMANAGER_TELEGRAM_CHAT_ID" = "0" ]; then
  echo "Please set ALERTMANAGER_TELEGRAM_CHAT_ID in .env before deploying Alertmanager." >&2
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
    telegram_configs:
      - bot_token: '$ALERTMANAGER_TELEGRAM_BOT_TOKEN'
        chat_id: $ALERTMANAGER_TELEGRAM_CHAT_ID
        send_resolved: true
        parse_mode: HTML
        message: |-
          {{ if eq .Status "firing" }}<b>[FIRING]</b>{{ else }}<b>[RESOLVED]</b>{{ end }} {{ .CommonLabels.alertname }}
          Severity: {{ .CommonLabels.severity }}
          {{ range .Alerts }}
          Instance: {{ .Labels.instance }}
          Job: {{ .Labels.job }}
          Summary: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}

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

docker stack deploy \
  --with-registry-auth \
  -c "$ROOT_DIR/docker-stack-exporters.yml" \
  "$STACK_NAME"
