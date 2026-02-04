#!/usr/bin/env bash

# Use the full path to your uv-created python binary
VENV_PYTHON=".venv/bin/python"
SCRIPT_PATH="tapo_control.py"

# Handle arguments
if [[ "$1" == "up" ]]; then
    $VENV_PYTHON $SCRIPT_PATH brightness 20
elif [[ "$1" == "down" ]]; then
    $VENV_PYTHON $SCRIPT_PATH brightness -20
elif [[ "$1" == "toggle" ]]; then
    $VENV_PYTHON $SCRIPT_PATH toggle
fi

# Final output for the icon
$VENV_PYTHON $SCRIPT_PATH
pkill -RTMIN+11 waybar