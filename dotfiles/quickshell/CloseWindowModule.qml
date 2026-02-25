// Close active window button
import Quickshell.Hyprland

ModuleButton {
    label: ""
    implicitWidth: 24

    onClicked: Hyprland.dispatch("killactive")
}
