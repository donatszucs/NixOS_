// Close active window button
import Quickshell.Hyprland

import "../elements"

ModuleButton {
    label: ""
    variant: "danger"
    opacity: Theme.moduleOpacity
    implicitWidth: Math.ceil(Theme.moduleHeight * 0.8)
    implicitHeight: Math.ceil(Theme.moduleHeight * 0.7)

    onClicked: Hyprland.dispatch("killactive")
    cursorShape: Qt.PointingHandCursor
}
