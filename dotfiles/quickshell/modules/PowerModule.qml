// Power group — power icon stays fixed right, action buttons slide out to the left
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import "../elements"

ModuleButton {
    id: powerModule
    color: Theme.palette("dark").base
    opacity: Theme.moduleOpacity
    noHoverColorChange: true
    property bool expanded: false
    property color buttonColor: mainButton.color

    topMarginButton: 0 // Removes default margin from ModuleButton

    HoverHandler {
        id: parentHover
        onHoveredChanged: {
            if (!parentHover.hovered && expanded) expanded = false
        }
    }

    bottomLeftRadius: expanded ? Theme.moduleEdgeRadius : Theme.moduleRadius

    implicitHeight: expanded ? actionColumn.implicitHeight + 6: Theme.moduleHeight
    implicitWidth: expanded ? actionColumn.implicitWidth : actionColumn.implicitWidth

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }

    // Action buttons — revealed by clip as width expands leftward
    ColumnLayout {
        id: actionColumn
        spacing: 5
        anchors {
            top: parent.top
            right: parent.right
        }

        ModuleButton {
            id: mainButton
            variant: "light"
            opacity: Theme.moduleOpacity
            noHoverColorChange: !powerModule.expanded
            
            radius: Theme.moduleEdgeRadius

            topLeftRadius: !powerModule.expanded ? Theme.moduleEdgeRadius : 0
            topRightRadius: !powerModule.expanded ? Theme.moduleEdgeRadius : 0
            
            property int padding: (Theme.moduleHeight - Math.ceil(Theme.moduleHeight * 0.75)) / 2

            Layout.alignment: Qt.AlignCenter
            Layout.rightMargin: 6
            Layout.topMargin: powerModule.expanded ? 0 : padding
            Layout.leftMargin: 6
            label: powerModule.expanded ? " Power Menu" : ""
            rightMargin: powerModule.expanded ? 0: 4
            
            implicitHeight: powerModule.expanded ? Theme.moduleHeight: Math.ceil(Theme.moduleHeight * 0.75)
            implicitWidth: powerModule.expanded ? textFont * 10 : Math.ceil(Theme.moduleHeight * 1.25)

            cursorShape: Qt.PointingHandCursor
            onClicked: powerModule.expanded = !powerModule.expanded

            Behavior on implicitWidth {
                NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }

            Behavior on implicitHeight {
                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
            }

            Behavior on Layout.topMargin {
                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
            }
        }

        Repeater {

            model: [
                { index: 0, text: "  Shutdown", cmd: "systemctl poweroff", },
                { index: 1, text: "  Reboot", cmd: "systemctl reboot", },
                { index: 2, text: "  Suspend", cmd: "systemctl suspend", },
                { index: 3, text: "  Lock", cmd: "hyprlock", }
            ]
            delegate: ModuleButton {
                id: actionButton

                required property var modelData
                cursorShape: Qt.PointingHandCursor
                variant: "danger"

                implicitWidth: mainButton.implicitWidth
                implicitHeight: Theme.moduleHeight

                Layout.alignment: Qt.AlignHCenter

                radius: Theme.moduleEdgeRadius

                label: modelData.text
                textAlign: "left"
                leftMargin: 20

                Process {
                    id: actionProc
                    command: ["bash", "-c", modelData.cmd]
                }

                onClicked: actionProc.running = true

            }
        }
    }

    Behavior on color {
        ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
}
