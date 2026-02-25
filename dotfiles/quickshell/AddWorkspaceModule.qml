// Add empty workspace button
import Quickshell.Hyprland

ModuleButton {
    label: ""
    implicitWidth: 24
    rightMargin: 3

    onClicked: Hyprland.dispatch("workspace empty")
}
