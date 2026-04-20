import QtQuick
import QtQuick.Layouts

ModuleButton {
    id: root

    property int percent: 100
    property string pillText: ""
    property string pillVariant: root.variant
    property var pillPal: Theme.palette(pillVariant)

    label: pillText
    textColor: "transparent"

        // Outer pill background
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 16
        height: Theme.moduleHeight - 8
        radius: height / 2
        color: root.pillPal.pillTrack
        clip: true

        // Inner percentage fill (clipped linearly)
        Item {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: parent.width * (Math.min(root.percent, 100) / 100)
            clip: true
            
            Behavior on width {
                NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }

            Rectangle {
                width: parent.parent.width
                height: parent.parent.height
                radius: parent.parent.radius
                color: root.pillPal.pillFill

                Behavior on color {
                    ColorAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
                }
            }
        }

        // Text inside the pill
        Text {
            anchors.fill: parent
            text: root.pillText
            color: root.pillPal.pillText
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            Behavior on color {
                ColorAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }
        }

        Behavior on color {
            ColorAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
        }
    }
}
