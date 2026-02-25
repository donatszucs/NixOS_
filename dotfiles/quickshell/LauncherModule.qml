// Launcher button — opens rofi drun
import Quickshell.Io

ModuleButton {
    label: "Menu  "

    Process {
        id: rofiProc
        command: ["rofi", "-show", "drun"]
    }

    onClicked: rofiProc.running = true
}
