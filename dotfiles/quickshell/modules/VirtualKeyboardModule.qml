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
        command: ["bash", "-c", "wvkbd-mobintl -R 10 -L 260 -W 960 --fn \"RobotoMono Nerd Font 14\" --bg 1f1f1ff0 --text 1f1f1f --fg e5c2f7 --fg-sp 2d2d2d --text-sp e5c2f7 --press b886d4 --press-sp a05dc6"]
        onExited: {
            virtualKbrd.active = false;
        }
    }

    Process {
        id: killProc
        command: ["bash", "-c", "pkill -f wvkbd"]
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