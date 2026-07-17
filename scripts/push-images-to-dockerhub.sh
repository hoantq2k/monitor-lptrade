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

DOCKER_HUB_NAMESPACE="${DOCKER_HUB_NAMESPACE:-}"

if [ -z "$DOCKER_HUB_NAMESPACE" ] || [ "$DOCKER_HUB_NAMESPACE" = "CHANGE_ME_DOCKER_HUB_NAMESPACE" ]; then
  echo "Please set DOCKER_HUB_NAMESPACE in .env before pushing images." >&2
  exit 1
fi

mirror_image() {
  local env_name="$1"
  local source_image="$2"
  local image_without_tag tag source_without_registry repo_name target_image

  if [ -z "$source_image" ]; then
    echo "Skip $env_name because image is empty." >&2
    return
  fi

  tag="${source_image##*:}"
  if [ "$tag" = "$source_image" ] || [[ "$source_image" == */* && "${source_image##*/}" != *:* ]]; then
    tag="latest"
    image_without_tag="$source_image"
  else
    image_without_tag="${source_image%:*}"
  fi

  source_without_registry="$image_without_tag"
  if [[ "$source_without_registry" == *.*/* || "$source_without_registry" == *:*/* ]]; then
    source_without_registry="${source_without_registry#*/}"
  fi

  repo_name="${source_without_registry//\//-}"
  target_image="${DOCKER_HUB_NAMESPACE}/${repo_name}:${tag}"

  echo "Pull $source_image"
  docker pull "$source_image"

  echo "Tag $source_image -> $target_image"
  docker tag "$source_image" "$target_image"

  echo "Push $target_image"
  docker push "$target_image"

  echo "$env_name=$target_image"
}

echo "Mirroring images to Docker Hub namespace: $DOCKER_HUB_NAMESPACE"
echo

echo "Generated image config:"
mirror_image "PROMETHEUS_IMAGE" "${PROMETHEUS_SOURCE_IMAGE:-prom/prometheus:latest}"
mirror_image "NODE_EXPORTER_IMAGE" "${NODE_EXPORTER_SOURCE_IMAGE:-prom/node-exporter:latest}"
mirror_image "CADVISOR_IMAGE" "${CADVISOR_SOURCE_IMAGE:-gcr.io/cadvisor/cadvisor:latest}"
mirror_image "ALERTMANAGER_IMAGE" "${ALERTMANAGER_SOURCE_IMAGE:-prom/alertmanager:latest}"
mirror_image "PROMETHEUS_MSTEAMS_IMAGE" "${PROMETHEUS_MSTEAMS_SOURCE_IMAGE:-quay.io/prometheusmsteams/prometheus-msteams:latest}"
mirror_image "BLACKBOX_EXPORTER_IMAGE" "${BLACKBOX_EXPORTER_SOURCE_IMAGE:-prom/blackbox-exporter:latest}"
mirror_image "POSTGRES_EXPORTER_IMAGE" "${POSTGRES_EXPORTER_SOURCE_IMAGE:-prometheuscommunity/postgres-exporter:latest}"
mirror_image "REDIS_EXPORTER_IMAGE" "${REDIS_EXPORTER_SOURCE_IMAGE:-oliver006/redis_exporter:latest}"
