// Monitor Brightness control — uses ddcutil to control external monitor brightness
import Quickshell.Io
import Quickshell
import QtQuick

import "../elements"

PillBarButton {
    id: root
    
    required property string screenName
    property int displayNumber: {
        var match = screenName.match(/\d+/);
        return match ? parseInt(match[0]) : 1;
    }
    property int brightness: 50
    property string cacheFile: "/tmp/ddc_brightness_disp" + displayNumber
    
    pillVariant: SharedState.nightLightActive ? "light" : "dark"

    percent: brightness
    pillText: brightness + "% "

    // Read brightness from cache on startup
    Component.onCompleted: {
        readCache()
    }

    onClicked: {
        SharedState.toggleNightLight()
    }

    function readCache() {
        readCacheProc.running = true
    }

    function setBrightness(newValue) {
        root.brightness = Math.max(0, Math.min(100, newValue))
        debounceTimer.restart()
    }

    // Read current brightness from cache
    Process {
        id: readCacheProc
        command: ["bash", "-c",
            "if [ -f " + cacheFile + " ]; then cat " + cacheFile + "; else " +
            "VAL=$(ddcutil getvcp 10 --display=" + displayNumber + " --brief 2>/dev/null | awk '{print $4}'); " +
            "[ -z \"$VAL\" ] && VAL=50; echo $VAL | tee " + cacheFile + "; fi"
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

    // Apply brightness to hardware (debounced)
    Process {
        id: applyBrightnessProc
        command: ["bash", "-c", "echo " + root.brightness + " > " + cacheFile + "; ddcutil setvcp 10 " + root.brightness + " --display=" + displayNumber]
    }

    Timer {
        id: debounceTimer
        interval: 1000
        repeat: false
        onTriggered: {
            applyBrightnessProc.running = true
        }
    }

    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
        
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) {
                root.setBrightness(root.brightness + 10)
            } else {
                root.setBrightness(root.brightness - 10)
            }
            wheel.accepted = true
        }
    }
}
