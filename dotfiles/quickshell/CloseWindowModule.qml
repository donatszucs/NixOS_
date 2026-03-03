// Close active window button
import Quickshell.Hyprland

ModuleButton {
    label: ""
    variant: "danger"
    implicitWidth: Math.ceil(Theme.moduleHeight * 0.8)
    implicitHeight: Math.ceil(Theme.moduleHeight * 0.7)

    onClicked: Hyprland.dispatch("killactive")
    cursorShape: Qt.PointingHandCursor
}
