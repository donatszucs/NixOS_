#!/bin/sh
# Usage: ./ddc_brightness.sh [DISPLAY_NUMBER] [up|down|get]

DISPLAY=$1
CMD=$2
CACHE_FILE="/tmp/ddc_brightness_disp${DISPLAY}"
WORKER_PID_FILE="/tmp/ddc_worker_disp${DISPLAY}.pid"

# Helper to get real hardware value (run once if cache missing)
get_hardware_brightness() {
    ddcutil getvcp 10 --display=$DISPLAY --brief | awk '{print $4}'
}

# Initialize Cache if missing
if [ ! -f "$CACHE_FILE" ]; then
    VAL=$(get_hardware_brightness)
    if [ -z "$VAL" ]; then VAL=50; fi
    echo "$VAL" > "$CACHE_FILE"
fi

# Read current cached value
CURRENT=$(cat "$CACHE_FILE")

# --- GET COMMAND (Used by Waybar to show value) ---
if [ "$CMD" = "get" ]; then
    echo "$CURRENT"
    exit 0
fi

# --- UP/DOWN LOGIC ---
if [ "$CMD" = "up" ]; then
    NEW=$((CURRENT + 10))
    if [ "$NEW" -gt 100 ]; then NEW=100; fi
elif [ "$CMD" = "down" ]; then
    NEW=$((CURRENT - 10))
    if [ "$NEW" -lt 0 ]; then NEW=0; fi
fi

# 1. Update the Cache IMMEDIATELY (So Waybar feels fast)
echo "$NEW" > "$CACHE_FILE"

# 2. Update Waybar Interface IMMEDIATELY
pkill -RTMIN+${DISPLAY} waybar

# 3. THE DEBOUNCE MAGIC
# Check if a worker is already waiting to update this monitor.
if [ -f "$WORKER_PID_FILE" ]; then
    OLD_PID=$(cat "$WORKER_PID_FILE")
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
    ddcutil setvcp 10 "$FINAL_VAL" --display=$DISPLAY
) &

# Save the PID of this new worker so we can kill it if you scroll again
echo $! > "$WORKER_PID_FILE"