// Clock module — updates every second, matches waybar clock style
import QtQuick
import Quickshell.Io

ModuleButton {
    id: root

    function updateTime() {
        label = Qt.formatDateTime(new Date(), "HH:mm:ss")
    }

    Component.onCompleted: updateTime()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.updateTime()
    }

    Process {
        id: calendarProc
        command: ["google-chrome-stable", "--app=https://calendar.google.com"]
    }

    onClicked: calendarProc.running = true
}
