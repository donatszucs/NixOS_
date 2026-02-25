// Control Center — hovers open downward showing network + bluetooth info
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell._Window
import Quickshell.Io
import Quickshell.Bluetooth

ModuleButton {
    id: menuButton

    width: 50
    property Item parentWindow

    state: hovered ? "open" : "closed"

    states: [
        State {
            name: "closed"
            PropertyChanges { target: menuButton; height: Theme.barHeight; color: "gray"}
        },
        State {
            name: "open"
            PropertyChanges { target: menuButton; height: 1000; color: "blue"}
        }
    ]

    transitions: Transition {
        // Automatically animates ALL properties changing between states
        ParallelAnimation {
            ColorAnimation { duration: 300 }
            NumberAnimation { properties: "width,rotation"; duration: 400; easing.type: Easing.OutBack }
        }
    }
}