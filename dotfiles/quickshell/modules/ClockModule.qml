// Clock module — updates every second, matches waybar clock style
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import "../elements"

ModuleButton {
    id: root

    property bool expanded: hovered

    color: Theme.palette("dark").base

    property string time
    property string date

    function updateTime() {
        var now = new Date()
        time = Qt.formatDateTime(now, "HH:mm:ss")
        date = Qt.formatDateTime(now, "ddd, MMM d")
    }

    Component.onCompleted: updateTime()

    implicitWidth: timeRow.implicitWidth + 20

    RowLayout {
        id: timeRow
        anchors.centerIn: parent
        spacing: 0
        ModuleButton {
            id: dateLabel
            label: root.date
            variant: "light"
            implicitWidth: root.expanded ? root.textFont * 8 : 0
            radius: implicitHeight / 2
            implicitHeight: Theme.moduleHeight - 8
            opacity: root.expanded ? 1 : 0

            cursorShape: Qt.PointingHandCursor
            onClicked: calendarProc.running = true

            Behavior on opacity {
                NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }

            Behavior on implicitWidth {
                NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }
        }

        Rectangle {
            implicitWidth: root.expanded ? 10 : 0
            height: timeRow.implicitHeight
            color: "transparent"

            Behavior on implicitWidth {
                NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }
        }
        ModuleButton {
            label: root.time
            variant: "light"
            implicitWidth: textFont * 8
            radius: implicitHeight / 2
            implicitHeight: Theme.moduleHeight - 8
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
