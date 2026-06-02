#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="raccoon-build"
DOCKERFILE="docker/Dockerfile"
HASH_FILE=".dockerfile.hash"

current_hash="$(sha256sum "$DOCKERFILE" | awk '{print $1}')"

if [[ ! -f "$HASH_FILE" ]] || [[ "$(cat "$HASH_FILE")" != "$current_hash" ]]; then
  echo "Dockerfile changed; rebuilding image..."
  docker build --platform linux/amd64 -t "$IMAGE_NAME" -f "$DOCKERFILE" .
  echo "$current_hash" > "$HASH_FILE"
else
  echo "Dockerfile unchanged; skipping docker build."
fi

docker run --rm --platform linux/amd64 \
  -v "$PWD:/src" \
  -w /src \
  "$IMAGE_NAME" \
  zig "$@"
