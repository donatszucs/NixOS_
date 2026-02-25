#!/usr/bin/env bash

CONF_FILE="$HOME/.config/hypr/hyprpaper.conf"
TEMPS_DIR="$HOME/.config/hypr/temps"
DEFAULT="$HOME/nixos-config/scripts/default.jpg"

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
        ln -s "$DEFAULT" "$LINK"
    fi

    # Append wallpaper block to the config file
    {
        echo "wallpaper {"
        echo "    monitor = $MON"
        echo "    path = $LINK"
        echo "    fit_mode = cover"
        echo "}"
        echo ""
    } >> "$CONF_FILE"
done

# Append default (fallback) wallpaper block
{
    echo "wallpaper {"
    echo "    monitor = "
    echo "    path = $DEFAULT"
    echo "    fit_mode = cover"
    echo "}"
    echo ""
    echo "splash = false"
} >> "$CONF_FILE"

# Now start hyprpaper
hyprpaper