// Monitor Brightness control — uses ddcutil to control external monitor brightness
import Quickshell.Io
import Quickshell
import QtQuick

ModuleButton {
    id: root
    implicitHeight: 30
    variant: "light"

    required property string screenName
    property int displayNumber: screenName === "DP-1" ? 1 : 2
    property int brightness: 50
    property string cacheFile: "/tmp/ddc_brightness_disp" + displayNumber

    label: brightness + "% "

    // Read brightness from cache on startup
    Component.onCompleted: {
        readCache()
    }

    function readCache() {
        readCacheProc.running = true
    }

    function setBrightness(newValue) {
        root.brightness = Math.max(0, Math.min(100, newValue))
        writeCacheProc.command = ["bash", "-c", "echo " + root.brightness + " > " + cacheFile]
        writeCacheProc.running = true
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

    // Write new brightness to cache
    Process {
        id: writeCacheProc
        command: ["bash", "-c", ""]
    }

    // Apply brightness to hardware (debounced)
    Process {
        id: applyBrightnessProc
        command: ["bash", "-c",
            "FINAL_VAL=$(cat " + cacheFile + "); " +
            "ddcutil setvcp 10 $FINAL_VAL --display=" + displayNumber
        ]
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
