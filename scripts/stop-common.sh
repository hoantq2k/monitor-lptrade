#!/usr/bin/env bash
# Remove monitoring stack cho mot cum. Yeu cau CLUSTER=dmz|mid.
# Day la thao tac gay outage giam sat; khong tu dong xoa persistent volume.
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

ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env.$CLUSTER}"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

STACK_NAME="${STACK_NAME:-${STACK_COMMON_NAME:-monitor}}"

echo "[monitor:$CLUSTER] Removing stack '$STACK_NAME' ..."
docker stack rm "$STACK_NAME"
