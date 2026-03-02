#!/bin/bash

run_vkmark_capture() {
    NAME=$1
    PARAMS=$2
    SAFE_NAME=$(sanitize "$NAME")
    VKMARK_LOG="/tmp/vkmark_${SAFE_NAME}.log"
    
    log "[VKMARK] $NAME"
    
    export VK_INSTANCE_LAYERS=VK_LAYER_MESA_overlay
    export VK_LAYER_MESA_OVERLAY_CONFIG=fps=1
    
    vkmark --present-mode=fifo --size "$SCREEN_RES" --benchmark "$PARAMS:duration=6.0" > "$VKMARK_LOG" 2>&1 &
    
    PID=$!
    sleep 3
    capture_screenshot "$NAME"
    wait $PID
    
    unset VK_INSTANCE_LAYERS
    unset VK_LAYER_MESA_OVERLAY_CONFIG
    
    SCORE=$(grep -o "FPS: [0-9]*" "$VKMARK_LOG" | head -n 1 | awk '{print $2}')
    if [ -z "$SCORE" ]; then SCORE=$(grep "Score:" "$VKMARK_LOG" | tail -n 1 | awk -F 'Score:' '{print $2}' | awk '{print $1}'); fi
    
    if [[ "$SCORE" =~ ^[0-9]+$ ]]; then
        log "   [RESULT] $SCORE FPS"
        echo "<tr><td>$NAME (Vulkan)</td><td><strong>$SCORE</strong></td></tr>" >> "$TABLE_ROWS_FILE"
    else
        log "   [FAIL] Parsing Error. Raw Score: '$SCORE'"
        tail -n 2 "$VKMARK_LOG" | while read -r line; do log "     > $line"; done
        echo "<tr><td>$NAME (Vulkan)</td><td><span style='color:red'>FAIL</span></td></tr>" >> "$TABLE_ROWS_FILE"
    fi
    rm -f "$VKMARK_LOG"
}

if command -v vkmark > /dev/null; then
    run_vkmark_capture "Vulkan Vertex" "vertex"
    run_vkmark_capture "Vulkan Texture" "texture"
    run_vkmark_capture "Vulkan Shading" "shading"
else
    log "[SKIP] vkmark not installed"
fi