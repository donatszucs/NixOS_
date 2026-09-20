#!/usr/bin/env bash
set -euo pipefail

# Ensure standard binaries are in PATH (especially when invoked from Sunshine daemon)
export PATH="$PATH:/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin"

LOG_FILE="/tmp/sunshine-virtual-display.log"
echo "[$(date -Iseconds)] Invoked with action: ${1:-none}" >> "$LOG_FILE"

# Client dimensions and FPS passed by Sunshine environment
CLIENT_WIDTH="${SUNSHINE_CLIENT_WIDTH:-1920}"
CLIENT_HEIGHT="${SUNSHINE_CLIENT_HEIGHT:-1080}"
CLIENT_FPS="${SUNSHINE_CLIENT_FPS:-60}"

case "${1:-}" in
  connect)
    echo "[$(date -Iseconds)] Connecting client: ${CLIENT_WIDTH}x${CLIENT_HEIGHT}@${CLIENT_FPS}" >> "$LOG_FILE"

    # 1. Unlock screen if locked and pause hypridle to avoid sleep during stream
    loginctl unlock-session 2>/dev/null || true
    pkill -STOP -x hypridle 2>/dev/null || true

    # 2. Create headless virtual monitor
    hyprctl output create headless >> "$LOG_FILE" 2>&1 || true
    sleep 0.5

    # Find the newly created HEADLESS monitor name
    HEADLESS=$(hyprctl monitors -j | jq -r '.[] | select(.name | startswith("HEADLESS")) | .name' | head -n 1)
    if [ -z "$HEADLESS" ]; then
      echo "[$(date -Iseconds)] ERROR: Headless monitor could not be found" >> "$LOG_FILE"
      exit 1
    fi
    echo "[$(date -Iseconds)] Created headless monitor: $HEADLESS" >> "$LOG_FILE"

    # 3. Configure the virtual monitor to match the client's resolution and refresh rate
    hyprctl eval "hl.monitor({ output = '$HEADLESS', mode = '${CLIENT_WIDTH}x${CLIENT_HEIGHT}@${CLIENT_FPS}', position = '0x0', scale = 1 })" >> "$LOG_FILE" 2>&1

    # 4. Disable physical monitors (DP-1 and DP-2)
    # This turns physical screens black / to sleep, and Hyprland migrates workspaces to the headless output
    hyprctl eval 'hl.monitor({ output = "DP-1", disabled = true }); hl.monitor({ output = "DP-2", disabled = true })' >> "$LOG_FILE" 2>&1
    sleep 0.5

    # 5. Focus the headless display
    hyprctl dispatch "hl.dsp.focus({ monitor = '$HEADLESS' })" >> "$LOG_FILE" 2>&1 || true
    echo "[$(date -Iseconds)] Switched to headless stream mode" >> "$LOG_FILE"
    ;;

  disconnect)
    echo "[$(date -Iseconds)] Disconnecting client, restoring physical displays" >> "$LOG_FILE"

    # 1. Re-enable physical monitors with their original positions and modes
    # DP-1: 2560x1440@165 at 1920x0
    # DP-2: 1920x1080@75 at 0x400
    hyprctl eval 'hl.monitor({ output = "DP-1", mode = "2560x1440@165", position = "1920x0", scale = 1, disabled = false }); hl.monitor({ output = "DP-2", mode = "1920x1080@75", position = "0x400", scale = 1, disabled = false })' >> "$LOG_FILE" 2>&1
    sleep 0.5

    # 2. Clean up all headless virtual outputs
    for m in $(hyprctl monitors -j | jq -r '.[] | select(.name | startswith("HEADLESS")) | .name'); do
      echo "[$(date -Iseconds)] Removing virtual monitor $m" >> "$LOG_FILE"
      hyprctl output remove "$m" >> "$LOG_FILE" 2>&1 || true
    done

    # 3. Focus back on main physical monitor
    hyprctl dispatch 'hl.dsp.focus({ monitor = "DP-1" })' >> "$LOG_FILE" 2>&1 || true

    # 4. Resume hypridle
    pkill -CONT -x hypridle 2>/dev/null || true
    echo "[$(date -Iseconds)] Restored physical displays successfully" >> "$LOG_FILE"
    ;;

  *)
    echo "Usage: $0 {connect|disconnect}"
    exit 1
    ;;
esac
