// Clock module — updates every second, matches waybar clock style
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import "../elements"

ModuleButton {
    id: root

    property bool expanded: hovered

    noHoverColorChange: true
    noPressColorChange: true

    property string time
    property string date

    function updateTime() {
        var now = new Date()
        time = Qt.formatDateTime(now, "HH:mm:ss")
        date = Qt.formatDateTime(now, "MMM d")
    }

    Component.onCompleted: updateTime()
    implicitWidth: clockBtn.implicitWidth + 10

    ModuleButton {
        anchors.centerIn: parent
        id: clockBtn
        label: ""
        variant: "neutral"
        border.color: pal.border
        border.width: 2
        radius: implicitHeight / 2
        implicitHeight: Theme.moduleHeight - 10
        implicitWidth: clockContent.implicitWidth + 20

        cursorShape: Qt.PointingHandCursor
        onClicked: calendarProc.running = true

        RowLayout {
            id: clockContent
            anchors.centerIn: parent
            spacing: 2

            Text {
                text: root.time
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
            Text {
                text: "|"
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: false
                opacity: 0.5
            }
            Text {
                text: root.date
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
                font.bold: false
                opacity: 0.8
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.updateTime()
    }

    Process {
        id: calendarProc
        command: ["zen", "--new-instance", "-P", "Calendar", "https://calendar.google.com"]
    }
}
