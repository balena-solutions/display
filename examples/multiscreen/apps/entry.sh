#!/bin/bash
set -e

export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"/run/user/0"}
export WAYLAND_DISPLAY=${SOCKET_NAME:-"wayland-0"}

APP1=${APP1:-"weston-simple-shm"}
APP2=${APP2:-"weston-flower"}

SOCKET="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
echo "Waiting for Wayland socket at $SOCKET..."
while [ ! -e "$SOCKET" ]; do sleep 1; done
echo "Wayland socket ready. Launching ${APP1} and ${APP2}..."

$APP1 &
$APP2 &

wait
