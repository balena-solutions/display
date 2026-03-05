"""
PDF export using WeasyPrint.

Renders report.html to a PDF and saves it to /data/reports/.
The same template is used for the web view and PDF, so there's one
source of truth for the report layout.
"""

import datetime
import os

import weasyprint
from jinja2 import Environment, FileSystemLoader

import config
from tests import ALL_TESTS

TEMPLATES_DIR = os.path.join(os.path.dirname(__file__), "templates")


def export(run_store: dict) -> str:
    """
    Render report.html with the current results and write it as a PDF.
    Returns the path to the saved PDF file.
    """
    os.makedirs(config.REPORTS_DIR, exist_ok=True)

    html = _render_report_html(run_store)

    device_type = run_store.get("system_info", {}).get("device_type", "device")
    display_output = (
        run_store.get("system_info", {})
        .get("display", {})
        .get("output_name", "display")
    )
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

    # Sanitise the components so they're safe to use in a filename.
    device_type = _slugify(device_type)
    display_output = _slugify(display_output)

    filename = f"report-{timestamp}-{device_type}-{display_output}.pdf"
    pdf_path = os.path.join(config.REPORTS_DIR, filename)

    weasyprint.HTML(string=html, base_url=os.path.dirname(__file__) + "/").write_pdf(pdf_path)
    return pdf_path


def _render_report_html(run_store: dict) -> str:
    """Render report.html using Jinja2 directly (no Flask app context needed)."""
    env = Environment(loader=FileSystemLoader(TEMPLATES_DIR), autoescape=True)
    template = env.get_template("report.html")
    return template.render(
        system_info=run_store.get("system_info", {}),
        all_tests=ALL_TESTS,
        results=run_store.get("results", {}),
        generated_at=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    )


def _slugify(value: str) -> str:
    """Replace characters that are unsafe in filenames with underscores."""
    safe = ""
    for ch in value:
        if ch.isalnum() or ch in ("-", "_", "."):
            safe += ch
        else:
            safe += "_"
    return safe.strip("_") or "unknown"
