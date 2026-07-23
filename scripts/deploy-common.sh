#!/usr/bin/env bash
# Deploy monitoring stack cho mot cum. Yeu cau bien CLUSTER=dmz|mid.
# Script se load .env.<cluster>, render alertmanager config va deploy stack
# tuong ung. Chay tren manager cua chinh cum do.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CLUSTER="${CLUSTER:-}"
case "$CLUSTER" in
  dmz|mid) ;;
  *)
    echo "CLUSTER phai la 'dmz' hoac 'mid'. Vd: CLUSTER=dmz $0" >&2
    exit 1
    ;;
esac

STACK_FILE="${STACK_FILE:-$ROOT_DIR/docker-stack-exporters-$CLUSTER.yml}"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env.$CLUSTER}"

if [ ! -f "$STACK_FILE" ]; then
  echo "Khong tim thay stack file: $STACK_FILE" >&2
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "Khong tim thay env file: $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

STACK_NAME="${STACK_NAME:-${STACK_COMMON_NAME:-monitor}}"
MONITORING_NETWORK="${MONITORING_NETWORK:-monitoring}"

if [ "$CLUSTER" = "dmz" ]; then
  TOOLS_NETWORK="${TOOLS_NETWORK:-nw_dmz}"
else
  TOOLS_NETWORK="${TOOLS_NETWORK:-backend}"
fi

if [ -z "${MS_TEAMS_WEBHOOK_URL:-}" ] \
   || [ "$MS_TEAMS_WEBHOOK_URL" = "CHANGE_ME_MS_TEAMS_WEBHOOK_URL" ] \
   || [ "$MS_TEAMS_WEBHOOK_URL" = "<MS_TEAMS_WEBHOOK_URL>" ]; then
  echo "MS_TEAMS_WEBHOOK_URL chua duoc dat trong $ENV_FILE." >&2
  exit 1
fi

if [ "$CLUSTER" = "dmz" ]; then
  if [ -z "${POSTGRES_DATA_SOURCE_NAME:-}" ] \
     || [ "$POSTGRES_DATA_SOURCE_NAME" = "<POSTGRES_DATA_SOURCE_NAME>" ]; then
    echo "POSTGRES_DATA_SOURCE_NAME chua duoc dat trong $ENV_FILE (bat buoc cho DMZ)." >&2
    exit 1
  fi
  if [ -z "${REDIS_EXPORTER_PASSWORD:-}" ] \
     || [ "$REDIS_EXPORTER_PASSWORD" = "<REDIS_EXPORTER_PASSWORD>" ]; then
    echo "REDIS_EXPORTER_PASSWORD chua duoc dat trong $ENV_FILE (bat buoc cho DMZ)." >&2
    exit 1
  fi
fi

mkdir -p "$ROOT_DIR/.generated"

# Render Alertmanager config tu template alertmanager/alertmanager.yml.
# Hien tai template khong co bien can substitute nen chi cp; giu nguyen buoc
# generate de tuong lai them cluster-specific route/receiver mot cach nhat quan.
cp "$ROOT_DIR/alertmanager/alertmanager.yml" "$ROOT_DIR/.generated/alertmanager.yml"

docker network inspect "$MONITORING_NETWORK" >/dev/null 2>&1 || \
  docker network create --driver overlay --attachable "$MONITORING_NETWORK"

if ! docker network inspect "$TOOLS_NETWORK" >/dev/null 2>&1; then
  echo "Overlay '$TOOLS_NETWORK' chua ton tai tren cum $CLUSTER." >&2
  echo "Vui long tao truoc (docker network create --driver overlay --attachable $TOOLS_NETWORK)" >&2
  echo "hoac deploy stack tools/femid cua cum truoc." >&2
  exit 1
fi

# Prometheus, Alertmanager, msteams pin ve node.labels.monitor==true. Kiem tra
# truoc khi deploy de tranh task ket ke o trang thai Pending vi khong co node
# khop constraint.
MONITOR_NODES=$(docker node ls --filter "label=monitor=true" --format '{{.Hostname}}' 2>/dev/null | wc -l | tr -d ' ')
if [ "${MONITOR_NODES:-0}" -eq 0 ]; then
  echo "Khong co node nao mang label 'monitor=true' tren swarm $CLUSTER." >&2
  echo "Chay tren manager cua cum:" >&2
  echo "  docker node ls" >&2
  echo "  docker node update --label-add monitor=true <hostname_da_chon>" >&2
  echo "Neu node lan truoc da chay monitor bi thay the, gan label vao node moi va giu volume prometheus_data/alertmanager_data cua node cu." >&2
  exit 1
fi
if [ "$MONITOR_NODES" -gt 1 ]; then
  echo "Canh bao: co $MONITOR_NODES node mang label monitor=true tren swarm $CLUSTER." >&2
  echo "Prometheus se schedule vao 1 trong so do; neu node do doi giua cac lan deploy, volume co the trong." >&2
  echo "Nen chi de dung 1 node mang label monitor=true." >&2
fi

echo "[monitor:$CLUSTER] Deploying stack '$STACK_NAME' tu $STACK_FILE ..."
docker stack deploy \
  --with-registry-auth \
  -c "$STACK_FILE" \
  "$STACK_NAME"

echo "[monitor:$CLUSTER] Done. Kiem tra: docker stack services $STACK_NAME"
