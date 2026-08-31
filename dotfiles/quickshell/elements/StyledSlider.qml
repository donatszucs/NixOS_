import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Slider {
    id: control
    Layout.fillWidth: true

    property int sliderHeight: 30
    property int radius: 7
    property int topLeftRadius: radius
    property int topRightRadius: radius
    property int bottomLeftRadius: radius
    property int bottomRightRadius: radius

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: 200
        implicitHeight: control.sliderHeight
        width: control.availableWidth
        height: implicitHeight
        radius: control.radius
        topLeftRadius: control.topLeftRadius
        topRightRadius: control.topRightRadius
        bottomLeftRadius: control.bottomLeftRadius
        bottomRightRadius: control.bottomRightRadius
        color: Theme.palette("neutral").hover
        border.width: 2
        border.color: Theme.palette("neutral").border

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 2

            id: progressFill
            width: control.visualPosition * parent.width - 4
            height: parent.height - 4
            color: control.pressed ? Theme.palette("light").pressed : Theme.palette("light").base
            border.color: Theme.palette("light").border
            radius: control.radius
            topLeftRadius: control.topLeftRadius
            topRightRadius: control.topRightRadius
            bottomLeftRadius: control.bottomLeftRadius
            bottomRightRadius: control.bottomRightRadius
        }
    }

    handle: Rectangle {
        color: "transparent"
    }
}