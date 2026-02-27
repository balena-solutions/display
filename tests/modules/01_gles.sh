#!/bin/bash

run_glmark_capture() {
    NAME=$1
    PARAMS=$2
    SAFE_NAME=$(sanitize "$NAME")
    GLMARK_LOG="/tmp/glmark_${SAFE_NAME}.log"
    
    log "[GLMARK2] $NAME"
    
    # Use 'fps' only for minimal overlay
    GALLIUM_HUD="fps" glmark2-es2-wayland --size "$SCREEN_RES" --benchmark "$PARAMS:duration=6.0" --fullscreen --swap-mode=fifo > "$GLMARK_LOG" 2>&1 &
    
    PID=$!
    sleep 3
    capture_screenshot "$NAME"
    wait $PID
    
    SCORE=$(grep "Score:" "$GLMARK_LOG" | tail -n 1 | awk -F 'Score:' '{print $2}' | awk '{print $1}')
    
    if [[ "$SCORE" =~ ^[0-9]+$ ]]; then
        log "   [RESULT] $SCORE FPS"
        echo "<tr><td>$NAME</td><td><strong>$SCORE</strong></td></tr>" >> "$TABLE_ROWS_FILE"
    else
        log "   [FAIL] Parsing Error. Raw Score: '$SCORE'"
        echo "<tr><td>$NAME</td><td><span style='color:red'>FAIL</span></td></tr>" >> "$TABLE_ROWS_FILE"
    fi
    rm -f "$GLMARK_LOG"
}

run_glmark_capture "GLES Texture Fill" "texture:texture-filter=linear"
run_glmark_capture "GLES Shading" "shading:shading=phong"
run_glmark_capture "GLES Jellyfish" "jellyfish"