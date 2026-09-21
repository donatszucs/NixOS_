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
    property real scrollStep: 0

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    WheelHandler {
        target: control
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            if (event.angleDelta.y === 0) return
            var range = control.to - control.from
            var defaultStep = (Math.abs(range) <= 1.01) ? 0.02 : Math.max(1, Math.round(Math.abs(range) / 20))
            var singleStep = (control.scrollStep > 0) ? control.scrollStep
                           : ((control.stepSize > 0) ? control.stepSize : defaultStep)

            var notches = Math.round(event.angleDelta.y / 120.0)
            if (notches === 0) notches = (event.angleDelta.y > 0 ? 1 : -1)
            var delta = notches * singleStep

            var minVal = Math.min(control.from, control.to)
            var maxVal = Math.max(control.from, control.to)
            var rawVal = control.value + delta

            var newVal
            if (control.stepSize > 0) {
                newVal = Math.round(rawVal / control.stepSize) * control.stepSize
            } else if (Math.abs(range) <= 1.01) {
                newVal = Math.round(rawVal * 100) / 100.0
            } else {
                newVal = Math.round(rawVal)
            }

            newVal = Math.max(minVal, Math.min(maxVal, newVal))

            if (newVal !== control.value) {
                control.value = newVal
                control.moved()
            }
            event.accepted = true
        }
    }

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
        color: Theme.palette("neutral").base
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