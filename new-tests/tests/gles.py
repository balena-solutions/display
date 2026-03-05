"""
OpenGL ES benchmark tests using glmark2-es2-wayland.

Each test runs one glmark2 scene for a fixed duration, captures a screenshot
mid-run, and returns the full raw output for display in the UI.

FPS parsing is opportunistic: if the 'Score:' line is present and parseable,
the score is stored in extra["fps"]. A failed parse does not affect the
test status — the raw output is always available.
"""

import dataclasses
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
        "--benchmark", f"{scene_params}:duration={config.GLMARK_DURATION}",
        "--fullscreen",
        "--swap-mode=fifo",
    ]
    env = {
        **os.environ,
        "GALLIUM_HUD": "fps",
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

    time.sleep(config.GLMARK_SCREENSHOT_DELAY)
    screenshot_b64 = capture_screenshot()

    raw_output, _ = proc.communicate()
    finished_at = datetime.now(timezone.utc).isoformat()

    extra = _parse_fps(raw_output)

    if proc.returncode == 0:
        status = "pass"
    else:
        status = "fail"

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


def _parse_fps(output: str) -> dict:
    """
    Try to extract the glmark2 composite score from output.
    Returns {"fps": <int>} if found, otherwise {}.
    """
    for line in reversed(output.splitlines()):
        if "Score:" in line:
            parts = line.split("Score:")
            if len(parts) == 2:
                score_str = parts[1].strip().split()[0] if parts[1].strip() else ""
                if score_str.isdigit():
                    return {"fps": int(score_str)}
    return {}
