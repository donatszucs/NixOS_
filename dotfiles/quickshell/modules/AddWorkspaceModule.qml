// Add empty workspace button
import Quickshell.Hyprland
import "../elements"

ModuleButton {
    label: ""
    variant: "dark"
    implicitWidth: Math.ceil(Theme.moduleHeight * 0.7)
    implicitHeight: Math.ceil(Theme.moduleHeight * 0.7)
    radius: implicitHeight / 2

    onClicked: Hyprland.dispatch("workspace empty")
    cursorShape: Qt.PointingHandCursor
}
