#!/bin/bash
# Discover available package versions from the base image.
# Writes src/DEPENDENCIES in package=version format.
# Usage: ./scripts/discover-versions.sh [arch] [image] [output-file]
#   arch defaults to aarch64 (maps to linux/arm64 for Docker)
set -e

ARCH="${1:-aarch64}"
IMAGE="${2:-debian:13.2-slim}"
OUTPUT="${3:-$(dirname "$0")/../src/DEPENDENCIES}"

# Map arch to Docker platform string
case "$ARCH" in
  aarch64) PLATFORM="linux/arm64" ;;
  amd64)   PLATFORM="linux/amd64" ;;
  *) echo "Unknown arch: $ARCH" >&2; exit 1 ;;
esac

echo "Querying apt candidates in $IMAGE ($PLATFORM)..."
docker run --rm --platform "$PLATFORM" "$IMAGE" bash -c "
  apt-get update -qq 2>/dev/null
  for pkg in weston libgl1-mesa-dri; do
    version=\$(apt-cache policy \"\$pkg\" 2>/dev/null | grep 'Candidate:' | awk '{print \$2}')
    echo \"\$pkg=\$version\"
  done" | tee "$OUTPUT"

echo ""
echo "Written to $OUTPUT — review, then build."
