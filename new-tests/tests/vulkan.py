"""
Vulkan benchmark tests using vkmark.

Follows the same structure as gles.py: one scene per test function,
screenshot mid-run, full raw output returned for display in the UI.

Skipped gracefully if vkmark is not installed.
"""

import dataclasses
import os
import subprocess
import time
from datetime import datetime, timezone

import config
from screenshot import capture_screenshot
from tests.result import TestResult


def run_vulkan_vertex() -> TestResult:
    return _run_vkmark_scene(
        test_id="vulkan_vertex",
        test_name="Vulkan Vertex",
        scene_params="vertex",
    )


def run_vulkan_texture() -> TestResult:
    return _run_vkmark_scene(
        test_id="vulkan_texture",
        test_name="Vulkan Texture",
        scene_params="texture",
    )


def run_vulkan_shading() -> TestResult:
    return _run_vkmark_scene(
        test_id="vulkan_shading",
        test_name="Vulkan Shading",
        scene_params="shading",
    )


def _run_vkmark_scene(test_id: str, test_name: str, scene_params: str) -> TestResult:
    """Run a single vkmark scene and return a TestResult."""
    started_at = datetime.now(timezone.utc).isoformat()

    cmd = [
        "vkmark",
        "--present-mode=fifo",
        "--size", config.SCREEN_RES,
        "--benchmark", f"{scene_params}:duration={config.VKMARK_DURATION}",
    ]
    env = {
        **os.environ,
        "VK_INSTANCE_LAYERS": "VK_LAYER_MESA_overlay",
        "VK_LAYER_MESA_OVERLAY_CONFIG": "fps=1",
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
            group="Vulkan",
            status="skip",
            raw_output="vkmark not found.",
            screenshot_b64=None,
            extra={},
            started_at=started_at,
            finished_at=datetime.now(timezone.utc).isoformat(),
            error_message="Tool not installed.",
        )

    time.sleep(config.VKMARK_SCREENSHOT_DELAY)
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
        group="Vulkan",
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
    Try to extract an FPS value from vkmark output.
    vkmark may output 'FPS: 123' or 'Score: 123'.
    Returns {"fps": <int>} if found, otherwise {}.
    """
    import re
    # Try 'FPS: 123' first
    m = re.search(r"FPS:\s*(\d+)", output)
    if m:
        return {"fps": int(m.group(1))}
    # Fall back to 'Score: 123'
    m = re.search(r"Score:\s*(\d+)", output)
    if m:
        return {"fps": int(m.group(1))}
    return {}
