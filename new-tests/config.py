"""
Central configuration constants.

Tests and other modules import from here rather than using magic strings.
Values that vary by environment are read from env vars with sensible defaults.
"""

import os

# Wayland / runtime
WAYLAND_DISPLAY = os.environ.get("WAYLAND_DISPLAY", "wayland-0")
XDG_RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", "/run/user/0")
WAYLAND_SOCKET = os.path.join(XDG_RUNTIME_DIR, WAYLAND_DISPLAY)

# Paths
ASSETS_DIR = "/usr/src/app/assets"
DATA_DIR = "/data"
REPORTS_DIR = "/data/reports"
SCREENSHOT_DIR = "/tmp/screenshots"

# Screen resolution — updated at runtime after wayland-info detection.
# Tests use this for --size arguments.
SCREEN_RES = os.environ.get("SCREEN_RES", "1280x720")

# Test duration (seconds). Applies to all benchmark and video tests.
# Can be overridden at runtime via the web UI or the TEST_DURATION env var.
TEST_DURATION = int(os.environ.get("TEST_DURATION", 10))

# Screenshot is always taken at the halfway point of the test duration.
# Recomputed whenever TEST_DURATION is updated via the /settings route.
SCREENSHOT_DELAY = TEST_DURATION // 2

# Subprocess timeout for diagnostic tools (seconds)
TOOL_TIMEOUT = 15

# Auto-run mode: run all tests on startup and export PDF, then exit.
# Set AUTO_RUN=1 env var or pass --auto flag to run.py.
AUTO_RUN = os.environ.get("AUTO_RUN", "0") == "1"

# Balena environment
BALENA_DEVICE_TYPE = os.environ.get("BALENA_DEVICE_TYPE", "")
BALENA_HOST_OS_VERSION = os.environ.get("BALENA_HOST_OS_VERSION", "")
