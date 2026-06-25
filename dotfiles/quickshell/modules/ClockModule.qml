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
        implicitWidth: clockContent.implicitWidth

        cursorShape: Qt.PointingHandCursor
        onClicked: calendarProc.running = true

        RowLayout {
            id: clockContent
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: 15

            Text {
                text: root.time
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
                Layout.leftMargin: 15
            }

            Rectangle {
                color: Qt.rgba(Theme.neutral.base.r, Theme.neutral.base.g, Theme.neutral.base.b, Theme.neutral.base.a * 0.7)
                topRightRadius: clockBtn.radius
                bottomRightRadius: clockBtn.radius
                implicitWidth: 60
                implicitHeight: Theme.moduleHeight - 10

                InverseRadius {
                    anchors.top: parent.top
                    anchors.right: parent.left
                    cornerPosition: "topRight"
                    color: parent.color
                    size: clockBtn.radius
                }

                InverseRadius {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.left
                    cornerPosition: "bottomRight"
                    color: parent.color
                    size: clockBtn.radius
                }

                Text {
                    anchors.centerIn: parent
                    text: root.date
                    color: "black"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    font.bold: false
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
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
