// Mod switcher — toggles input-remapper preset, light theme like waybar
import QtQuick
import Quickshell.Io

ModuleButton {
    id: root
    variant: "light"
    label: "󰍽"
    implicitWidth: 30
    implicitHeight: 30

    readonly property string device: "Keychron  Keychron Link "
    readonly property string preset: "SuperMouse"
    readonly property string stateFile: "/tmp/input_remapper_state"

    function refresh() {
        stateCheckProc.running = true
    }

    // Check state file to update icon
    Process {
        id: stateCheckProc
        command: ["bash", "-c", `[ -f "${root.stateFile}" ] && echo "󱗼" || echo "󰍽"`]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var v = text.trim()
                if (v.length > 0) root.label = v
            }
        }
    }

    // Stop preset: remove state file, update icon
    Process {
        id: stopProc
        command: ["bash", "-c", `input-remapper-control --command stop --device "${root.device}" --preset "${root.preset}" && rm -f "${root.stateFile}"`]
        stdout: StdioCollector {
            onStreamFinished: root.refresh()
        }
    }

    // Start preset: create state file, update icon
    Process {
        id: startProc
        command: ["bash", "-c", `input-remapper-control --command start --device "${root.device}" --preset "${root.preset}" && touch "${root.stateFile}"`]
        stdout: StdioCollector {
            onStreamFinished: root.refresh()
        }
    }

    // Check file to decide toggle direction
    Process {
        id: toggleCheckProc
        command: ["bash", "-c", `[ -f "${root.stateFile}" ] && echo "on" || echo "off"`]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "on") {
                    root.variant = "light"
                    root.label = "󰍽"
                    stopProc.running = true
                } else {
                    root.variant = "dark"
                    root.label = "󱗼"
                    startProc.running = true
                }
            }
        }
    }

    onClicked: toggleCheckProc.running = true
}
