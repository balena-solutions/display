#!/bin/bash
set -e

# ==============================================================================
# ENVIRONMENT VARIABLES & DEFAULTS
# ==============================================================================
# Define the Runtime Directory
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/0}"
SOCKET_NAME="${SOCKET_NAME:-wayland-0}"
WESTON_DEBUG="${WESTON_DEBUG:-false}"

# Load Weston configuration defaults from weston-env-defaults.sh
source /etc/weston/weston-env-defaults.sh

# ==============================================================================
# DEFAULT OUTPUT DETECTION
# ==============================================================================
# Weston's [output] section keys on the connector name (e.g. HDMI-A-1, DSI-1),
# which differs per platform/GPU. To keep the public DISPLAY_* geometry vars
# generic, we auto-detect the connected connector(s) and apply the config to the
# FIRST connected one. Multi-display targeting is intentionally out of scope for
# now (see docs/todo-multi-display.md).
detect_connected_outputs() {            # echoes Weston output names, one per line
    for status in /sys/class/drm/card*-*/status; do
        [ -e "$status" ] || continue
        [ "$(cat "$status")" = "connected" ] || continue
        conn=$(basename "$(dirname "$status")")   # e.g. card0-HDMI-A-1
        name="${conn#card*-}"                       # -> HDMI-A-1 (Weston output name)
        case "$name" in Writeback-*) continue ;; esac  # skip virtual connectors
        echo "$name"
    done
}

CONNECTED_OUTPUTS=$(detect_connected_outputs)
if [ -n "$CONNECTED_OUTPUTS" ]; then
    echo "Connected display outputs detected:"
    echo "$CONNECTED_OUTPUTS" | sed 's/^/  - /'
    export WESTON_INI_OUTPUT_NAME=$(echo "$CONNECTED_OUTPUTS" | head -n1)
    echo "Applying display geometry (rotation/resolution/scale) to: $WESTON_INI_OUTPUT_NAME"
    if [ "$(echo "$CONNECTED_OUTPUTS" | wc -l)" -gt 1 ]; then
        echo "[NOTE] Multiple displays connected. Only '$WESTON_INI_OUTPUT_NAME' is configured;"
        echo "       For custom multi-output layouts, provide your own weston.ini via WESTON_INI_PATH."
    fi
else
    echo "[WARN] No connected display outputs detected; skipping [output] configuration."
    export WESTON_INI_OUTPUT_NAME=""
fi

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
# UDEV 
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
echo "Setting up XDG_RUNTIME_DIR at $XDG_RUNTIME_DIR..."
mkdir -p "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"

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
        # The [output] fragment requires a connector name; skip it when no display
        # was detected (headless) so Weston doesn't reject an empty 'name='.
        if [ "$(basename "$template")" = "04-output.ini.template" ] && [ -z "$WESTON_INI_OUTPUT_NAME" ]; then
            continue
        fi
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

echo "--- LAUNCHING WESTON ---"
echo "Command: exec weston $ARGS"

exec weston $ARGS