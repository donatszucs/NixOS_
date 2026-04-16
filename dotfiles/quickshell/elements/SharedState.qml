pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications as Notif

Item {
    id: root
    
    // ==========================================
    // Light Switch State
    // ==========================================
    property bool lightActive: true
    property string lightVariant: "light"
    property int lightBrightness: 100
    property int lightHue: 30
    property int lightSaturation: 0
    property string tapoScriptPath: "~/nixos-config/scripts/scriptsEnv/.venv/bin/python ~/nixos-config/scripts/TapoLight/tapo_control.py"

    function refreshLightStatus() {
        lightStatusProc.running = true
        lightBrightnessProc.running = true
        lightColorProc.running = true
    }

    Process {
        id: lightStatusProc
        command: ["bash", "-c", root.tapoScriptPath + " status"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "ON") {
                    root.lightVariant = "light"
                    root.lightActive = true
                } else {
                    root.lightVariant = "dark"
                    root.lightActive = false
                }
            }
        }
    }

    Process {
        id: lightBrightnessProc
        command: ["bash", "-c", root.tapoScriptPath + " brightness"]
        stdout: StdioCollector {
            onStreamFinished: {
                var val = parseInt(text.trim())
                if (!isNaN(val)) {
                    root.lightBrightness = val
                }
            }
        }
    }

    function toggleLight() {
        if (root.lightActive) {
            root.lightVariant = "dark"
            root.lightActive = false
            lightOffProc.running = true
        } else {
            root.lightVariant = "light"
            root.lightActive = true
            lightOnProc.running = true
        }
    }

    Process {
        id: lightOnProc
        command: ["bash", "-c", root.tapoScriptPath + " on"]
        onRunningChanged: if (!running) refreshLightStatus()
    }

    Process {
        id: lightOffProc
        command: ["bash", "-c", root.tapoScriptPath + " off"]
        onRunningChanged: if (!running) refreshLightStatus()
    }

    function setLightBrightness(val) {
        root.lightBrightness = val
        lightSetBrightnessProc.targetBrightness = val
        lightSetBrightnessProc.running = true
    }

    Process {
        id: lightSetBrightnessProc
        property int targetBrightness: 100
        command: ["bash", "-c", root.tapoScriptPath + " set " + targetBrightness]
        onRunningChanged: if (!running) refreshLightStatus()
    }

    Process {
        id: lightColorProc
        command: ["bash", "-c", root.tapoScriptPath + " get_color"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(",")
                if (parts.length === 2) {
                    var h = parseInt(parts[0])
                    var s = parseInt(parts[1])
                    if (!isNaN(h)) root.lightHue = h
                    if (!isNaN(s)) root.lightSaturation = s
                }
            }
        }
    }

    function setLightColor(hue, sat) {
        root.lightHue = hue
        root.lightSaturation = sat
        lightSetColorProc.targetHue = hue
        lightSetColorProc.targetSat = sat
        lightSetColorProc.running = true
    }

    Process {
        id: lightSetColorProc
        property int targetHue: 30
        property int targetSat: 0
        command: ["bash", "-c", root.tapoScriptPath + " color " + targetHue + " " + targetSat]
        onRunningChanged: if (!running) refreshLightStatus()
    }

    property bool muted: false
    property double notifVolume: 0.1

    // ==========================================
    // Night Light (wlsunset) State
    // ==========================================
    property bool nightLightActive: false

    function toggleNightLight() {
        root.nightLightActive = !root.nightLightActive
        if (root.nightLightActive) {
            startNightLightProc.running = false
        } else {
            killNightLightProc.running = false
        }
    }

    Process {
        id: startNightLightProc
        command: ["bash", "-c", "wlsunset -l 47.5 -L 19.0 -t 3500 -T 5000"]
    }

    Process {
        id: killNightLightProc
        command: ["bash", "-c", "pkill wlsunset"]
    }

    function playNotificationSound() {
        if (!root.muted){
            Quickshell.execDetached(["pw-play", "--volume", root.notifVolume, "/home/doni/nixos-config/misc/ping.ogg"])
        }
    }
}