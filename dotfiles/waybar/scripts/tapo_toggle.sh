#!/usr/bin/env bash

# Use the full path to your uv-created python binary
CMD=$1
VENV_PYTHON=~/.config/waybar/scripts/.venv/bin/python
PY_SCRIPT=~/.config/waybar/scripts/tapo_control.py
CACHE_FILE="/tmp/tapo_brightness"
PID_FILE="/tmp/tapo_worker.pid"

# Helper to get real hardware value (run once if cache missing)
get_hardware_brightness() {
    $VENV_PYTHON $PY_SCRIPT brightness
}

get_hardware_status() {
    $VENV_PYTHON $PY_SCRIPT status
}

# Initialize Cache if missing
if [ ! -f "$CACHE_FILE" ]; then
    VAL=$(get_hardware_brightness)
    if [ -z "$VAL" ]; then VAL=100; fi
    echo "$VAL" > "$CACHE_FILE"
fi

# Read current cached value
CURRENT=$(cat "$CACHE_FILE")

# --- GET COMMAND (Used by Waybar to show value) ---
if [ "$CMD" = "get" ]; then
    # python script for the state, but cache for the number
    STATE=$(get_hardware_status)
    
    if [ "$STATE" = "OFF" ]; then
        echo " Off 󱩎"
    else
        # Use printf to ensure the % is always padded to the same width
        printf "%3d%% 󱩒\n" "$CURRENT"
    fi
    exit 0
fi

# --- GET COMMAND (Used by Waybar to show value) ---
if [ "$CMD" = "toggle" ]; then
    STATE=$(get_hardware_status)
    if [ "$STATE" = "ON" ]; then
        $VENV_PYTHON $PY_SCRIPT off
    else
        $VENV_PYTHON $PY_SCRIPT on
        echo "100" > "$CACHE_FILE"
    fi
    exit 0
fi

# --- UP/DOWN LOGIC ---
if [ "$CMD" = "up" ]; then
    NEW=$((CURRENT + 10))
    if [ "$NEW" -gt 100 ]; then NEW=100; fi
elif [ "$CMD" = "down" ]; then
    NEW=$((CURRENT - 10))
    if [ "$NEW" -lt 1 ]; then NEW=1; fi
fi

# 1. Update the Cache IMMEDIATELY (So Waybar feels fast)
echo "$NEW" > "$CACHE_FILE"

# 2. Update Waybar Interface IMMEDIATELY
pkill -RTMIN+11 waybar

# 3. THE DEBOUNCE MAGIC
# Check if a worker is already waiting to update this monitor.
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    # If the process is still alive (sleeping), kill it!
    if kill -0 "$OLD_PID" 2>/dev/null; then
        kill "$OLD_PID"
    fi
fi

# 4. Start a new worker in the background
(
    # Wait 1 second. If user scrolls again during this time, 
    # this process gets killed (above) and never runs the command.
    sleep 1
    
    # Read the latest value (in case user scrolled 5 times fast)
    FINAL_VAL=$(cat "$CACHE_FILE")
    
    # Send the command to the monitor ONCE
    $VENV_PYTHON $PY_SCRIPT set $FINAL_VAL
) &

# Save the PID of this new worker so we can kill it if you scroll again
echo $! > "$PID_FILE"