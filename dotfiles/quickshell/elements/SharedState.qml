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
        if (!lightRefreshProc.running) {
            lightRefreshProc.running = true
        }
    }

    Process {
        id: lightRefreshProc
        command: ["bash", "-c", root.tapoScriptPath + " state"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(",")
                if (parts.length >= 4) {
                    if (parts[0] === "ON") {
                        root.lightVariant = "light"
                        root.lightActive = true
                    } else {
                        root.lightVariant = "dark"
                        root.lightActive = false
                    }
                    var b = parseInt(parts[1])
                    var h = parseInt(parts[2])
                    var s = parseInt(parts[3])
                    if (!isNaN(b)) root.lightBrightness = b
                    if (!isNaN(h)) root.lightHue = h
                    if (!isNaN(s)) root.lightSaturation = s
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
            startNightLightProc.running = true
        } else {
            killNightLightProc.running = true
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