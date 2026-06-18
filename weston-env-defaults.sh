#!/bin/bash
# Translates abstract public DISPLAY_* variables to internal WESTON_INI_* templates.

# ==============================================================================
# DEFAULT TEMPLATE VALUES
# ==============================================================================

# [core]
export WESTON_INI_CORE_SHELL="${DISPLAY_UX_MODE:-kiosk}"
export WESTON_INI_CORE_IDLE_TIME="${DISPLAY_IDLE_TIMEOUT:-0}"
export WESTON_INI_CORE_REQUIRE_INPUT="${DISPLAY_REQUIRE_INPUT:-false}"

# [shell]
export WESTON_INI_SHELL_LOCKING="${DISPLAY_ALLOW_LOCKING:-false}"
export WESTON_INI_SHELL_PANEL_POSITION="${DISPLAY_PANEL_POSITION:-none}"

# [libinput] is explicitly hardcoded in its template and requires no variables.

# [output]
# DISPLAY_ROTATION is the public, compositor-agnostic knob: it rotates the displayed
# CONTENT by N degrees CLOCKWISE (0/90/180/270). This matches what every end-user
# display setting does (macOS, Windows, GNOME) and the v2 block's xrandr behavior.
#
# IMPORTANT — direction inversion (do not "fix" this back):
# Weston's `transform` does NOT rotate content. Per `man weston.ini`, it describes
# "how you have rotated your MONITOR from its normal orientation", and Weston then
# counter-rotates the framebuffer to compensate. So `transform=rotate-90` ("monitor
# turned 90° CW") makes the visible content appear rotated 90° COUNTER-clockwise.
# (Verified on device; the `wl_output.transform` protocol that sway/wlroots also use
# shares this panel-orientation convention, so the inversion is not Weston-specific.)
# To honor our content-clockwise contract we therefore map to the OPPOSITE token:
#   DISPLAY_ROTATION=90  (content CW)  -> rotate-270
#   DISPLAY_ROTATION=270 (content CCW) -> rotate-90
# 0 and 180 are direction-agnostic and map straight through.
case "${DISPLAY_ROTATION:-0}" in
  0)    export WESTON_INI_OUTPUT_TRANSFORM="normal" ;;
  90)   export WESTON_INI_OUTPUT_TRANSFORM="rotate-270" ;;
  180)  export WESTON_INI_OUTPUT_TRANSFORM="rotate-180" ;;
  270)  export WESTON_INI_OUTPUT_TRANSFORM="rotate-90" ;;
  *)    echo "[WARN] Invalid DISPLAY_ROTATION='${DISPLAY_ROTATION}' (expected 0/90/180/270); using 0"
        export WESTON_INI_OUTPUT_TRANSFORM="normal" ;;
esac
# DISPLAY_RESOLUTION is the generic public form (WIDTHxHEIGHT). When unset we fall
# back to Weston's "preferred" keyword (the EDID-preferred mode) internally — that
# keyword is a Weston detail and is intentionally kept out of the public interface.
export WESTON_INI_OUTPUT_MODE="${DISPLAY_RESOLUTION:-preferred}"
export WESTON_INI_OUTPUT_SCALE="${DISPLAY_SCALE:-1}"