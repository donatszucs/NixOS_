// Power group — power icon stays fixed right, action buttons slide out to the left
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ModuleButton {
    id: powerModule
    variant: "danger"
    noHoverColorChange: true
    property bool expanded: parentHover.hovered

    HoverHandler {
        id: parentHover
    }

    bottomLeftRadius: expanded ? Theme.moduleEdgeRadius : Theme.moduleRadius

    implicitHeight: expanded ? Theme.moduleHeight * 4 : Theme.moduleHeight
    implicitWidth: expanded ? 100 : 32

    Behavior on implicitWidth {
        NumberAnimation { duration: horizontalDuration; easing.type: Easing.OutCubic }
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    Text {
        visible: !powerModule.expanded
        id: powerIcon
        text: ""
        color: Theme.transparentRed.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter

        NumberAnimation on opacity {
                    from: 0.0
                    to: 1.0
                    duration: horizontalDuration
                    easing.type: Easing.OutCubic
                }
    }

    // Action buttons — revealed by clip as width expands leftward
    ColumnLayout {
        id: actionColumn
        visible: powerModule.expanded
        spacing: 0
        Repeater {
            model: [
                { icon: "", cmd: "systemctl poweroff",   tip: "Shutdown", },
                { icon: "", cmd: "systemctl reboot",   tip: "Reboot", },
                { icon: "", cmd: "systemctl suspend",  tip: "Suspend", },
                { icon: "", cmd: "hyprlock",           tip: "Lock", }
            ]
            delegate: ModuleButton {
                required property var modelData
                variant: "transparentRed"
                implicitWidth: expanded ? 100 : 28

                radius: 0

                bottomLeftRadius: (modelData.tip === "Lock") ? Theme.moduleEdgeRadius : 0

                rightMargin: 12
                textAlign: "right"

                label: expanded ? modelData.tip + " " + modelData.icon : modelData.icon

                Process {
                    id: actionProc
                    command: ["bash", "-c", modelData.cmd]
                }

                onClicked: actionProc.running = true

            }
        }
    }

    Process {
        id: powerOffProc
        command: ["bash", "-c", "systemctl poweroff"]
    }
}
