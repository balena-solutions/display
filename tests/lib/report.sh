#!/bin/bash

generate_html_report() {
    log "--- GENERATING REPORT ---"

    S_DT=$(sanitize "$TIMESTAMP")
    S_DEV=$(sanitize "${BALENA_DEVICE_TYPE:-Generic}")
    S_OS=$(sanitize "${BALENA_HOST_OS_VERSION:-UnknownOS}")
    S_WESTON=$(sanitize "$WESTON_VER")
    S_OUTPUT=$(sanitize "$OUTPUT_NAME")

    # Pattern: report-<datetime>-<output>-<device>-<os>-weston-<version>.html
    REPORT_FILENAME="report-${S_DT}-${S_OUTPUT}-${S_DEV}-${S_OS}-weston-${S_WESTON}.html"
    REPORT_FINAL="$RESULTS_DIR/$REPORT_FILENAME"

    ROWS_CONTENT=$(cat "$TABLE_ROWS_FILE")
    GALLERY_CONTENT=$(cat "$GALLERY_FILE")

    cat <<END_HTML > "$REPORT_FINAL"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Benchmark: $DEVICE_MODEL</title>
<style>
  body { font-family: -apple-system, system-ui, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; max-width: 900px; margin: 2rem auto; padding: 0 1rem; color: #333; line-height: 1.5; }
  h1 { color: #0056b3; border-bottom: 2px solid #eee; padding-bottom: 0.5rem; }
  h2 { margin-top: 2rem; border-bottom: 1px solid #eee; color: #444; page-break-after: avoid; }
  pre { background: #f8f9fa; padding: 1rem; border: 1px solid #ddd; border-radius: 4px; white-space: pre-wrap; word-wrap: break-word; font-size: 0.85em; }
  table { width: 100%; border-collapse: collapse; margin: 1rem 0; page-break-inside: avoid; }
  th, td { text-align: left; padding: 12px; border-bottom: 1px solid #ddd; }
  th { background-color: #f1f3f5; font-weight: 600; }
  tr:hover { background-color: #f8f9fa; }
  .gallery-item { margin-bottom: 3rem; border: 1px solid #eee; padding: 10px; border-radius: 8px; page-break-inside: avoid; }
  .gallery-item h3 { margin-top: 0; font-size: 1.1rem; color: #555; }
  img { max-width: 100%; height: auto; display: block; border-radius: 4px; }
  @media print { body { max-width: 100%; margin: 0; padding: 0.5cm; } pre { border: 1px solid #999; } }
</style>
</head>
<body>

<h1>Graphics Report: $DEVICE_MODEL</h1>
<p><strong>Date:</strong> $(date) <br> <strong>Output:</strong> $OUTPUT_NAME</p>

<h2>System Diagnostics</h2>
<pre>$DIAG_CONTENT</pre>

<h2>Software Versions</h2>
<table>
  <tr><th>Component</th><th>Version</th></tr>
  <tr><td>Kernel</td><td>$KERNEL_VER</td></tr>
  <tr><td>Mesa</td><td>$MESA_VER</td></tr>
  <tr><td>Weston</td><td>$WESTON_VER</td></tr>
  <tr><td>Glmark2</td><td>$GLMARK_VER</td></tr>
  <tr><td>Vkmark</td><td>$VKMARK_VER</td></tr>
</table>

<h2>Performance Results</h2>
<table>
  <tr><th>Benchmark Scene</th><th>Result (FPS)</th></tr>
$ROWS_CONTENT
</table>

<h2>Visual Verification</h2>
<div class="gallery">
$GALLERY_CONTENT
</div>

</body>
</html>
END_HTML

    rm "$TABLE_ROWS_FILE" "$GALLERY_FILE"
    log "Report Saved: $REPORT_FINAL"
}