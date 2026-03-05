"""
Screenshot capture via weston-screenshooter.

weston-screenshooter writes a PNG named 'screenshot.png' into the current
working directory. We run it from a dedicated temp dir to contain the file,
then base64-encode and return it.

Requires weston to be started with --debug (WESTON_DEBUG=true in docker-compose).
Returns None if capture fails for any reason — the test still records raw output.
"""

import base64
import glob
import os
import subprocess

import config


def capture_screenshot() -> str | None:
    """
    Run weston-screenshooter, read the produced PNG, return a base64 string.
    Returns None if the screenshot could not be captured.
    """
    os.makedirs(config.SCREENSHOT_DIR, exist_ok=True)

    # Remove any stale PNGs from a previous capture in this dir.
    for existing in glob.glob(os.path.join(config.SCREENSHOT_DIR, "*.png")):
        os.remove(existing)

    env = {
        **os.environ,
        "WAYLAND_DISPLAY": config.WAYLAND_DISPLAY,
        "XDG_RUNTIME_DIR": config.XDG_RUNTIME_DIR,
    }

    try:
        subprocess.run(
            ["weston-screenshooter"],
            cwd=config.SCREENSHOT_DIR,
            env=env,
            capture_output=True,
            timeout=10,
        )
    except FileNotFoundError:
        return None
    except subprocess.TimeoutExpired:
        return None

    pngs = glob.glob(os.path.join(config.SCREENSHOT_DIR, "*.png"))
    if not pngs:
        return None

    png_path = pngs[0]
    try:
        with open(png_path, "rb") as f:
            data = base64.b64encode(f.read()).decode("ascii")
        os.remove(png_path)
        return data
    except OSError:
        return None
