"""
Video playback tests using mpv.

Each test plays a video file for a fixed duration, captures a screenshot
partway through, then stops mpv. The full log output is returned for display.

Hardware decoder selection follows the same logic as the original bash tests:
  - HWDEC env var (if set) overrides everything
  - raspberry* devices → v4l2m2m
  - jetson* devices    → nvdec
  - everything else    → auto
"""

import os
import subprocess
import tempfile
import time
from datetime import datetime, timezone

import config
from screenshot import capture_screenshot
from tests.result import TestResult

VIDEO_H264_720P  = os.path.join(config.ASSETS_DIR, "video_test_h264_720p30.mp4")
VIDEO_H264_1080P = os.path.join(config.ASSETS_DIR, "video_test_h264_1080p60.mp4")
VIDEO_H265_1080P = os.path.join(config.ASSETS_DIR, "video_test_h265_1080p60.mp4")


def run_video_h264_720p30() -> TestResult:
    return _run_video(
        test_id="video_h264_720p30",
        test_name="H.264 720p 30fps",
        file_path=VIDEO_H264_720P,
    )


def run_video_h264_1080p60() -> TestResult:
    return _run_video(
        test_id="video_h264_1080p60",
        test_name="H.264 1080p 60fps",
        file_path=VIDEO_H264_1080P,
    )


def run_video_h265_1080p60() -> TestResult:
    return _run_video(
        test_id="video_h265_1080p60",
        test_name="H.265 1080p 60fps",
        file_path=VIDEO_H265_1080P,
    )


def _run_video(test_id: str, test_name: str, file_path: str) -> TestResult:
    """
    Play a video with mpv, capture a screenshot mid-playback, then stop.
    Returns a TestResult with the full mpv log as raw_output.
    """
    started_at = datetime.now(timezone.utc).isoformat()

    if not os.path.isfile(file_path):
        return TestResult(
            test_id=test_id,
            test_name=test_name,
            group="Video",
            status="skip",
            raw_output=f"Video file not found: {file_path}",
            screenshot_b64=None,
            extra={},
            started_at=started_at,
            finished_at=datetime.now(timezone.utc).isoformat(),
            error_message="Video file missing.",
        )

    hwdec = _get_hwdec_setting()

    # Write all output (stdout, stderr, and mpv log) to a temp file.
    # Using a regular file avoids pipe buffer issues with verbose mpv output.
    log_fd, log_path = tempfile.mkstemp(prefix=f"mpv_{test_id}_", suffix=".log")
    os.close(log_fd)

    cmd = [
        "mpv",
        file_path,
        "--vo=gpu",
        "--gpu-context=wayland",
        f"--hwdec={hwdec}",
        "--fullscreen",
        "--no-config",
        "--no-osc",
        "--gpu-dumb-mode=yes",
        f"--log-file={log_path}",
        "--msg-level=vd=info,ffmpeg=info,hwdec=debug,vo=info",
        "--term-status-msg=Status: fps=${estimated-vf-fps}, drops=${frame-drop-count}, "
        "codec=${video-codec}, hwdec=${hwdec-current}",
    ]
    env = {
        **os.environ,
        "WAYLAND_DISPLAY": config.WAYLAND_DISPLAY,
        "XDG_RUNTIME_DIR": config.XDG_RUNTIME_DIR,
    }

    try:
        # Redirect mpv's terminal output to the log file as well, to capture
        # --term-status-msg lines (which go to stderr, not --log-file).
        with open(log_path, "a") as log_file:
            proc = subprocess.Popen(
                cmd,
                stdout=log_file,
                stderr=log_file,
                env=env,
            )
    except FileNotFoundError:
        os.unlink(log_path)
        return TestResult(
            test_id=test_id,
            test_name=test_name,
            group="Video",
            status="skip",
            raw_output="mpv not found.",
            screenshot_b64=None,
            extra={},
            started_at=started_at,
            finished_at=datetime.now(timezone.utc).isoformat(),
            error_message="Tool not installed.",
        )

    # Phase 1: wait for playback to stabilise, then capture a screenshot.
    time.sleep(config.MPV_SCREENSHOT_DELAY)
    screenshot_b64 = capture_screenshot()

    # Phase 2: let playback continue, then stop mpv.
    remaining = config.MPV_PLAY_DURATION - config.MPV_SCREENSHOT_DELAY
    time.sleep(remaining)
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()

    finished_at = datetime.now(timezone.utc).isoformat()

    try:
        with open(log_path) as f:
            raw_output = f.read()
    except OSError:
        raw_output = "Could not read mpv log."
    finally:
        try:
            os.unlink(log_path)
        except OSError:
            pass

    extra = _parse_status(raw_output)
    status = "pass" if extra else "fail"

    return TestResult(
        test_id=test_id,
        test_name=test_name,
        group="Video",
        status=status,
        raw_output=raw_output,
        screenshot_b64=screenshot_b64,
        extra=extra,
        started_at=started_at,
        finished_at=finished_at,
        error_message=None,
    )


def _get_hwdec_setting() -> str:
    """
    Determine the hardware decoder to use.
    Explicit HWDEC env var takes priority, then device type heuristic.
    """
    hwdec_env = os.environ.get("HWDEC", "")
    if hwdec_env:
        return hwdec_env

    device_type = config.BALENA_DEVICE_TYPE.lower()
    if device_type.startswith("raspberry"):
        return "v4l2m2m"
    if device_type.startswith("jetson"):
        return "nvdec"
    return "auto"


def _parse_status(output: str) -> dict:
    """
    Try to extract FPS and hardware decoder from the last mpv status line.
    Status lines look like:
      Status: fps=59.94, drops=0, codec=h264, hwdec=v4l2m2m
    Returns a dict with "fps" and "decoder" if found, otherwise {}.
    """
    import re
    # Find the last line that matches the status message format with a real FPS value.
    status_line = None
    for line in reversed(output.splitlines()):
        if re.search(r"Status: fps=[0-9]", line):
            status_line = line
            break

    if status_line is None:
        return {}

    result = {}
    fps_match = re.search(r"fps=([0-9.]+)", status_line)
    if fps_match:
        result["fps"] = fps_match.group(1)

    hwdec_match = re.search(r"hwdec=([^,\s]+)", status_line)
    if hwdec_match:
        result["decoder"] = hwdec_match.group(1)

    return result
