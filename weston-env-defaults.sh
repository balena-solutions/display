#!/bin/bash
# Defines fallback values for the Weston configuration templates.

# ==============================================================================
# DEFAULT TEMPLATE VALUES
# ==============================================================================

# [core]
export WESTON_INI_CORE_SHELL="${WESTON_INI_CORE_SHELL:-kiosk}"
export WESTON_INI_CORE_IDLE_TIME="${WESTON_INI_CORE_IDLE_TIME:-0}"
export WESTON_INI_CORE_REQUIRE_INPUT="${WESTON_INI_CORE_REQUIRE_INPUT:-false}"

# [shell]
export WESTON_INI_SHELL_LOCKING="${WESTON_INI_SHELL_LOCKING:-false}"
export WESTON_INI_SHELL_PANEL_POSITION="${WESTON_INI_SHELL_PANEL_POSITION:-none}"

# [libinput] is explicitly hardcoded in its template and requires no variables.