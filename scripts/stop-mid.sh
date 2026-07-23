#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER=mid "$ROOT_DIR/scripts/stop-common.sh"
