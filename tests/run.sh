#!/bin/bash
set -e

# Load Libraries
source ./lib/common.sh
source ./lib/system.sh
source ./lib/report.sh

# Start Web Server
echo "--- STARTING INTERNAL WEB SERVER ---"
webfsd -F -p 8000 -r /data -d > /dev/null 2>&1 &
sleep 1
log "[INFO] Server Active at http://<DEVICE_IP>:8080"
log "=== DIAGNOSTIC RUN: $TIMESTAMP ==="

# System Checks & Data Gathering
# We run these in the main shell so variables persist for the report
run_preflight
detect_display
gather_system_info 

# Setup Results Files
RESULTS_DIR="/data/benchmarks/${TIMESTAMP}_${OUTPUT_NAME}"
mkdir -p "$RESULTS_DIR"
mv "$TEMP_LOG" "$RESULTS_DIR/results.txt"
LOG_FILE="$RESULTS_DIR/results.txt"
ln -sf "$LOG_FILE" /data/benchmarks/latest_run.log

TABLE_ROWS_FILE="$RESULTS_DIR/rows.tmp"
GALLERY_FILE="$RESULTS_DIR/gallery.tmp"
> "$TABLE_ROWS_FILE"
> "$GALLERY_FILE"

# Prepare Diagnostics Content (Text Output)
DIAG_CONTENT=$(print_diagnostics)

# Run Benchmark Modules
log "--- STARTING BENCHMARK MODULES ---"

# Loop through modules in alphabetical order
for module in $(ls modules/*.sh | sort); do
    if [ -f "$module" ]; then
        log ">>> Loading module: $module"
        source "$module"
    fi
done

log "COMPLETED."

# Generate Final Report
generate_html_report

log "Server active. Press Ctrl+C to stop."
sleep infinity