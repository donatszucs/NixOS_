// Virtual Keyboard button
import Quickshell.Io
import Quickshell
import QtQuick

import "../elements"

PillBarButton {
    id: virtualKbrd
    pillText: ""
    pillVariant: virtualKbrd.active ? "light" : "neutral"
    percent: virtualKbrd.active ? 100 : 0
    cursorShape: Qt.PointingHandCursor
    property bool active: false


    Process {
        id: startProc
        command: ["bash", "-c", "wvkbd-mobintl -R 10 -L 300 --fn \"RobotoMono Nerd Font 20\" --bg 604c6c98 --text 2a202f --fg d5bfe2 --fg-sp 2a202f --text-sp d5bfe2 --press a05dc6 --press-sp a05dc6"]
    }

    Process {
        id: killProc
        command: ["bash", "-c", "pkill wvkbd-mobint"]
    }

    onClicked: {
        virtualKbrd.active = !virtualKbrd.active; // Toggle the state
        
        if (virtualKbrd.active) {
            startProc.running = true;
        } else {
            killProc.running = true;
        }
    }
}