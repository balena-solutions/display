#!/bin/bash
set -e
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"/run/user/0"}
export GALLIUM_HUD=${GALLIUM_HUD:-"fps,cpu"}

SOCKET_NAME=${SOCKET_NAME:-"wayland-0"}
export WAYLAND_DISPLAY=$SOCKET_NAME

SOCKET="$XDG_RUNTIME_DIR/$SOCKET_NAME"

echo "Waiting for Wayland socket at $SOCKET..."
while [ ! -e "$SOCKET" ]; do sleep 1; done
echo "Socket found. Launching eglgears_wayland..."

exec eglgears_wayland
