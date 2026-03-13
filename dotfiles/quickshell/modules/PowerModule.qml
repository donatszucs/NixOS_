// Power group — power icon stays fixed right, action buttons slide out to the left
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import "../elements"

ModuleButton {
    id: powerModule
    variant: "dark"
    opacity: Theme.moduleOpacity
    noHoverColorChange: powerModule.expanded
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

    implicitHeight: expanded ? actionColumn.implicitHeight + 10: Theme.moduleHeight
    implicitWidth: expanded ? actionColumn.implicitWidth + 20 : actionColumn.implicitWidth

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }

    // Action buttons — revealed by clip as width expands leftward
    ColumnLayout {
        id: actionColumn
        spacing: 5
        anchors { left: parent.left; right: parent.right; top: parent.top }

        ModuleButton {
            id: mainButton
            colorOverride: !expanded
            noHoverColorChange: !powerModule.expanded            
            bottomLeftRadius: powerModule.expanded ? Theme.moduleEdgeRadius : 0
            bottomRightRadius: bottomLeftRadius
            Layout.alignment: Qt.AlignHCenter
            label: powerModule.expanded ? " Power Menu" : ""
            rightMargin: powerModule.expanded ? 0: 3
            

            cursorShape: Qt.PointingHandCursor
            onClicked: powerModule.expanded = !powerModule.expanded

            Behavior on implicitWidth {
                NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
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
                visible: powerModule.expanded
                required property var modelData
                cursorShape: Qt.PointingHandCursor
                variant: "danger"

                implicitWidth: mainButton.implicitWidth

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
