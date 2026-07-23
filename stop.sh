#!/usr/bin/env bash
# Wrapper an toan: bat buoc chi ro cum khi stop.
# stop la thao tac gay outage giam sat; xac dinh dung cum truoc khi chay.
# Vd:  ./stop.sh dmz    hoac    ./stop.sh mid
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLUSTER="${1:-}"
case "$CLUSTER" in
  dmz|mid)
    "$ROOT_DIR/scripts/stop-$CLUSTER.sh"
    ;;
  *)
    echo "Su dung: $0 <dmz|mid>" >&2
    exit 1
    ;;
esac
