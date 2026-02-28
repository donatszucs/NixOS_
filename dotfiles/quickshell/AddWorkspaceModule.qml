// Add empty workspace button
import Quickshell.Hyprland

ModuleButton {
    label: ""
    variant: "dark"
    implicitWidth: Theme.moduleHeight * 0.8
    implicitHeight: Theme.moduleHeight * 0.7
    rightMargin: 2

    onClicked: Hyprland.dispatch("workspace empty")
}
