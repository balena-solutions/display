"""
System information collection.

Each field is collected by a separate function so one failure does not
affect the rest. Subprocess calls are used only where Python stdlib is
insufficient (display info, GPU info, package versions).
"""

import os
import platform
import re
import shutil
import subprocess

import config


def collect() -> dict:
    """Collect all system info. Returns a flat dict. Fields may be None on failure."""
    return {
        "os":              _get_os_info(),
        "kernel":          _get_kernel(),
        "device_model":    _get_device_model(),
        "device_type":     config.BALENA_DEVICE_TYPE or "Unknown",
        "balena_os":       config.BALENA_HOST_OS_VERSION or "Unknown",
        "ram":             _get_ram(),
        "storage":         _get_storage(),
        "display":         _get_display_info(),
        "opengl":          _get_opengl_info(),
        "vulkan":          _get_vulkan_info(),
        "video_decode":    _get_video_decode_info(),
        "mesa_version":    _get_dpkg_version("libgl1-mesa-dri"),
        "weston_version":  _get_weston_version(),
        "glmark2_version": _get_dpkg_version("glmark2-es2-wayland"),
        "vkmark_version":  _get_dpkg_version("vkmark"),
        "gpu_modules":     _get_gpu_modules(),
    }


def _get_os_info() -> dict:
    """Parse /etc/os-release — pure Python, no subprocess."""
    fields = {}
    try:
        with open("/etc/os-release") as f:
            for line in f:
                line = line.strip()
                if "=" in line:
                    key, _, value = line.partition("=")
                    fields[key] = value.strip('"')
    except OSError:
        pass
    return {
        "name":    fields.get("NAME", "Unknown"),
        "version": fields.get("VERSION_ID", fields.get("VERSION", "Unknown")),
        "pretty":  fields.get("PRETTY_NAME", "Unknown"),
    }


def _get_kernel() -> str:
    """platform.uname() — pure Python, no subprocess."""
    u = platform.uname()
    return f"{u.system} {u.release} {u.machine}"


def _get_device_model() -> str:
    """
    Try ARM device tree model first, then x86 /proc/cpuinfo model name,
    then fall back to the BALENA_DEVICE_TYPE env var.
    """
    try:
        with open("/sys/firmware/devicetree/base/model", "rb") as f:
            return f.read().rstrip(b"\x00").decode("utf-8", errors="replace")
    except OSError:
        pass

    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if line.startswith("model name"):
                    return line.split(":", 1)[1].strip()
    except OSError:
        pass

    return config.BALENA_DEVICE_TYPE or "Unknown"


def _get_ram() -> dict:
    """Parse /proc/meminfo — pure Python, no subprocess."""
    mem = {}
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 2:
                    mem[parts[0].rstrip(":")] = int(parts[1])
    except OSError:
        return {"total_mb": None, "free_mb": None, "available_mb": None, "used_mb": None}

    total     = mem.get("MemTotal", 0) // 1024
    available = mem.get("MemAvailable", 0) // 1024
    return {
        "total_mb":     total,
        "free_mb":      mem.get("MemFree", 0) // 1024,
        "available_mb": available,
        "used_mb":      total - available,
    }


def _get_storage() -> dict:
    """shutil.disk_usage() — Python stdlib, no subprocess."""
    try:
        usage = shutil.disk_usage("/")
        return {
            "total_gb": round(usage.total / 1024 ** 3, 1),
            "used_gb":  round(usage.used / 1024 ** 3, 1),
            "free_gb":  round(usage.free / 1024 ** 3, 1),
        }
    except OSError:
        return {"total_gb": None, "used_gb": None, "free_gb": None}


def _get_display_info() -> dict:
    """
    Run wayland-info to detect the connected output name and current resolution.
    Returns a dict with 'output_name', 'resolution', and 'raw' output.
    """
    raw = _run_tool(["wayland-info"])
    if raw is None:
        return {"output_name": "Unknown", "resolution": "Unknown", "raw": "wayland-info not available"}

    output_name = "Unknown"
    resolution = "Unknown"
    lines = raw.splitlines()

    # Find the wl_output section and extract the output name (e.g. HDMI-A-1)
    for i, line in enumerate(lines):
        if "interface: 'wl_output'" in line:
            for j in range(i, min(i + 15, len(lines))):
                m = re.match(r"\s+name:\s+(\S+)", lines[j])
                if m:
                    output_name = m.group(1)
                    break
            break

    # Find the current mode line. wayland-info outputs mode lines like:
    #   width: 1920 px, height: 1080 px, refresh: 60.000 Hz
    #   flags: current preferred
    # We look for a 'flags:' line containing 'current', then look at the
    # preceding line for the width/height values.
    for i, line in enumerate(lines):
        if "flags:" in line and "current" in line:
            if i > 0:
                m = re.search(r"width:\s*(\d+)\s*px.*height:\s*(\d+)\s*px", lines[i - 1])
                if m:
                    resolution = f"{m.group(1)}x{m.group(2)}"
            break

    return {"output_name": output_name, "resolution": resolution, "raw": raw}


def _get_opengl_info() -> dict:
    """
    Run es2_info to get OpenGL ES version and renderer info.
    Falls back to glmark2 --validate if es2_info is not available.
    """
    raw = _run_tool(["es2_info"])
    if raw is None:
        raw = _run_tool(["glmark2-es2-wayland", "--validate"])

    version = "Unknown"
    if raw:
        # If the tool ran but couldn't open a display, give a clear version label
        # rather than "Unknown". The raw output (with the error) is still stored.
        if "couldn't open display" in raw or "unable to open display" in raw.lower():
            version = "N/A (no display at collection time)"
        else:
            m = re.search(r"GL_VERSION[:\s]+(.+)", raw)
            if m:
                version = m.group(1).strip()

    return {"version": version, "raw": raw or "es2_info not available"}


def _get_vulkan_info() -> dict:
    """Run vulkaninfo --summary to get Vulkan driver and API version."""
    raw = _run_tool(["vulkaninfo", "--summary"])

    version = "Unknown"
    if raw:
        m = re.search(r"apiVersion\s*=\s*(\S+)", raw)
        if m:
            version = m.group(1)

    return {"version": version, "raw": raw or "vulkaninfo not available"}


def _get_video_decode_info() -> dict:
    """
    Check hardware video decode support via vainfo.
    Falls back to v4l2-ctl --list-formats-out for V4L2 devices (e.g. Raspberry Pi).
    Shows raw output in the UI rather than parsing.
    """
    raw = _run_tool(["vainfo"])
    if raw is None:
        raw = _run_tool(["v4l2-ctl", "--list-formats-out"])
    return {"raw": raw or "vainfo / v4l2-ctl not available"}


def _get_gpu_modules() -> str:
    """Check lsmod for known GPU kernel drivers."""
    try:
        result = subprocess.run(
            ["lsmod"],
            capture_output=True, text=True, timeout=5,
        )
        known = ["v3d", "vc4", "i915", "xe", "amdgpu", "nouveau", "nvidia"]
        found = [m for m in known if m in result.stdout]
        return ", ".join(found) if found else "none detected"
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return "lsmod not available"


def _get_dpkg_version(package: str) -> str:
    """Query installed package version via dpkg-query."""
    try:
        result = subprocess.run(
            ["dpkg-query", "-f", "${Version}", "-W", package],
            capture_output=True, text=True, timeout=5,
        )
        return result.stdout.strip() or "not installed"
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return "unknown"


def _get_weston_version() -> str:
    """
    Read from the file written by the weston/display container.
    Falls back to dpkg-query.
    """
    try:
        with open("/run/user/0/weston_version.txt") as f:
            line = f.readline().strip()
            parts = line.split()
            return parts[1] if len(parts) >= 2 else line
    except OSError:
        pass
    return _get_dpkg_version("weston")


def _run_tool(cmd: list) -> str | None:
    """
    Run a subprocess, return combined stdout+stderr as a string.
    Returns None if the tool is not found, times out, or otherwise fails.
    """
    env = {
        **os.environ,
        "WAYLAND_DISPLAY": config.WAYLAND_DISPLAY,
        "XDG_RUNTIME_DIR": config.XDG_RUNTIME_DIR,
    }
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=config.TOOL_TIMEOUT,
            env=env,
        )
        combined = (result.stdout + result.stderr).strip()
        return combined or None
    except (FileNotFoundError, subprocess.TimeoutExpired, PermissionError):
        return None
