#!/bin/bash
set -e

ORG="${ORG:-balena_solutions}"
BLOCK_NAME="${BLOCK_NAME:-display}"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

ARCH="${1:?Usage: $0 <arch> (aarch64|amd64) [--dry-run]}"
DRY_RUN=false
if [[ "$2" == "--dry-run" ]]; then
    DRY_RUN=true
fi

FLEET="${ORG}/${BLOCK_NAME}-${ARCH}"


echo ">>> Pushing to fleet: ${FLEET}"
if [ "$DRY_RUN" = true ]; then
    echo "    [dry-run] balena push ${FLEET} --source ${SRC_DIR}"
else
    balena push "${FLEET}" --source "${SRC_DIR}"
fi

echo "Done."
