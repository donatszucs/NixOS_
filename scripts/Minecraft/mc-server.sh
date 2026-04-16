#!/usr/bin/env bash

# Grab the first word typed after the script name
ACTION=$1

# If they didn't type anything, show them how to use it
if [[ -z "$ACTION" ]]; then
    echo "Usage: ./mc-server.sh [start|stop|restart|status]"
    exit 1
fi

case $ACTION in
    start)
        echo "🟢 Starting Minecraft Server and Playit..."
        sudo systemctl start minecraft-server playit
        echo "Done!"
        ;;
    stop)
        echo "🔴 Stopping Playit and Minecraft Server..."
        # We stop Playit first so players don't get a connection error while Minecraft saves
        sudo systemctl stop playit minecraft-server
        echo "Done!"
        ;;
    restart)
        echo "🔄 Restarting Minecraft Server and Playit..."
        sudo systemctl restart minecraft-server playit
        echo "Done!"
        ;;
    status)
        sudo systemctl status minecraft-server playit
        ;;
    *)
        echo "❌ Invalid option."
        echo "Usage: ./mc-server.sh [start|stop|restart|status]"
        exit 1
        ;;
esac