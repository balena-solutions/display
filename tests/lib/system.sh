#!/bin/bash

detect_display() {
    log "--- WAITING FOR WAYLAND SOCKET ---"
    while [ ! -e "$SOCKET" ]; do sleep 1; done
    log "Socket found."

    OUTPUT_NAME=$(wayland-info 2>/dev/null | grep -A 10 "interface: 'wl_output'" | grep -E "^\s+name:" | awk '{print $2}' | head -n 1)
    OUTPUT_NAME=${OUTPUT_NAME:-"UNKNOWN_DISPLAY"}

    SCREEN_RES=$(wayland-info 2>/dev/null | grep -B 1 "flags:.*current" | head -n 1 | awk '{print $2"x"$5}')
    if [[ ! "$SCREEN_RES" =~ ^[0-9]+x[0-9]+$ ]]; then
        log "[WARN] Could not detect resolution. Defaulting to 800x480."
        SCREEN_RES="800x480"
    fi

    log "DISPLAY OUTPUT: $OUTPUT_NAME"
    log "DETECTED RESOLUTION: $SCREEN_RES"
    
    export OUTPUT_NAME
    export SCREEN_RES
}

get_pkg_ver() { dpkg-query -f '${Version}' -W "$1" 2>/dev/null || echo "Unknown"; }

# Gather variables in main shell scope so they persist
gather_system_info() {
    export KERNEL_VER=$(uname -r)
    export MESA_VER=$(get_pkg_ver libgl1-mesa-dri)
    export GLMARK_VER=$(get_pkg_ver glmark2-es2-wayland)
    export VKMARK_VER=$(get_pkg_ver vkmark)
    export WESTON_VER=$(cat /run/user/0/weston_version.txt 2>/dev/null | head -n 1 | awk '{print $2}')
    [ -z "$WESTON_VER" ] && export WESTON_VER="Unknown"
    export DEVICE_MODEL=$(cat /sys/firmware/devicetree/base/model 2>/dev/null | tr -d '\0')
}

print_diagnostics() {
    echo "=== DEVICE INFO ==="
    echo "Model: ${DEVICE_MODEL:-Generic}"
    echo "Balena Device Type: ${BALENA_DEVICE_TYPE:-N/A}"
    echo "Balena Host OS: ${BALENA_HOST_OS_VERSION:-N/A}"
    echo ""
    echo "=== KERNEL ==="
    uname -a
    echo ""
    echo "=== GRAPHICS (VULKAN) ==="
    vulkaninfo --summary 2>/dev/null | grep -E "deviceName|driverID|driverInfo|apiVersion"
    echo ""
    echo "=== GRAPHICS (EGL) ==="
    glmark2-es2-wayland --validate 2>&1 | grep -E "GL_VENDOR|GL_RENDERER|GL_VERSION"
    echo ""
    echo "=== WAYLAND INFO (RAW) ==="
    wayland-info 2>/dev/null
}

run_preflight() {
    log "--- HARDWARE PRE-FLIGHT CHECKS ---"
    if lsmod | grep -E "v3d|vc4|i915|xe|amdgpu" > /dev/null; then
        log "[PASS] Graphics kernel module detected."
    else
        log "[FAIL] No supported graphics kernel module found."
    fi

    if command -v vkmark > /dev/null; then
        log "[PASS] 'vkmark' tool found."
    else
        log "[FAIL] 'vkmark' missing."
    fi
    log "--------------------------------------------------------------------------------"
}