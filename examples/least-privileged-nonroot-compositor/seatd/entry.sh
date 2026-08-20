#!/bin/bash
set -e

# ==============================================================================
# seatd broker sidecar
# ==============================================================================
# Runs the seatd daemon as root in an isolated, non-privileged container. It
# opens the GPU (/dev/dri) and input (/dev/input) devices and hands file
# descriptors to an unprivileged Weston (in the 'display' container) over
# /run/seatd.sock on the shared /run volume. This is what lets the compositor
# itself run as a non-root user.

# ------------------------------------------------------------------------------
# STOP PLYMOUTH (Release DRM master)
# ------------------------------------------------------------------------------
# Because seatd is the process that grabs the GPU, it owns releasing the DRM
# lock Plymouth holds on boot. This container carries the io.balena.features.dbus
# label; the compositor container needs no D-Bus access at all.
if [ -e /host/run/dbus/system_bus_socket ]; then
    echo "Stopping Plymouth to release DRM lock..."
    DBUS_SYSTEM_BUS_ADDRESS=unix:path=/host/run/dbus/system_bus_socket dbus-send \
    --system \
    --dest=org.freedesktop.systemd1 \
    --type=method_call \
    --print-reply /org/freedesktop/systemd1 \
    org.freedesktop.systemd1.Manager.StartUnit string:"plymouth-quit.service" string:"replace" || true
else
    echo "[WARN] D-Bus socket not found. Ensure 'io.balena.features.dbus' label is set."
fi

# ------------------------------------------------------------------------------
# LAUNCH SEATD
# ------------------------------------------------------------------------------
# Non-VT-bound: a container has no VT (/dev/tty0), and a VT-bound seat can never
# activate, causing seatd to deny device access. '-g seat' sets the socket group
# so the compositor user (a member of 'seat') can connect across containers.
export SEATD_VTBOUND="${SEATD_VTBOUND:-0}"

echo "--- LAUNCHING SEATD ---"
exec seatd -g seat
