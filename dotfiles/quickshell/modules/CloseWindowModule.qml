// Close active window button
import Quickshell.Hyprland

import "../elements"

ModuleButton {
    label: ""
    variant: "red"
    implicitWidth: Math.ceil(Theme.moduleHeight * 0.7)
    implicitHeight: Math.ceil(Theme.moduleHeight * 0.7)
    radius: implicitHeight / 2
    
    onClicked: Hyprland.dispatch("killactive")
    cursorShape: Qt.PointingHandCursor
}
