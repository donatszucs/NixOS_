#!/usr/bin/env bash

CONF_FILE="$HOME/.config/hypr/hyprpaper.conf"
TEMPS_DIR="$HOME/.config/hypr/temps"

# Create temps directory if it doesn't exist
mkdir -p "$TEMPS_DIR"

# Clear the old config
echo "" > "$CONF_FILE"

# Get list of all connected monitors
MONITORS=$(hyprctl monitors -j | jq -r '.[] | .name')

for MON in $MONITORS; do
    LINK="$TEMPS_DIR/wallpaper_$MON"
    
    # Create a placeholder symlink if it doesn't exist 
    if [ ! -L "$LINK" ]; then
        ln -s "$HOME/nixos-config/scripts/default.jpg" "$LINK"
    fi

    # Append to the config file
    echo "preload = $LINK" >> "$CONF_FILE"
    echo "wallpaper = $MON,$LINK" >> "$CONF_FILE"
done

# Now start hyprpaper
hyprpaper