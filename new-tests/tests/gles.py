"""
OpenGL ES benchmark tests using glmark2-es2-wayland.

Each test runs one glmark2 scene for a configurable duration (config.TEST_DURATION),
captures a screenshot at the halfway point, and returns the full raw output for
display in the UI. No FPS parsing is performed — status is based on exit code only.

GALLIUM_HUD="fps,cpu" is set so the HUD overlay appears in screenshots.
"""

import os
import subprocess
import time
from datetime import datetime, timezone

import config
from screenshot import capture_screenshot
from tests.result import TestResult


def run_gles_texture() -> TestResult:
    return _run_glmark_scene(
        test_id="gles_texture",
        test_name="GLES Texture Fill",
        scene_params="texture:texture-filter=linear",
    )


def run_gles_shading() -> TestResult:
    return _run_glmark_scene(
        test_id="gles_shading",
        test_name="GLES Shading (Phong)",
        scene_params="shading:shading=phong",
    )


def run_gles_jellyfish() -> TestResult:
    return _run_glmark_scene(
        test_id="gles_jellyfish",
        test_name="GLES Jellyfish",
        scene_params="jellyfish",
    )


def _run_glmark_scene(test_id: str, test_name: str, scene_params: str) -> TestResult:
    """Run a single glmark2-es2-wayland scene and return a TestResult."""
    started_at = datetime.now(timezone.utc).isoformat()

    cmd = [
        "glmark2-es2-wayland",
        "--size", config.SCREEN_RES,
        "--benchmark", f"{scene_params}:duration={config.TEST_DURATION}",
        "--fullscreen",
        "--swap-mode=fifo",
    ]
    env = {
        **os.environ,
        "GALLIUM_HUD": "fps,cpu",
        "WAYLAND_DISPLAY": config.WAYLAND_DISPLAY,
        "XDG_RUNTIME_DIR": config.XDG_RUNTIME_DIR,
    }

    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            env=env,
            text=True,
        )
    except FileNotFoundError:
        return TestResult(
            test_id=test_id,
            test_name=test_name,
            group="OpenGL ES",
            status="skip",
            raw_output="glmark2-es2-wayland not found.",
            screenshot_b64=None,
            extra={},
            started_at=started_at,
            finished_at=datetime.now(timezone.utc).isoformat(),
            error_message="Tool not installed.",
        )

    time.sleep(config.SCREENSHOT_DELAY)
    screenshot_b64 = capture_screenshot()

    raw_output, _ = proc.communicate()
    finished_at = datetime.now(timezone.utc).isoformat()

    # Status is based purely on the tool's exit code, not on parsed output.
    status = "pass" if proc.returncode == 0 else "fail"

    # Software renderer check — informational only, does not affect status.
    extra = {}
    warning = _check_software_renderer(raw_output)
    if warning:
        extra["sw_warning"] = warning

    return TestResult(
        test_id=test_id,
        test_name=test_name,
        group="OpenGL ES",
        status=status,
        raw_output=raw_output or "",
        screenshot_b64=screenshot_b64,
        extra=extra,
        started_at=started_at,
        finished_at=finished_at,
        error_message=None,
    )


def _check_software_renderer(output: str) -> str | None:
    """
    Return a warning string if a known software renderer name is found in the output.
    Used to alert the user that hardware acceleration may not be active.
    Does not affect the test status.
    """
    for name in ("llvmpipe", "softpipe", "lavapipe"):
        if name in output:
            return f"Software renderer detected ({name})"
    return None
