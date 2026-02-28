// Close active window button
import Quickshell.Hyprland

ModuleButton {
    label: ""
    variant: "danger"
    implicitWidth: 24
    implicitHeight: 24

    onClicked: Hyprland.dispatch("killactive")
}
