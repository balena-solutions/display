#!/bin/bash
# Handles configuration, logging, and shared utilities like screenshotting.


# Configuration
export SOCKET_NAME=${SOCKET_NAME:-"wayland-0"}
export XDG_RUNTIME_DIR=/run/user/0
export WAYLAND_DISPLAY=$SOCKET_NAME 
SOCKET="/run/user/0/$SOCKET_NAME"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Setup Directories
mkdir -p /data/benchmarks 
TEMP_LOG="/data/benchmarks/latest_run.log" 
# Remove existing file/symlink
rm -f "$TEMP_LOG"
# Initialize log
> "$TEMP_LOG"

# Shared Files
RESULTS_DIR=${RESULTS_DIR:-""}
TABLE_ROWS_FILE=${TABLE_ROWS_FILE:-""}
GALLERY_FILE=${GALLERY_FILE:-""}

log() {
    echo "$1" | tee -a "$TEMP_LOG"
    # If results dir exists, also log to the final result file
    if [ -n "$RESULTS_DIR" ] && [ -f "$RESULTS_DIR/results.txt" ]; then
        echo "$1" >> "$RESULTS_DIR/results.txt"
    fi
}

sanitize() { 
    echo "$1" | tr ' /' '__' | tr -cd '[:alnum:]_.-'
}

capture_screenshot() {
    NAME=$1
    # Aggressively clean previous PNGs
    rm -f *.png
    
    # Run screenshooter
    if TOOL_OUTPUT=$(weston-screenshooter 2>&1); then
         CAPTURED_FILE=$(ls *.png 2>/dev/null | head -n 1)
         
         if [ -n "$CAPTURED_FILE" ]; then
             B64_DATA=$(base64 -w 0 "$CAPTURED_FILE")
             echo "<div class='gallery-item'><h3>$NAME</h3><img src='data:image/png;base64,$B64_DATA' alt='$NAME' /></div>" >> "$GALLERY_FILE"
             log "   [IMAGE] Captured: $CAPTURED_FILE"
             rm "$CAPTURED_FILE"
         else
             log "   [WARN] Screenshot missing."
             log "          Tool Output: $TOOL_OUTPUT"
             log "          Current Directory ($(pwd)) Contents: $(ls)"
         fi
    else
         log "   [WARN] Screenshot command failed."
         log "          Error: $TOOL_OUTPUT"
    fi
}