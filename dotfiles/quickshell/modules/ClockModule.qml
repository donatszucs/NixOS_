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

    property string hours
    property string minutes
    property string seconds
    property string date

    function updateTime() {
        var now = new Date()
        hours = Qt.formatDateTime(now, "HH")
        minutes = Qt.formatDateTime(now, "mm")
        seconds = Qt.formatDateTime(now, "ss")
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
            spacing: 10

            RowLayout {
                Layout.leftMargin: 10
                spacing: 0

                Text {
                    text: root.hours
                    color: Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                Text {
                    text: ":"
                    color: Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                Text {
                    text: root.minutes
                    color: Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }


                Text {
                    text: ":"
                    color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, Theme.textPrimary.a * 0.5)
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                Text {
                    text: root.seconds
                    color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, Theme.textPrimary.a * 0.5)
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }
            }

            Rectangle {
                color: Qt.rgba(Theme.neutral.base.r, Theme.neutral.base.g, Theme.neutral.base.b, Theme.neutral.base.a * 0.5)
                radius: clockBtn.radius
                implicitWidth: 60
                implicitHeight: Theme.moduleHeight - 10

                Text {
                    anchors.centerIn: parent
                    text: root.date
                    color: Theme.paletteInk
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
