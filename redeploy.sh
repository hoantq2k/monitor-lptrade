#!/usr/bin/env bash
# Wrapper an toan: bat buoc chi ro cum khi redeploy.
# Vd:  ./redeploy.sh dmz    hoac    ./redeploy.sh mid
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLUSTER="${1:-}"
case "$CLUSTER" in
  dmz|mid)
    "$ROOT_DIR/scripts/redeploy-$CLUSTER.sh"
    ;;
  *)
    echo "Su dung: $0 <dmz|mid>" >&2
    exit 1
    ;;
esac
