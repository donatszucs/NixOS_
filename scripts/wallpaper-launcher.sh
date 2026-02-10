#!/usr/bin/env bash

WALL_DIR="$HOME/Pictures/wallpapers"
ROFI_CONF="$HOME/.config/rofi/wallpaper-config.rasi"
CONF_DIR="$HOME/.config/hypr"

# 1. Get the focused monitor name (e.g., DP-1, HDMI-A-1)
MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')

# 2. Build rofi menu with image paths as icons
MENU_CONTENT=""
while IFS= read -r img; do
    MENU_CONTENT+="$img\x00icon\x1f$WALL_DIR/$img\n"
done < <(ls "$WALL_DIR")

# Remove trailing newline
MENU_CONTENT="${MENU_CONTENT%\\n}"

# 3. Pick the wallpaper with image previews
SELECTION=$(echo -e "$MENU_CONTENT" | rofi -dmenu \
                            -i -p "󰸉 Wallpaper ($MONITOR):" \
                            -config "$ROFI_CONF" \
                            -show-icons
            )

[[ -z "$SELECTION" ]] && exit 1
FULL_PATH="$WALL_DIR/$SELECTION"

# 4. Create a monitor-specific symlink
LINK_NAME="$CONF_DIR/temps/wallpaper_$MONITOR"

ln -sf "$FULL_PATH" "$LINK_NAME"

# 5. Apply immediately
hyprctl hyprpaper preload "$FULL_PATH"
hyprctl hyprpaper wallpaper "$MONITOR,$FULL_PATH"
hyprctl hyprpaper unload unused