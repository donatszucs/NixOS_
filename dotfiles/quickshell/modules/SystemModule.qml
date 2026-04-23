// System group — system icon stays fixed right, action buttons slide out to the left
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import "../elements"

ModuleButton {
    id: systemModule
    noHoverColorChange: expanded
    noPressColorChange: expanded
    property bool expanded: false
    property color buttonColor: mainButton.color

    HoverHandler {
        id: parentHover
        onHoveredChanged: {
            if (!parentHover.hovered && expanded) expanded = false
        }
    }
    onClicked: if (!expanded) expanded = true
    
    bottomLeftRadius: expanded ? Theme.moduleEdgeRadius + 5 : Theme.moduleRadius

    implicitHeight: expanded ? actionColumn.implicitHeight + 10: Theme.moduleHeight
    implicitWidth: expanded ? actionColumn.implicitWidth + 5 : actionColumn.implicitWidth - 8

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }

    // Action buttons — revealed by clip as width expands leftward
    ColumnLayout {
        id: actionColumn
        spacing: 10
        anchors {
            top: parent.top
            right: parent.right
        }

        PillBarButton {
            id: mainButton
            colorOverride: !expanded
            noHoverColorChange: !expanded
            noPressColorChange: !expanded

            pillVariant: "neutral"


            bottomLeftRadius: systemModule.expanded ? Theme.moduleEdgeRadius : 0
            bottomRightRadius: systemModule.expanded ? Theme.moduleEdgeRadius : 0


            Layout.alignment: Qt.AlignCenter

            pillText: systemModule.expanded ? "System" : ""
            percent: expanded ? 100 : 0

            implicitWidth: systemModule.expanded ? 190 : Math.ceil(Theme.moduleHeight * 1.5)

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton

                onPressedChanged: {
                        if(!systemModule.expanded) {
                            systemModule.pressed = !systemModule.pressed
                        }
                        else {
                            mainButton.pressed = !mainButton.pressed
                        }
                    }
                onClicked: (mouse) => {
                                        systemModule.expanded = !systemModule.expanded
                                    }
            }

            Behavior on implicitWidth {
                NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }

            Behavior on radius {
                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
            }
        }

        Repeater {

            model: [
                { index: 0, icon: "", text: "Shutdown", cmd: "systemctl poweroff", },
                { index: 1, icon: "", text: "Reboot", cmd: "systemctl reboot", },
                { index: 2, icon: "󰌪", text: "Suspend", cmd: "systemctl suspend", },
                { index: 3, icon: "", text: "Lock", cmd: "hyprlock", }
            ]
            delegate: ModuleButton {
                id: actionButton

                required property var modelData
                cursorShape: Qt.PointingHandCursor
                variant: "red"

                implicitWidth: mainButton.implicitWidth
                implicitHeight: Theme.listHeight

                Layout.alignment: Qt.AlignCenter
                Layout.preferredWidth: mainButton.implicitWidth
                Layout.rightMargin: 10
                Layout.leftMargin: 5
                Layout.fillWidth: true

                radius: Theme.moduleEdgeRadius

                RowLayout {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.modulePaddingH
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 15

                    Text {
                        text: actionButton.modelData.icon
                        color: actionButton.textColor
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize * 1.5
                        font.bold: true
                    }

                    Rectangle {

                        width: 4
                        height: Theme.moduleHeight - 10
                        color: Theme.palette("dark").base
                        opacity: 0.5
                        radius: 2
                    }

                    Text {
                        text: actionButton.modelData.text
                        color: actionButton.textColor
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                    }
                }

                Process {
                    id: actionProc
                    command: ["bash", "-c", modelData.cmd]
                }

                onClicked: actionProc.running = true

            }
        }

        // ── System actions ─────────────────────────────
        Rectangle {
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: mainButton.implicitWidth
            Layout.rightMargin: 10
            Layout.leftMargin: 5
            Layout.fillWidth: true
            implicitHeight: Theme.listHeight
            color: Theme.divider
            radius: Theme.moduleEdgeRadius

            RowLayout {
                id: sysRow
                anchors.centerIn: parent
                spacing: 10

                Text {
                    text: "NixOS "
                    color: Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: 22
                    font.bold: true
                }

                ModuleButton {
                    variant: "light"
                    label: "󰚰"
                    textFont: 20

                    cursorShape: Qt.PointingHandCursor
                    onClicked: updateProc.running = true

                    implicitWidth: implicitHeight

                    radius: Theme.moduleEdgeRadius
                }
                
                ModuleButton {
                    variant: "light"
                    label: "󱄅"
                    textFont: 20
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rebuildProc.running = true

                    implicitWidth: implicitHeight

                    radius: Theme.moduleEdgeRadius
                }

            }
        }
    }

    Process {
        id: rebuildProc
        command: ["kitty", "--hold", "bash", "-lc", "cd ~/nixos-config && sudo nixos-rebuild switch --flake .#doni --impure; notify-send 'Rebuild finished'"]
    }

    Process {
        id: updateProc
        command: ["kitty", "--hold", "bash", "-lc", "cd ~/nixos-config && sudo nix flake update; notify-send 'Flake update finished'"]
    }
}
