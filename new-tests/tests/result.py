"""
TestResult dataclass — the shared data type for all test runner functions.

Lives in its own module to avoid circular imports between tests/__init__.py
(which imports runner functions) and the runner modules (which need TestResult).
"""

import dataclasses
from typing import Optional


@dataclasses.dataclass
class TestResult:
    test_id: str
    test_name: str
    group: str
    # "pending" | "running" | "pass" | "fail" | "skip"
    status: str
    # Full stdout+stderr from the tool — displayed as-is in a <pre> block.
    raw_output: str
    # Base64-encoded PNG screenshot, or None if capture failed.
    screenshot_b64: Optional[str]
    # Group-specific extras captured opportunistically.
    # GLES/Vulkan: {"fps": 245}
    # Video:       {"fps": "29.97", "decoder": "v4l2m2m"}
    extra: dict
    started_at: Optional[str]
    finished_at: Optional[str]
    error_message: Optional[str]
