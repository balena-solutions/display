"""
Flask application factory, routes, and in-memory state store.

run_store is the single source of truth for the current session's results.
It is ephemeral — a container restart clears it. The PDF export is the
persistence mechanism for results across sessions.
"""

import dataclasses
import os
import threading

from flask import Flask, abort, jsonify, redirect, render_template, request, send_file, url_for

import config
import pdf_export
import system_info as sysinfo_module
from tests import ALL_TESTS

# In-memory state. Shared across all requests.
run_store: dict = {
    "system_info": {},
    "results": {},      # test_id → dataclasses.asdict(TestResult)
    "settings": {
        "duration": config.TEST_DURATION,
    },
}

# Prevents two tests from running at the same time.
_run_lock = threading.Lock()


def create_app() -> Flask:
    app = Flask(__name__)

    @app.route("/")
    def index():
        # Collect system info on first visit. The user can refresh it explicitly.
        if not run_store["system_info"]:
            _refresh_system_info()

        return render_template(
            "index.html",
            system_info=run_store["system_info"],
            all_tests=ALL_TESTS,
            results=run_store["results"],
            settings=run_store["settings"],
        )

    @app.route("/run/<test_id>", methods=["POST"])
    def run_test(test_id):
        test_def = _find_test(test_id)
        if test_def is None:
            abort(404)

        if not _run_lock.acquire(blocking=False):
            return jsonify({"error": "A test is already running. Please wait."}), 409

        try:
            run_store["results"][test_id] = {"status": "running"}
            result = test_def["fn"]()
            run_store["results"][test_id] = dataclasses.asdict(result)
        finally:
            _run_lock.release()

        return redirect(url_for("test_detail", test_id=test_id))

    @app.route("/test/<test_id>")
    def test_detail(test_id):
        test_def = _find_test(test_id)
        if test_def is None:
            abort(404)
        result = run_store["results"].get(test_id)
        return render_template("test_detail.html", test_def=test_def, result=result)

    @app.route("/run-all", methods=["POST"])
    def run_all():
        if not _run_lock.acquire(blocking=False):
            return jsonify({"error": "A test is already running."}), 409

        def _run_all_in_background():
            try:
                for test_def in ALL_TESTS:
                    run_store["results"][test_def["id"]] = {"status": "running"}
                    result = test_def["fn"]()
                    run_store["results"][test_def["id"]] = dataclasses.asdict(result)
            finally:
                _run_lock.release()

        thread = threading.Thread(target=_run_all_in_background, daemon=True)
        thread.start()

        return redirect(url_for("index"))

    @app.route("/settings", methods=["POST"])
    def update_settings():
        try:
            duration = int(request.form.get("duration", config.TEST_DURATION))
        except (ValueError, TypeError):
            duration = config.TEST_DURATION

        # Clamp to a sensible range so tests don't run for an absurd amount of time.
        duration = max(5, min(120, duration))

        run_store["settings"]["duration"] = duration
        config.TEST_DURATION = duration
        config.SCREENSHOT_DELAY = duration // 2

        return redirect(url_for("index"))

    @app.route("/export-pdf")
    def export_pdf():
        pdf_path = pdf_export.export(run_store)
        return send_file(pdf_path, as_attachment=True, download_name=os.path.basename(pdf_path))

    @app.route("/refresh-sysinfo", methods=["POST"])
    def refresh_sysinfo():
        _refresh_system_info()
        return redirect(url_for("index"))

    return app


def _find_test(test_id: str) -> dict | None:
    return next((t for t in ALL_TESTS if t["id"] == test_id), None)


def _refresh_system_info():
    """Collect system info and update both run_store and config.SCREEN_RES."""
    sysinfo = sysinfo_module.collect()
    run_store["system_info"] = sysinfo

    # Make the detected resolution available to test modules via config.
    display = sysinfo.get("display", {})
    resolution = display.get("resolution", "")
    if resolution and "x" in resolution:
        config.SCREEN_RES = resolution
