import QtQuick
import QtQuick.Layouts

ModuleButton {
    id: root

    property real percent: 100
    property bool animatePercent: true
    property string pillText: ""
    property string pillVariant: root.variant
    property var pillPal: Theme.palette(pillVariant)
    property int pillRadius: (Theme.moduleHeight - 10) / 2

    // Smooth percentage animation
    property real animatedPercent: percent
    Behavior on animatedPercent {
        enabled: root.animatePercent
        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    label: pillText
    textColor: "transparent"

        // Outer pill background
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 10
        height: Theme.moduleHeight - 10
        radius: pillRadius
        color: Qt.rgba(root.pillPal.pillTrack.r, root.pillPal.pillTrack.g, root.pillPal.pillTrack.b, root.pillPal.pillTrack.a * root.colorOpacity)
        clip: true

        // Inner percentage fill (clipped linearly)
        Item {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: parent.width * (Math.min(Math.max(root.animatedPercent, 0), 100) / 100)
            clip: true

            Rectangle {
                width: parent.parent.width
                height: parent.parent.height
                radius: parent.parent.radius
                color: Qt.rgba(root.pillPal.pillFill.r, root.pillPal.pillFill.g, root.pillPal.pillFill.b, root.pillPal.pillFill.a * root.colorOpacity)
                Behavior on color {
                    ColorAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
                }
            }
        }

        // Overlay border so it displays evenly over both track and fill colors
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Qt.rgba(root.pillPal.pillBorder.r, root.pillPal.pillBorder.g, root.pillPal.pillBorder.b, root.pillPal.pillBorder.a * root.colorOpacity)
            border.width: 2
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
