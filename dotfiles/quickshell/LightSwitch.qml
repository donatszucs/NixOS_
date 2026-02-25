// Tapo Light Switch button — toggles smart bulb on/off with brightness control
import Quickshell.Io
import Quickshell
import QtQuick

ModuleButton {
    id: root
    implicitHeight: 30
    property bool active: true
    variant: "light"

    property int brightness: 100

    label: root.active ? brightness + "% 󱩒" : " Off 󱩎"

    // Read status and brightness on startup
    Component.onCompleted: {
        refreshAll()
    }

    function refreshAll() {
        statusProc.running = true
        brightnessProc.running = true
    }

    Process {
        id: statusProc
        command: ["bash", "-c",
            "~/.config/waybar/scripts/.venv/bin/python ~/.config/waybar/scripts/tapo_control.py status"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "ON") {
                    root.variant = "light"
                    root.active = true
                } else {
                    root.variant = "dark"
                    root.active = false
                }
            }
        }
    }

    Process {
        id: brightnessProc
        command: ["bash", "-c",
            "~/.config/waybar/scripts/.venv/bin/python ~/.config/waybar/scripts/tapo_control.py brightness"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var val = parseInt(text.trim())
                if (!isNaN(val)) {
                    root.brightness = val
                }
            }
        }
    }

    Process {
        id: onProc
        command: ["bash", "-c",
            "~/.config/waybar/scripts/.venv/bin/python ~/.config/waybar/scripts/tapo_control.py on"
        ]
        onRunningChanged: if (!running) refreshAll()
    }

    Process {
        id: offProc
        command: ["bash", "-c",
            "~/.config/waybar/scripts/.venv/bin/python ~/.config/waybar/scripts/tapo_control.py off"
        ]
        onRunningChanged: if (!running) refreshAll()
    }

    Process {
        id: setBrightnessProc
        property int targetBrightness: 100
        command: ["bash", "-c",
            "~/.config/waybar/scripts/.venv/bin/python ~/.config/waybar/scripts/tapo_control.py set " + targetBrightness
        ]
        onRunningChanged: if (!running) refreshAll()
    }

    Timer {
        id: debounceTimer
        interval: 1000
        repeat: false
        onTriggered: {
            setBrightnessProc.targetBrightness = root.brightness
            setBrightnessProc.running = true
        }
    }

    onClicked: {
        if (root.active) {
            lightTheme = false
            offProc.running = true
        } else {
            lightTheme = true
            onProc.running = true
        }
    }

    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        acceptedButtons: Qt.NoButton
        
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) {
                // Scroll up - increase brightness
                root.brightness = Math.min(100, root.brightness + 10)
            } else {
                // Scroll down - decrease brightness
                root.brightness = Math.max(1, root.brightness - 10)
            }
            
            // Restart debounce timer
            debounceTimer.restart()
            wheel.accepted = true
        }
    }
}
