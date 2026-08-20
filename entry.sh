#!/bin/bash
set -e

# ==============================================================================
# ENVIRONMENT VARIABLES & DEFAULTS
# ==============================================================================
# Optional unprivileged compositor user. When set (e.g. COMPOSITOR_USER=weston),
# Weston is dropped to this user for the final exec — see the non-root deployment
# in examples/least-privileged-nonroot-compositor. Default unset => Weston runs
# as root (the historical behavior), unchanged.
COMPOSITOR_USER="${COMPOSITOR_USER:-}"

# Define the Runtime Directory. In non-root mode it defaults to /run/user/<uid>
# of the compositor user; otherwise /run/user/0.
if [ -n "$COMPOSITOR_USER" ]; then
    COMPOSITOR_UID="$(id -u "$COMPOSITOR_USER")"
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$COMPOSITOR_UID}"
else
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/0}"
fi
SOCKET_NAME="${SOCKET_NAME:-wayland-0}"
WESTON_DEBUG="${WESTON_DEBUG:-false}"

# Run libseat's embedded seatd as a NON-VT-bound seat by default. A container
# has no VT (/dev/tty0), and a VT-bound seat can never mark the client "active",
# which makes seatd refuse DRM device access (EPERM / "no drm device found").
# Non-VT-bound is the right mode for a single-compositor kiosk. Set
# SEATD_VTBOUND=1 only if you have a real VT and need VT switching.
export SEATD_VTBOUND="${SEATD_VTBOUND:-0}"

# Load Weston configuration defaults from weston-env-defaults.sh
source /etc/weston/weston-env-defaults.sh

# ==============================================================================
# STOP PLYMOUTH (Release DRM Master)
# ==============================================================================
# Plymouth holds the DRM lock on boot. We must tell it to quit so Weston can
# take control of the graphics card.
if [ "$LIBSEAT_BACKEND" = "seatd" ]; then
    echo "INFO: LIBSEAT_BACKEND=seatd; the seatd sidecar owns Plymouth handling. Skipping."
elif [ -e /host/run/dbus/system_bus_socket ]; then
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
# UDEV (optional — dynamic hotplug detection)
# ==============================================================================
# Off by default: devices bind-mounted via `devices:` (e.g. /dev/dri, /dev/input)
# are already present at container start and need no udev. Set UDEV=true only
# if you need to detect devices that are plugged in *after* the container
# starts (e.g. a hot-swappable USB touchscreen, mouse, or keyboard) — this
# requires the container to be run with extra capabilities (CAP_SYS_ADMIN,
# CAP_MKNOD, CAP_DAC_OVERRIDE) or privileged:true. See examples/least-privileged
# and examples/dynamic-hotplug.
UDEV=$(echo "${UDEV:-off}" | tr '[:upper:]' '[:lower:]')
case "$UDEV" in
	1|true) UDEV=on ;;
esac

if [ "$UDEV" == "on" ]; then
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
else
	echo "INFO: UDEV is disabled (default). Devices must be bind-mounted via 'devices:'. Set UDEV=true to enable dynamic hotplug detection."
fi

# Set up the directory structure and permissions
echo "Setting up XDG_RUNTIME_DIR at $XDG_RUNTIME_DIR..."
mkdir -p "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"

# ==============================================================================
# WAIT FOR EXTERNAL SEATD (non-root deployment)
# ==============================================================================
# When using an external seatd broker (LIBSEAT_BACKEND=seatd), the seatd sidecar
# opens the devices and exposes /run/seatd.sock on the shared volume. Wait for it
# before launching Weston so libseat's seatd backend can connect.
if [ "$LIBSEAT_BACKEND" = "seatd" ]; then
    SEATD_SOCK="${SEATD_SOCK:-/run/seatd.sock}"
    echo "Waiting for seatd socket at $SEATD_SOCK..."
    for _ in $(seq 1 30); do
        [ -S "$SEATD_SOCK" ] && break
        sleep 1
    done
    [ -S "$SEATD_SOCK" ] || echo "[WARN] seatd socket not found at $SEATD_SOCK after timeout; Weston will likely fail to start."
fi

# ==============================================================================
# weson configuration
# ==============================================================================
if [ -n "$WESTON_INI_PATH" ] && [ -f "$WESTON_INI_PATH" ]; then
    echo "INFO: WESTON_INI_PATH is set. Bypassing dynamic template generation."
    echo "INFO: Using static configuration file at: $WESTON_INI_PATH"
    
    CONFIG_FILE="$WESTON_INI_PATH"
else
    echo "INFO: Generating dynamic weston.ini from template fragments..."
    
    # Target configuration file
    CONFIG_DIR="${XDG_CONFIG_HOME:-$XDG_RUNTIME_DIR}/weston"
    mkdir -p "$CONFIG_DIR"
    CONFIG_FILE="$CONFIG_DIR/weston.ini"

    # Substitute env vars in .ini.template files via envsubst.
    # We iterate explicitly to ensure a trailing newline separates each fragment,
    # preventing syntax errors if a template file lacks an EOF newline.
    for template in /etc/weston/templates/*.ini.template; do
        cat "$template"
        echo ""
    done | envsubst > "$CONFIG_FILE"
fi

# ==============================================================================
# LAUNCH WESTON
# ==============================================================================
ARGS="--socket=$SOCKET_NAME --config=$CONFIG_FILE"

# Conditionally enable Debug Mode and Export Version
if [ "$WESTON_DEBUG" == "true" ]; then
    echo "[INFO] Enabling Weston Debug Mode"
    ARGS="$ARGS --debug"

    echo "Exporting Weston version to shared volume..."
    weston --version > "$XDG_RUNTIME_DIR/weston_version.txt" 2>&1
fi

# ------------------------------------------------------------------------------
# Non-root launch: drop privileges to COMPOSITOR_USER for the compositor process.
# ------------------------------------------------------------------------------
if [ -n "$COMPOSITOR_USER" ]; then
    # The GL renderer opens the GPU render node directly (not brokered by seatd),
    # so the unprivileged user needs access to it. The render node's group varies
    # by host, so detect its GID at runtime and add the user to it.
    if [ -e /dev/dri/renderD128 ]; then
        RENDER_GID="$(stat -c %g /dev/dri/renderD128)"
        if ! getent group "$RENDER_GID" >/dev/null 2>&1; then
            groupadd -g "$RENDER_GID" render_host
        fi
        usermod -aG "$RENDER_GID" "$COMPOSITOR_USER"
    fi

    # The runtime dir and generated config must be owned by the target user.
    chown -R "$COMPOSITOR_USER" "$XDG_RUNTIME_DIR"

    COMPOSITOR_GID="$(id -g "$COMPOSITOR_USER")"
    echo "--- LAUNCHING WESTON as $COMPOSITOR_USER (uid $COMPOSITOR_UID) ---"
    echo "Command: exec setpriv --reuid $COMPOSITOR_UID --regid $COMPOSITOR_GID --init-groups weston $ARGS"
    exec setpriv --reuid "$COMPOSITOR_UID" --regid "$COMPOSITOR_GID" --init-groups \
        env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
            LIBSEAT_BACKEND="$LIBSEAT_BACKEND" \
            SEATD_VTBOUND="$SEATD_VTBOUND" \
            weston $ARGS
fi

echo "--- LAUNCHING WESTON ---"
echo "Command: exec weston $ARGS"

exec weston $ARGS