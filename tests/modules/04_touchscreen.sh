#!/bin/bash

# Touchscreen Test Module - Runs weston-simple-touch demo app

run_simple_touch_capture() {
    NAME="Touchscreen - weston-simple-touch"
    SAFE_NAME=$(sanitize "$NAME")
    TOUCH_LOG="/tmp/touch_${SAFE_NAME}.log"
    
    log "[TOUCHSCREEN] $NAME"
    
    # Run weston-simple-touch in the background for a few seconds
    # This demo app renders colored boxes and responds to touch input
    # It will be running on the Wayland display
    timeout 10 weston-simple-touch > "$TOUCH_LOG" 2>&1 &
    TOUCH_PID=$!
    
    # Give it time to start and render
    sleep 2
    
    # Capture screenshot showing the app running
    capture_screenshot "$NAME"
    
    # Wait for timeout or process to finish
    wait $TOUCH_PID 2>/dev/null || true
    
    # Check if the app ran successfully (no obvious errors in log)
    if grep -q "error\|Error\|ERROR\|failed\|Failed" "$TOUCH_LOG" 2>/dev/null; then
        log "   [FAIL] weston-simple-touch exited with errors"
        echo "<tr><td>$NAME</td><td><span style='color:red'>FAILED</span></td></tr>" >> "$TABLE_ROWS_FILE"
        rm -f "$TOUCH_LOG"
        return 1
    else
        log "   [RESULT] weston-simple-touch demo ran successfully"
        echo "<tr><td>$NAME</td><td><strong>PASS</strong></td></tr>" >> "$TABLE_ROWS_FILE"
        rm -f "$TOUCH_LOG"
        return 0
    fi
}

# Run the touchscreen test
if command -v weston-simple-touch > /dev/null; then
    run_simple_touch_capture
else
    log "[SKIP] weston-simple-touch not installed"
fi
