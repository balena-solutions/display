#!/usr/bin/env python3
"""
Entrypoint for the test suite.

Normal mode:  python3 run.py
  Waits for the Wayland socket, then starts the Flask web server on port 8000.

Auto mode:    python3 run.py --auto   (or set AUTO_RUN=1)
  Waits for the Wayland socket, runs all tests sequentially, exports a PDF,
  then exits. Intended for CI pipelines and scripted deployments.
"""

import argparse
import dataclasses
import os
import sys
import time

import config


def wait_for_wayland(timeout: int = 60):
    """Block until the Wayland socket appears, or raise on timeout."""
    print(f"[INFO] Waiting for Wayland socket at {config.WAYLAND_SOCKET} ...")
    elapsed = 0
    while not os.path.exists(config.WAYLAND_SOCKET):
        time.sleep(1)
        elapsed += 1
        if elapsed >= timeout:
            raise RuntimeError(
                f"Wayland socket not found after {timeout}s: {config.WAYLAND_SOCKET}"
            )
    print(f"[INFO] Wayland socket found.")


def auto_run():
    """Run all tests sequentially, export PDF, and exit."""
    # Import here to avoid circular imports at module level.
    import system_info
    import pdf_export
    from app import run_store, _refresh_system_info
    from tests import ALL_TESTS

    print("[AUTO] Collecting system info ...")
    _refresh_system_info()

    for test_def in ALL_TESTS:
        print(f"[AUTO] Running: {test_def['name']}")
        run_store["results"][test_def["id"]] = {"status": "running"}
        result = test_def["fn"]()
        run_store["results"][test_def["id"]] = dataclasses.asdict(result)
        print(f"[AUTO] Done: {test_def['name']} → {result.status}")

    pdf_path = pdf_export.export(run_store)
    print(f"[AUTO] PDF saved: {pdf_path}")
    sys.exit(0)


def serve():
    """Start the Flask web server."""
    from app import create_app
    app = create_app()
    print("[INFO] Starting Flask on http://0.0.0.0:8000")
    app.run(host="0.0.0.0", port=8000, debug=False, threaded=True)


def main():
    parser = argparse.ArgumentParser(description="Display block test suite")
    parser.add_argument(
        "--auto",
        action="store_true",
        help="Run all tests and export PDF without starting the web UI (CI mode)",
    )
    args = parser.parse_args()

    wait_for_wayland()

    if args.auto or config.AUTO_RUN:
        auto_run()
    else:
        serve()


if __name__ == "__main__":
    main()
