// Add empty workspace button
import Quickshell.Hyprland

ModuleButton {
    label: ""
    variant: "light"
    implicitWidth: 24
    implicitHeight: 24
    rightMargin: 3

    onClicked: Hyprland.dispatch("workspace empty")
}
