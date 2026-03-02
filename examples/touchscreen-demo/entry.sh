#!/bin/bash
set -e
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"/run/user/0"}

SOCKET_NAME=${SOCKET_NAME:-"wayland-0"}
export WAYLAND_DISPLAY=$SOCKET_NAME

SOCKET="$XDG_RUNTIME_DIR/$SOCKET_NAME"

echo "Waiting for Wayland socket at $SOCKET..."
while [ ! -e "$SOCKET" ]; do sleep 1; done
echo "Socket found. Launching gtk4-demo..."


DEMO=${DEMO:-"drawingarea"}
export GDK_BACKEND=wayland

exec gtk4-demo --run $DEMO
