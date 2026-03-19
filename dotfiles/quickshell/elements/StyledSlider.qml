import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Slider {
    Layout.fillWidth: true

    background: Rectangle {
        x: parent.leftPadding
        y: parent.topPadding + parent.availableHeight / 2 - height / 2
        implicitWidth: 200
        implicitHeight: 14
        width: parent.availableWidth
        height: implicitHeight
        radius: 7
        color: Theme.palette("dark").hover

        Rectangle {
            id: progressFill
            width: parent.parent.visualPosition * parent.width
            height: parent.height
            color: parent.pressed ? Theme.palette("dark").hover : Theme.palette("light").base
            radius: 7
        }
    }

    handle: Rectangle {
        color: "transparent"
    }
}