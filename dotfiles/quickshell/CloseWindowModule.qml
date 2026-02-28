// Close active window button
import Quickshell.Hyprland

ModuleButton {
    label: ""
    variant: "danger"
    implicitWidth: Theme.moduleHeight * 0.8
    implicitHeight: Theme.moduleHeight * 0.7

    onClicked: Hyprland.dispatch("killactive")
}
