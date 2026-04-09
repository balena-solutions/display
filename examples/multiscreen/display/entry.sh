#!/bin/bash
set -e

MULTISCREEN_ENABLED=${MULTISCREEN_ENABLED:-"1"}
PRIMARY_MODE=${PRIMARY_MODE:-"current"}
SECONDARY_MODE=${SECONDARY_MODE:-"1920x1080"}

# ==============================================================================
# AUTO-DETECT CONNECTED OUTPUTS
# ==============================================================================
# /sys/class/drm/ is accessible in privileged containers before udev runs.
# Connector paths look like: /sys/class/drm/card1-DSI-1/status
# We strip the "cardN-" prefix to get the weston output name (e.g. "DSI-1").

DETECTED_OUTPUTS=()
for path in /sys/class/drm/card*-*/status; do
    [ -f "$path" ] || continue
    [ "$(cat "$path")" = "connected" ] || continue
    connector=$(basename "$(dirname "$path")")
    # Strip cardN- prefix: card1-HDMI-A-1 -> HDMI-A-1
    name=$(echo "$connector" | cut -d'-' -f2-)
    # Skip virtual connectors (e.g. Writeback-1 on RPi4)
    case "$name" in Writeback*) continue ;; esac
    DETECTED_OUTPUTS+=("$name")
done

echo "[INFO] Detected connected outputs: ${DETECTED_OUTPUTS[*]:-none}"

# PRIMARY_DISPLAY / SECONDARY_DISPLAY can be set explicitly to control which
# physical output takes each role. If unset, the first and second detected
# connected outputs are used.
PRIMARY_DISPLAY=${PRIMARY_DISPLAY:-${DETECTED_OUTPUTS[0]:-}}
SECONDARY_DISPLAY=${SECONDARY_DISPLAY:-${DETECTED_OUTPUTS[1]:-}}

if [ -z "$PRIMARY_DISPLAY" ]; then
    echo "[WARN] No connected displays detected and PRIMARY_DISPLAY not set. Weston will use defaults."
fi

if [ -z "$SECONDARY_DISPLAY" ]; then
    echo "[INFO] No secondary display detected. Disabling multiscreen."
    MULTISCREEN_ENABLED=0
fi

# ==============================================================================
# AUTO-SELECT RENDERER
# ==============================================================================
# On Raspberry Pi with multiscreen enabled, default to pixman to avoid a known
# DRM cursor plane crash in the RPi GPU driver.
# See: https://github.com/agherzan/meta-raspberrypi/issues/1407
#
# Override by setting WESTON_RENDERER explicitly:
#   WESTON_RENDERER=gl     — force hardware rendering
#   WESTON_RENDERER=pixman — force software rendering

if [ -z "${WESTON_RENDERER:-}" ]; then
    if echo "${BALENA_MACHINE_NAME:-}" | grep -qi "raspberry" && [ "$MULTISCREEN_ENABLED" = "1" ]; then
        WESTON_RENDERER="pixman"
        echo "[INFO] Raspberry Pi + multiscreen detected: defaulting WESTON_RENDERER=pixman"
        echo "[INFO] Set WESTON_RENDERER=gl to override"
    fi
fi

# ==============================================================================
# ROTATION HELPER
# ==============================================================================
# Per-display rotation is configured via an env var named after the output,
# uppercased with hyphens replaced by underscores, prefixed with ROTATION_.
#
#   DSI-1    → ROTATION_DSI_1=rotate-90
#   HDMI-A-1 → ROTATION_HDMI_A_1=rotate-180
#
# Valid values: normal | rotate-90 | rotate-180 | rotate-270

get_rotation() {
    local display="$1"
    local varname="ROTATION_$(echo "$display" | tr '[:lower:]-' '[:upper:]_')"
    echo "${!varname:-normal}"
}

# ==============================================================================
# GENERATE WESTON.INI
# ==============================================================================
# desktop-shell.so gives each window a title bar so it can be dragged between
# outputs. kiosk-shell.so (the default) would lock apps fullscreen to one output.

cat > /etc/xdg/weston/weston.ini << 'WESTONEOF'
[core]
shell=desktop-shell.so
idle-time=0
require-input=false
WESTONEOF

if [ -n "${WESTON_RENDERER:-}" ]; then
    echo "renderer=${WESTON_RENDERER}" >> /etc/xdg/weston/weston.ini
fi

cat >> /etc/xdg/weston/weston.ini << 'WESTONEOF'

[shell]
locking=false
panel-position=top
WESTONEOF

if [ -n "$PRIMARY_DISPLAY" ]; then
    PRIMARY_ROTATION=$(get_rotation "$PRIMARY_DISPLAY")
    cat >> /etc/xdg/weston/weston.ini << EOF

[output]
name=${PRIMARY_DISPLAY}
mode=${PRIMARY_MODE}
position=0,0
transform=${PRIMARY_ROTATION}
EOF
fi

if [ "${MULTISCREEN_ENABLED}" = "1" ] && [ -n "$SECONDARY_DISPLAY" ]; then
    # Determine the x-offset for the secondary output.
    # If PRIMARY_MODE=current we don't know the resolution upfront, so we read
    # the connector's preferred mode from sysfs. Fall back to 1920 if unreadable.
    if [ "$PRIMARY_MODE" = "current" ] || [ -z "$PRIMARY_MODE" ]; then
        PRIMARY_WIDTH=$(cat /sys/class/drm/card*-"${PRIMARY_DISPLAY}"/modes 2>/dev/null \
            | head -1 | cut -dx -f1 || true)
    else
        PRIMARY_WIDTH=$(echo "$PRIMARY_MODE" | cut -dx -f1)
    fi
    PRIMARY_WIDTH=${PRIMARY_WIDTH:-1920}

    SECONDARY_ROTATION=$(get_rotation "$SECONDARY_DISPLAY")
    cat >> /etc/xdg/weston/weston.ini << EOF

[output]
name=${SECONDARY_DISPLAY}
mode=${SECONDARY_MODE}
position=${PRIMARY_WIDTH},0
transform=${SECONDARY_ROTATION}
EOF
    echo "[INFO] Multiscreen: ${PRIMARY_DISPLAY} (${PRIMARY_MODE}, rot=${PRIMARY_ROTATION}) + ${SECONDARY_DISPLAY} (${SECONDARY_MODE}, rot=${SECONDARY_ROTATION}) at x=${PRIMARY_WIDTH}"
    [ -n "${WESTON_RENDERER:-}" ] && echo "[INFO] Renderer: ${WESTON_RENDERER}"
else
    echo "[INFO] Single-screen mode: ${PRIMARY_DISPLAY:-default}"
fi

echo "--- Generated weston.ini ---"
cat /etc/xdg/weston/weston.ini
echo "----------------------------"

# ==============================================================================
# HAND OFF TO PARENT ENTRY SCRIPT
# ==============================================================================
# Reuse Plymouth stop, udev setup, and Weston launch from the base image.
exec /usr/bin/entry.sh
