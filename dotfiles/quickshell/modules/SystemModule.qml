// System group — system icon stays fixed right, action buttons slide out below
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io

import "../elements"

ExpandableModule {
    id: systemModule
    expandedBottomRightRadius: 0
    property int cardWidth: 200

    pillText: expanded ? "" : ""
    expandedPillLabel: "System"
    pillPercent: 0
    pillVariant: "neutral"
    expandedBottomLeftRadius: Theme.moduleEdgeRadius + 10

    headerPill.bottomRightRadius: 0

    leftCornerStyle: "side"
    rightCornerStyle: "bottom"

    implicitHeight: expanded ? baseColumn.implicitHeight + Theme.moduleHeight + systemModule.titleBarHeight + 15 : Theme.moduleHeight

    collapsedWidth: 50

    // Overlay dropdown setup
    expandedDropdownWidth: cardWidth + 30
    dropdownAlignment: "right"

    Component {
        id: cardShadowEffect
        MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.65)
            shadowBlur: 0.8
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
        }
    }

    ColumnLayout {
        id: baseColumn
        parent: systemModule.overlay
        spacing: 10
        anchors {
            top: parent.top
            topMargin: systemModule.titleBarHeight
            horizontalCenter: parent.horizontalCenter
        }


        scale: expanded ? 1 : 0
        transformOrigin: Item.Top
        Behavior on scale { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

        MouseArea {
            visible: systemModule.contentVisible
            opacity: systemModule.contentOpacity
            implicitWidth: systemModule.cardWidth
            Layout.preferredWidth: systemModule.cardWidth
            Layout.preferredHeight: popupCol.implicitHeight
            Layout.alignment: Qt.AlignHCenter
            acceptedButtons: Qt.NoButton

            ColumnLayout {
                id: popupCol
                width: parent.width
                spacing: 10

                // ── System Actions ─────────────────────────────────────────
                Rectangle {
                    color: Theme.bgBlurColor
                    radius: Theme.moduleEdgeRadius / 2 + 10
                    Layout.fillWidth: true
                    implicitHeight: sysBottomBar.height + sysContentCol.implicitHeight + 20
                    clip: true
                    border.width: 2
                    border.color: Theme.cardBorder

                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: cardShadowEffect

                    InverseRadius {
                        anchors.top: sysBottomBar.bottom
                        anchors.left: sysBottomBar.left
                        cornerPosition: "topLeft"
                        color: sysBottomBar.color
                    }

                    InverseRadius {
                        cornerPosition: "topRight"
                        anchors.top: sysBottomBar.bottom
                        anchors.right: sysBottomBar.right
                        color: sysBottomBar.color
                    }

                    Rectangle {
                        id: sysBottomBar
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 35
                        color: Theme.topBarBlurColor

                        topLeftRadius: parent.radius
                        topRightRadius: parent.radius
                        bottomLeftRadius: 0
                        bottomRightRadius: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 15
                            anchors.rightMargin: 15
                            spacing: 5

                            HoverMarqueeText {
                                id: userNameText
                                text: "User 󰚭"
                                textMaxWidth: 100
                                fontFamily: Theme.font
                                pixelSize: Theme.fontSize + 8
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

                            Item { Layout.fillWidth: true } // spacer

                            ModuleButton {
                                variant: "neutral"
                                label: "󰚰"
                                textFont: 16
                                cursorShape: Qt.PointingHandCursor
                                onClicked: updateProc.running = true
                                implicitHeight: 23
                                implicitWidth: 28
                                radius: Theme.moduleEdgeRadius / 2
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ModuleButton {
                                variant: "neutral"
                                label: "󱄅"
                                textFont: 16
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rebuildProc.running = true
                                implicitHeight: 23
                                implicitWidth: 28
                                radius: Theme.moduleEdgeRadius / 2
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }

                    ColumnLayout {
                        id: sysContentCol
                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                            margins: 10
                        }
                        spacing: 5

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

                                Layout.fillWidth: true
                                implicitHeight: Theme.listHeight - 10

                                radius: Theme.moduleEdgeRadius - 5
                                border.width: 2

                                RowLayout {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
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
                                        Layout.fillWidth: true
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
                                        Layout.rightMargin: 5
                                        

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
                    }
                }
            }
        }
    }

    Process {
        id: rebuildProc
        command: ["kitty", "--hold", "bash", "-lc", "cd ~/nixos-config/nix_files && sudo nixos-rebuild switch --flake .#doni --impure && nix run nixpkgs#nvd -- diff $(ls -d1v /nix/var/nix/profiles/system-*-link | tail -2); notify-send 'Rebuild finished'"]
    }

    Process {
        id: updateProc
        command: ["kitty", "--hold", "bash", "-lc", "cd ~/nixos-config/nix_files && nix flake update; notify-send 'Flake update finished'"]
    }
}
