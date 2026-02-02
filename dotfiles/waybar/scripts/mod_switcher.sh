#!/usr/bin/env bash

# Use the EXACT name from your previous command
DEVICE="Keychron  Keychron Link " 
PRESET="SuperMouse"
STATE_FILE="/tmp/input_remapper_state"

# Check our own toggle file
if [[ "$1" == "toggle" ]]; then
    if [ -f "$STATE_FILE" ]; then
        # TURN OFF
        input-remapper-control --command stop --device "$DEVICE" --preset "$PRESET"
        rm "$STATE_FILE"
        echo "󰘳"  # Icon for SUPER mode (Windows/Super logo)
    else
        # TURN ON
        input-remapper-control --command start --device "$DEVICE" --preset "$PRESET"
        touch "$STATE_FILE"
        echo "󰍽"  # Icon for MOUSE mode
    fi
    pkill -RTMIN+10 waybar
else
    if [ -f "$STATE_FILE" ]; then
        echo "󰘳"
    else
        echo "󰍽"
    fi
fi