pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications as Notif

Item {
    id: root

    // ==========================================
    // Mod Switcher State
    // ==========================================
    property string modVariant: "dark"
    property string modLabel: "󰍽"

    readonly property string modDevice: "Keychron  Keychron Link "
    readonly property string modPreset: "SuperMouse"
    readonly property string modStateFile: "/tmp/input_remapper_state"

    function refreshModSwitcher() {
        modStateCheckProc.running = true
    }

    Process {
        id: modStateCheckProc
        command: ["bash", "-c", `[ -f "${root.modStateFile}" ] && echo "on" || echo "off"`]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "on") {
                    root.modVariant = "light"
                    root.modLabel = "󱗼"
                } else {
                    root.modVariant = "dark"
                    root.modLabel = "󰍽"
                }
            }
        }
    }

    function toggleModSwitcher() {
        modToggleCheckProc.running = true
    }

    Process {
        id: modToggleCheckProc
        command: ["bash", "-c", `[ -f "${root.modStateFile}" ] && echo "on" || echo "off"`]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "on") {
                    // Optimistically set UI to off
                    root.modVariant = "dark"
                    root.modLabel = "󰍽"
                    modStopProc.running = true
                } else {
                    // Optimistically set UI to on
                    root.modVariant = "light"
                    root.modLabel = "󱗼"
                    modStartProc.running = true
                }
            }
        }
    }

    Process {
        id: modStopProc
        command: ["bash", "-c", `input-remapper-control --command stop --device "${root.modDevice}" --preset "${root.modPreset}" && rm -f "${root.modStateFile}"`]
        stdout: StdioCollector {
            onStreamFinished: root.refreshModSwitcher()
        }
    }

    Process {
        id: modStartProc
        command: ["bash", "-c", `input-remapper-control --command start --device "${root.modDevice}" --preset "${root.modPreset}" && touch "${root.modStateFile}"`]
        stdout: StdioCollector {
            onStreamFinished: root.refreshModSwitcher()
        }
    }

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
    property double notifVolume: 0.3

    function playNotificationSound() {
        if (!root.muted){
            Quickshell.execDetached(["pw-play", "--volume", root.notifVolume, "/home/doni/nixos-config/misc/ping.ogg"])
        }
    }
}