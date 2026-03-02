#!/bin/bash

# ==============================================================================
# CONFIGURATION
# ==============================================================================
VIDEO_H264_720P_30FPS="/usr/src/app/assets/video_test_h264_720p30.mp4"
VIDEO_H264_1080P_60FPS="/usr/src/app/assets/video_test_h264_1080p60.mp4"
VIDEO_H265_1080P_60FPS="/usr/src/app/assets/video_test_h265_1080p60.mp4"

# Determine hwdec setting based on environment variable or device type
get_hwdec_setting() {
    # If HWDEC environment variable is explicitly set, use it
    if [ -n "$HWDEC" ]; then
        echo "$HWDEC"
        return
    fi
    
    # Set default based on device type
    case "${BALENA_DEVICE_TYPE:-}" in
        raspberry*)
            # Raspberry Pi devices
            echo "v4l2m2m"
            ;;
        jetson*)
            # NVIDIA Jetson devices
            echo "nvdec"
            ;;
        *)
            # Default for other devices
            echo "auto"
            ;;
    esac
}

HWDEC_SETTING=$(get_hwdec_setting)


# -----------------------------------------------------------------------------
# MPV-based playback, hw-dec detection, and FPS measurement
# -----------------------------------------------------------------------------
run_video_capture_mpv() {
    FILE_PATH=$1
    TEST_NAME=$2

    if [ ! -f "$FILE_PATH" ]; then
        log "[SKIP] Video file not found: $FILE_PATH"
        return
    fi

    SAFE_NAME=$(sanitize "$TEST_NAME")
    MPV_LOG="/tmp/mpv_${SAFE_NAME}.log"

    log "[MPV] Starting $TEST_NAME"

    # Start mpv with status message that includes FPS and decoder info
    # Capture both stdout and stderr to the log file to get term-status-msg output
    # Disable complex shaders via --gpu-dumb-mode=yes
    mpv "$FILE_PATH" \
        --vo=gpu \
        --gpu-context=wayland \
        --hwdec=$HWDEC_SETTING \
        --fullscreen \
        --no-config \
        --no-osc \
        --gpu-dumb-mode=yes \
        --log-file="$MPV_LOG" --msg-level=vd=info,ffmpeg=info,hwdec=debug,vo=info \
        --term-status-msg='Status: fps=${estimated-vf-fps}, drops=${frame-drop-count}, codec=${video-codec}, hwdec=${hwdec-current}' \
        >> "$MPV_LOG" 2>&1 &
    PID=$!

    sleep 8

    # Capture screenshot
    rm -f *.png
    weston-screenshooter > /dev/null 2>&1
    CAPTURED_PNG=$(ls *.png 2>/dev/null | head -n 1)

    sleep 12

    # Stop mpv
    kill $PID 2>/dev/null || true
    wait $PID 2>/dev/null || true

    # -------------------------------------------------------------------------
    # Parse status messages from log to extract FPS and detect HW decoder
    # -------------------------------------------------------------------------
    # Extract the last status message with FPS info
    # Use grep to match "Status: fps=" followed by a digit to exclude debug template lines
    STATUS_LINE=$(grep 'Status: fps=[0-9]' "$MPV_LOG" 2>/dev/null | tail -n1 || true)
    AVG_FPS=""
    HW="software"
    if [ -n "$STATUS_LINE" ]; then
        # Extract fps value using portable sed (no grep -oP dependency)
        AVG_FPS=$(echo "$STATUS_LINE" | sed 's/.*fps=\([0-9.]*\).*/\1/')
        # Fallback: try awk split on commas
        if [ -z "$AVG_FPS" ] || [ "$AVG_FPS" = "$STATUS_LINE" ]; then
            AVG_FPS=$(echo "$STATUS_LINE" | awk -F'fps=' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
        fi
        # Extract hwdec value
        HW=$(echo "$STATUS_LINE" | sed 's/.*hwdec=\([^ ,]*\).*/\1/')
        if [ -z "$HW" ] || [ "$HW" = "$STATUS_LINE" ]; then
            HW=$(echo "$STATUS_LINE" | awk -F'hwdec=' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
        fi
        log "   [DEBUG] STATUS_LINE: $STATUS_LINE"
        log "   [DEBUG] Parsed FPS: $AVG_FPS"
        log "   [DEBUG] Parsed HW: $HW"
    else
        log "   [DEBUG] No status line found in log. Checking log file..."
        log "   [DEBUG] Log file exists: $([ -f "$MPV_LOG" ] && echo 'yes' || echo 'no')"
        log "   [DEBUG] Last 3 lines: $(tail -3 "$MPV_LOG" 2>/dev/null | head -c 200)"
    fi

    # Prepare Raw Log (Escape HTML)
    if [ -f "$MPV_LOG" ]; then
        RAW_LOG_CONTENT=$(cat "$MPV_LOG" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    else
        RAW_LOG_CONTENT="Log file not found."
    fi

    # -------------------------------------------------------------------------
    # Reporting & Gallery Card
    # -------------------------------------------------------------------------
    if [[ "$AVG_FPS" =~ [0-9.]+ ]]; then
        log "   [RESULT] $AVG_FPS FPS (HW: $HW)"
        echo "<tr><td>$TEST_NAME</td><td><strong>$AVG_FPS</strong></td><td>$HW</td></tr>" >> "$TABLE_ROWS_FILE"

        if [ -n "$CAPTURED_PNG" ] && [ -n "$GALLERY_FILE" ]; then
            B64_DATA=$(base64 -w 0 "$CAPTURED_PNG")

            echo "<div class='gallery-item' style='border: 1px solid #ccc; padding: 15px; margin-bottom: 20px; border-radius: 8px;'>" >> "$GALLERY_FILE"
            echo "  <h3 style='margin-top:0;'>$TEST_NAME</h3>" >> "$GALLERY_FILE"
            echo "  <p><strong>Performance:</strong> $AVG_FPS FPS &nbsp; <strong>Decoder:</strong> $HW</p>" >> "$GALLERY_FILE"
            echo "  <img src='data:image/png;base64,$B64_DATA' alt='$TEST_NAME' style='border:1px solid #eee; margin: 10px 0;' />" >> "$GALLERY_FILE"

            echo "  <details style='background: #f8f9fa; border: 1px solid #ddd; padding: 10px; border-radius: 4px;'>" >> "$GALLERY_FILE"
            echo "    <summary style='cursor:pointer; font-weight:600; color:#0056b3;'>View MPV Log</summary>" >> "$GALLERY_FILE"
            echo "    <pre style='font-size:0.75em; max-height:300px; overflow:auto; margin-top:10px; background:#fff; padding:10px; border:1px solid #eee;'>$RAW_LOG_CONTENT</pre>" >> "$GALLERY_FILE"
            echo "  </details>" >> "$GALLERY_FILE"
            echo "</div>" >> "$GALLERY_FILE"

            log "   [IMAGE] Bundled into report."
            rm "$CAPTURED_PNG"
        else
            log "   [WARN] Screenshot capture failed." 
        fi
    else
        log "   [FAIL] Could not parse playback FPS. HW: $HW"
        echo "<tr><td>$TEST_NAME</td><td><span style='color:red'>FAIL</span></td><td>$HW</td></tr>" >> "$TABLE_ROWS_FILE"
    fi

    rm -f "$MPV_LOG"
}

# -----------------------------------------------------------------------------
# EXECUTION: mpv-only playback
# -----------------------------------------------------------------------------
if command -v mpv > /dev/null; then
    run_video_capture_mpv "$VIDEO_H264_720P_30FPS" "H.264 720p30"
    run_video_capture_mpv "$VIDEO_H264_1080P_60FPS" "H.264 1080p60"
    run_video_capture_mpv "$VIDEO_H265_1080P_60FPS" "H.265 1080p60"
else
    log "[SKIP] mpv not installed."
fi