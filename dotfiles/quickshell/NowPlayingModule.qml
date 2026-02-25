// Now Playing module — title + hover-to-reveal play/pause & skip controls
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ModuleButton {
    id: root
    noHoverColorChange: true
    property string titleText: "󰎆  Nothing playing"
    property string playPauseIcon: "󰐊"
    property bool expanded: parentHover.hovered

    HoverHandler {
        id: parentHover
    }

    // Mirrors the script's $active / $CACHE logic entirely in QML
    property string activePlayer: ""   // currently active player name
    property string cachedPlayer: ""   // last known playing player

    function refreshAll() {
        activeProc.running = true
    }

    // Called once we know activePlayer — fetch title+status
    function fetchMetadata() {
        if (activePlayer === "") return
        titleProc.running = true
        statusProc.running = true
    }

    implicitHeight: 30
    implicitWidth: expanded ? row.implicitWidth : titleBtn.implicitWidth
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    RowLayout {
        id: row
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        spacing: 0
        layoutDirection: Qt.RightToLeft
        // Title
        Text {
            id: titleBtn
            text: root.titleText
            color: Theme.textPrimary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.bold: true
            leftPadding: 15
            rightPadding: 15

            MouseArea {
                anchors.fill: parent
                onClicked: focusProc.running = true
            }
        }

        // Controls — only visible when expanded
        RowLayout {
            visible: root.expanded
            spacing: 2
            layoutDirection: Qt.RightToLeft

            Repeater {
                model: [
                    { icon: "󰒭", action: "next" },
                    { icon: "󰐊", action: "playpause" }
                ]
                delegate: ModuleButton {
                    required property var modelData

                    implicitWidth: 28
                    implicitHeight: 24
                    radius: 6

                    label: modelData.action === "playpause" ? root.playPauseIcon : modelData.icon

                    onClicked: {
                            if (modelData.action === "playpause")
                                playPauseProc.running = true
                            else
                                nextProc.running = true
                    }
                }
            }

            Item { implicitWidth: 6 }
        }
    }

    // Step 1: find the first Playing player across all known players
    // Output: one player name per line, we pick the first that is Playing
    Process {
        id: activeProc
        command: ["bash", "-c",
            "playerctl -l 2>/dev/null | while read -r p; do " +
            "  if playerctl -p \"$p\" status 2>/dev/null | grep -q Playing; then echo \"$p\"; break; fi; " +
            "done"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var found = text.trim()
                if (found.length > 0) {
                    // Active player found — update cache
                    root.activePlayer = found
                    root.cachedPlayer = found
                } else {
                    // Nothing playing — fall back to cached player if it still exists
                    if (root.cachedPlayer.length > 0) {
                        // verify cached player is still registered
                        cacheCheckProc.running = true
                        return
                    } else {
                        root.activePlayer = ""
                        root.titleText = "󰎆  Nothing playing"
                        root.playPauseIcon = "󰐊"
                        return
                    }
                }
                root.fetchMetadata()
            }
        }
    }

    // Step 2a: verify the cached player still exists in playerctl -l
    Process {
        id: cacheCheckProc
        command: ["bash", "-c",
            "playerctl -l 2>/dev/null | grep -qx " + JSON.stringify(root.cachedPlayer) + " && echo yes || echo no"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "yes") {
                    root.activePlayer = root.cachedPlayer
                    root.fetchMetadata()
                } else {
                    // Cache is stale — clear it
                    root.cachedPlayer = ""
                    root.activePlayer = ""
                    root.titleText = "󰎆  Nothing playing"
                    root.playPauseIcon = "󰐊"
                }
            }
        }
    }

    // Step 3: fetch title + artist for activePlayer, require both (handles closed Chrome tabs)
    Process {
        id: titleProc
        command: ["bash", "-c",
            "title=$(playerctl -p " + JSON.stringify(root.activePlayer) + " metadata --format '{{title}}' 2>/dev/null | head -c 40); " +
            "artist=$(playerctl -p " + JSON.stringify(root.activePlayer) + " metadata --format '{{artist}}' 2>/dev/null); " +
            "[ -n \"$title\" ] && [ -n \"$artist\" ] && echo \"$title\" || echo ''"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim()
                if (t.length > 0) {
                    root.titleText = "󰎆  " + t
                } else {
                    // title/artist missing — treat as nothing playing
                    root.titleText = "󰎆  Nothing playing"
                    root.cachedPlayer = ""
                    root.activePlayer = ""
                }
            }
        }
    }

    // Step 4: fetch status for play/pause icon
    Process {
        id: statusProc
        command: ["bash", "-c",
            "playerctl -p " + JSON.stringify(root.activePlayer) + " status 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.playPauseIcon = text.trim() === "Playing" ? "󰏤" : "󰐊"
            }
        }
    }

    Process {
        id: playPauseProc
        command: ["bash", "-c",
            "playerctl -p " + JSON.stringify(root.activePlayer) + " play-pause"
        ]
        onRunningChanged: if (!running) root.refreshAll()
    }

    Process {
        id: nextProc
        command: ["bash", "-c",
            "playerctl -p " + JSON.stringify(root.activePlayer) + " next"
        ]
        onRunningChanged: if (!running) root.refreshAll()
    }

    Process {
        id: focusProc
        command: ["bash", "-c", (function() {
            var p = root.activePlayer
            var cls = (p.match(/^chromium|^chrome/) ? "google-chrome" : p)
            return "hyprctl dispatch focuswindow class:" + cls
        })()]
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refreshAll()
    }
}

