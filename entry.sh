#!/bin/bash
set -e
# Define the Runtime Directory
# Wayland requires this directory to communicate via sockets.
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"/run/user/0"}
SOCKET_NAME=${SOCKET_NAME:-"wayland-0"}
WESTON_DEBUG=${WESTON_DEBUG:-"false"}  # Default: Disabled

# ==============================================================================
# STOP PLYMOUTH (Release DRM Master)
# ==============================================================================
# Plymouth holds the DRM lock on boot. We must tell it to quit so Weston can
# take control of the graphics card.
if [ -e /host/run/dbus/system_bus_socket ]; then
    echo "Stopping Plymouth to release DRM lock..."
    # We send the Quit command to Plymouth. 
    # '|| true' ensures the script continues even if Plymouth is already stopped.
    DBUS_SYSTEM_BUS_ADDRESS=unix:path=/host/run/dbus/system_bus_socket dbus-send \
    --system \
    --dest=org.freedesktop.systemd1 \
    --type=method_call \
    --print-reply /org/freedesktop/systemd1   \
    org.freedesktop.systemd1.Manager.StartUnit string:"plymouth-quit.service" string:"replace"
else
    echo "[WARN] D-Bus socket not found. Ensure 'io.balena.features.dbus' label is set."
fi

# ==============================================================================
# CLEANUP & SETUP
# ==============================================================================

# source: https://github.com/jakogut/balena-steam/blob/5b5205cf49912dff267385a13af1520559eb16f0/display/entry.sh#L2
cleanup () {
	rm -rf "${XDG_RUNTIME_DIR}" /tmp/.X11-unix/* /tmp/.X?-lock
}
cleanup

# ==============================================================================
#  UDEV 
# ==============================================================================
setup_devtmpfs() {
	newdev=/tmp/dev
	mkdir -p "$newdev"
	mount -t devtmpfs none "$newdev"
	mount --move /dev/console "$newdev/console"
	mount --move /dev/mqueue "$newdev/mqueue"
	mount --move /dev/pts "$newdev/pts"
	mount --move /dev/shm "$newdev/shm"
	umount /dev
	mount --move "$newdev" /dev
	ln -sf /dev/pts/ptmx /dev/ptmx
}

setup_devtmpfs

unshare --net /lib/systemd/systemd-udevd --daemon
udevadm control --reload-rules
udevadm trigger 
udevadm settle


# Set up the directory structure and permissions
# It must be owned by the user (root in this case) and have 0700 permissions.
echo "Setting up XDG_RUNTIME_DIR at $XDG_RUNTIME_DIR..."
mkdir -p "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"
ARGS="--idle-time=0 --socket=$SOCKET_NAME"

# Conditionally enable Debug Mode and Export Version
if [ "$WESTON_DEBUG" == "true" ]; then
    echo "[INFO] Enabling Weston Debug Mode (Screenshooter authorized)"
    ARGS="$ARGS --debug"

    # Export version ONLY if debug is on
    echo "Exporting Weston version to shared volume..."
    weston --version > "$XDG_RUNTIME_DIR/weston_version.txt" 2>&1
fi

echo "--- LAUNCHING WESTON ---"
echo "Command: exec weston $ARGS"

# Replace shell with Weston process
exec weston $ARGS

