// Add empty workspace button
import Quickshell.Hyprland
import "../elements"

ModuleButton {
    label: ""
    variant: "dark"
    implicitWidth: Math.ceil(Theme.moduleHeight * 0.8)
    implicitHeight: Math.ceil(Theme.moduleHeight * 0.7)
    rightMargin: 2

    onClicked: Hyprland.dispatch("workspace empty")
    cursorShape: Qt.PointingHandCursor
}
