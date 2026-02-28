// Virtual Keyboard button
import Quickshell.Io
import Quickshell
import QtQuick

ModuleButton {
    id: virtualKbrd
    label: ""
    implicitWidth: 30
    implicitHeight: 30
    property bool active: false

    rightMargin: 5

    Process {
        id: startProc
        command: ["bash", "-c", "wvkbd-mobintl -R 10 -L 300 --fn \"JetBrainsMono Nerd Font 20\" --bg 604c6c00 --text 2a202f --fg d5bfe2 --fg-sp 2a202f --text-sp d5bfe2 --press a05dc6 --press-sp a05dc6"]
    }

    Process {
        id: killProc
        command: ["bash", "-c", "pkill wvkbd-mobint"]
    }

    onClicked: {
        virtualKbrd.active = !virtualKbrd.active; // Toggle the state
        
        if (virtualKbrd.active) {
            virtualKbrd.variant = "light"
            startProc.running = true;
        } else {
            virtualKbrd.variant = "dark"
            killProc.running = true;
        }
    }
}