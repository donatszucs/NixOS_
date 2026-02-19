#!/usr/bin/env bash

CACHE="/tmp/waybar-nowplaying-last"

# Find the first player with status "Playing"
active=""
while read -r p; do
    if playerctl -p "$p" status 2>/dev/null | grep -q "Playing"; then
        active="$p"
        break
    fi
done < <(playerctl -l 2>/dev/null)

# If something is playing, update the cache
if [ -n "$active" ]; then
    echo "$active" > "$CACHE"
else
    # Fall back to last known player if it still exists
    if [ -f "$CACHE" ]; then
        cached=$(cat "$CACHE")
        if playerctl -l 2>/dev/null | grep -qx "$cached"; then
            active="$cached"
        else
            rm -f "$CACHE"
        fi
    fi
fi

case "$1" in
    title)
        if [ -n "$active" ]; then
            title=$(playerctl -p "$active" metadata --format '{{title}}' 2>/dev/null | head -c 40)
            artist=$(playerctl -p "$active" metadata --format '{{artist}}' 2>/dev/null)
            # Handle if chrome is the player, but the tab has been closed
            if [ -n "$title" ] && [ -n "$artist" ]; then
                printf '{"text":"%s","tooltip":"%s"}\n' \
                "$(echo "$title" | sed 's/"/\\"/g')" \
                "$(echo "$artist" | sed 's/"/\\"/g')"
            else
                printf '{"text":"Nothing playing","tooltip":""}'\n
            fi
        else
            printf '{"text":"Nothing playing","tooltip":""}'\n
        fi
        ;;
    check)
        # Always show the module
        exit 0
        ;;
    playpause-icon)
        status=$([ -n "$active" ] && playerctl -p "$active" status 2>/dev/null)
        [ "$status" = "Playing" ] && echo '󰏤' || echo '󰐊'
        ;;
    play-pause)
        [ -n "$active" ] && playerctl -p "$active" play-pause
        ;;
    next)
        [ -n "$active" ] && playerctl -p "$active" next
        ;;
    focus)
        [ -z "$active" ] && exit 1
        case "$active" in
            chromium*|chrome*) class="google-chrome" ;;
            *)                 class="$active"       ;;
        esac
        hyprctl dispatch focuswindow class:"$class"
        ;;
esac
