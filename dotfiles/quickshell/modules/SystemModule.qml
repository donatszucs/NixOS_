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
    
    bottomLeftRadius: expanded ? Theme.moduleEdgeRadius + 10 : 0

    implicitHeight: expanded ? actionColumn.implicitHeight + 10: Theme.moduleHeight
    implicitWidth: mainButton.implicitWidth

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


            Layout.alignment: Qt.AlignCenter

            pillText: systemModule.expanded ? "System" : ""
            percent: expanded ? 100 : 0

            implicitWidth: systemModule.expanded ? 200 : 50

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

        InverseRadius {
            id: corner
            cornerPosition: "topRight"
            color: mainButton.color
            size: Theme.moduleEdgeRadius

            Layout.alignment: Qt.AlignTop | Qt.AlignRight
            Layout.topMargin: -10

        }
        
        Repeater {

            model: [
                { index: 0, icon: "", text: "Shutdown", cmd: "systemctl poweroff", },
                { index: 1, icon: "󰌪", text: "Suspend", cmd: "systemctl suspend", },
                { index: 3, icon: "", text: "Reboot", cmd: "systemctl reboot", },
                { index: 2, icon: "", text: "Lock", cmd: "hyprlock", }
            ]
            delegate: ModuleButton {
                id: actionButton

                required property var modelData
                cursorShape: Qt.PointingHandCursor
                variant: "red"

                implicitHeight: Theme.listHeight - 10

                Layout.alignment: Qt.AlignCenter
                Layout.preferredWidth: mainButton.implicitWidth - 20
                Layout.topMargin: actionButton.modelData.index === 0 ? (- corner.size) : 0

                radius: Theme.moduleEdgeRadius - 5
                border.width: 2

                RowLayout {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {
                        color: Qt.rgba(Theme.neutral.base.r, Theme.neutral.base.g, Theme.neutral.base.b, Theme.neutral.base.a)
                        topLeftRadius: Theme.moduleEdgeRadius - 5
                        bottomLeftRadius: Theme.moduleEdgeRadius - 5
                        implicitWidth: 40
                        implicitHeight: 40

                        InverseRadius {
                            anchors.top: parent.top
                            anchors.left: parent.right
                            cornerPosition: "topLeft"
                            color: parent.color
                            size: 10
                        }

                        InverseRadius {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.right
                            cornerPosition: "bottomLeft"
                            color: parent.color
                            size: 10
                        }

                        Text {
                            anchors.fill: parent
                            text: actionButton.modelData.icon
                            color: actionButton.textColor
                            font.family: Theme.font
                            font.pixelSize: 20
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        text: actionButton.modelData.text
                        color: actionButton.textColor
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        Layout.preferredWidth: actionButton.modelData.index === 3 ? actionButton.Layout.preferredWidth - 65 - winBtn.implicitWidth : actionButton.Layout.preferredWidth - 55
                        horizontalAlignment: Text.AlignLeft
                    }

                    ModuleButton {
                        id: winBtn
                        visible: actionButton.modelData.index === 3
                        variant: "neutral"
                        cursorShape: Qt.PointingHandCursor
                        radius: Theme.moduleEdgeRadius - 8

                        colorOpacity: 2.0
                        textColor: Theme.palette("red").text

                        label: "󰨡"
                        textFont: 20
                        border.width: 0
                        implicitWidth: 40
                        implicitHeight: 30
                        

                        Process {
                            id: procWin
                            command: ["bash", "-c", "sudo /run/current-system/sw/bin/efibootmgr --bootnext 0000 && systemctl reboot"]
                        }
                        onClicked: procWin.running = true
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
            Layout.preferredWidth: mainButton.implicitWidth - 20
            implicitHeight: Theme.listHeight
            color: Theme.divider
            radius: Theme.moduleEdgeRadius

            RowLayout {
                id: sysRow
                anchors.centerIn: parent
                spacing: 10

                HoverMarqueeText {
                    id: userNameText
                    text: "User 󰚭"
                    textMaxWidth: 80
                    fontFamily: Theme.font
                    pixelSize: 24
                    fontBold: true
                    textColor: Theme.textPrimary

                    Process {
                        command: ["whoami"]
                        running: true
                        stdout: StdioCollector {
                            onStreamFinished: {
                                var username = text.trim();
                                if (username.length > 0) {
                                    userNameText.text = username.charAt(0).toUpperCase() + username.slice(1)
                                }
                            }
                        }
                    }
                }

                ModuleButton {
                    variant: "light"
                    label: "󰚰"
                    textFont: 20

                    cursorShape: Qt.PointingHandCursor
                    onClicked: updateProc.running = true

                    implicitHeight: 30
                    implicitWidth: implicitHeight

                    radius: Theme.moduleEdgeRadius

                    border.width: 2
                }
                
                ModuleButton {
                    variant: "light"
                    label: "󱄅"
                    textFont: 20
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rebuildProc.running = true

                    implicitHeight: 30
                    implicitWidth: implicitHeight

                    radius: Theme.moduleEdgeRadius

                    border.width: 2
                }

            }
        }
    }

    Process {
        id: rebuildProc
        command: ["kitty", "--hold", "bash", "-lc", "cd ~/nixos-config/nix_files && sudo nixos-rebuild switch --flake .#doni --impure; notify-send 'Rebuild finished'"]
    }

    Process {
        id: updateProc
        command: ["kitty", "--hold", "bash", "-lc", "cd ~/nixos-config/nix_files && sudo nix flake update; notify-send 'Flake update finished'"]
    }
}
