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