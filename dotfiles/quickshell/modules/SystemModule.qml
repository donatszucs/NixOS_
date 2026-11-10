// System group — system icon stays fixed right, action buttons slide out below
import QtQuick
import QtQuick.Layouts
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

    leftCornerStyle: "side"
    rightCornerStyle: "bottom"

    implicitHeight: expanded ? baseColumn.implicitHeight + Theme.moduleHeight + systemModule.titleBarHeight + Theme.dropdownMargin : Theme.moduleHeight

    collapsedWidth: 50

    // Overlay dropdown setup
    expandedDropdownWidth: cardWidth + Theme.dropdownMargin * 2
    dropdownAlignment: "right"


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
                BaseCard {
                    id: sysCard
                    Layout.fillWidth: true
                    implicitHeight: headerBar.height + sysContentCol.implicitHeight + Theme.cardPadding * 2
                    hasHeader: true

                    headerContent: [
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 15
                            anchors.rightMargin: 10
                            spacing: 5

                            HoverMarqueeText {
                                id: userNameText
                                text: "User 󰚭"
                                textMaxWidth: 100
                                fontFamily: Theme.font
                                pixelSize: Theme.fontSize + 8
                                fontBold: true
                                textColor: Theme.textPrimary
                                Layout.alignment: Qt.AlignVCenter

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

                            HeaderButton {
                                icon: "󰚰"
                                iconSize: 20
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: updateProc.running = true
                            }

                            HeaderButton {
                                icon: "󱄅"
                                iconSize: 20
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: rebuildProc.running = true
                            }
                        }
                    ]

                    ColumnLayout {
                        id: sysContentCol
                        anchors {
                            top: sysCard.headerBar.bottom
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                            margins: Theme.cardPadding
                        }
                        spacing: 5

                        Repeater {
                            model: [
                                { index: 0, icon: "", text: "Shutdown", cmd: "systemctl poweroff", },
                                { index: 1, icon: "󰌪", text: "Suspend", cmd: "systemctl suspend", },
                                { index: 3, icon: "", text: "Reboot", cmd: "systemctl reboot", },
                                { index: 2, icon: "", text: "Lock", cmd: "hyprlock", }
                            ]
                            delegate: RowLayout {
                                id: actionRow
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.listHeight - 10
                                implicitHeight: Theme.listHeight - 10
                                spacing: 5

                                ModuleButton {
                                    id: actionButton

                                    cursorShape: Qt.PointingHandCursor
                                    variant: "red"

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    implicitHeight: actionRow.implicitHeight

                                    radius: Theme.cardItemRadius
                                    border.width: 2

                                    RowLayout {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10

                                        Rectangle {
                                            color: Theme.palette("neutral").base
                                            topLeftRadius: Math.min(height / 2, actionButton.radius)
                                            bottomLeftRadius: Math.min(height / 2, actionButton.radius)
                                            implicitWidth: 40
                                            implicitHeight: 40

                                            InverseRadius {
                                                anchors.top: parent.top
                                                anchors.left: parent.right
                                                cornerPosition: "topLeft"
                                                color: parent.color
                                                size: Theme.cardItemIconInverseRadius
                                            }

                                            InverseRadius {
                                                anchors.bottom: parent.bottom
                                                anchors.left: parent.right
                                                cornerPosition: "bottomLeft"
                                                color: parent.color
                                                size: Theme.cardItemIconInverseRadius
                                            }

                                            Text {
                                                anchors.fill: parent
                                                text: actionRow.modelData.icon
                                                color: actionButton.textColor
                                                font.family: Theme.font
                                                font.pixelSize: 20
                                                font.bold: true
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }

                                        Text {
                                            text: actionRow.modelData.text
                                            color: actionButton.textColor
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize
                                            font.bold: true
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignLeft
                                        }
                                    }

                                    Process {
                                        id: actionProc
                                        command: ["bash", "-c", actionRow.modelData.cmd]
                                    }

                                    onClicked: actionProc.running = true
                                }

                                ModuleButton {
                                    id: winBtn
                                    visible: actionRow.modelData.index === 3
                                    variant: "red"
                                    cursorShape: Qt.PointingHandCursor
                                    radius: Theme.cardItemRadius
                                    border.width: 2

                                    label: "󰨡"
                                    textFont: 20
                                    Layout.preferredWidth: 40
                                    Layout.fillHeight: true
                                    implicitWidth: 40
                                    implicitHeight: actionRow.implicitHeight

                                    Process {
                                        id: procWin
                                        command: ["bash", "-c", "sudo /run/current-system/sw/bin/efibootmgr --bootnext 0000 && systemctl reboot"]
                                    }
                                    onClicked: procWin.running = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: rebuildProc
        command: [
            "kitty", "--hold", "bash", "-lc",
            "cd ~/nixos-config/nix_files && notify-send -a 'NixOS' -i 'nix-snowflake' -u low -t 3000 'System Rebuild' 'Building NixOS configuration...' && if sudo nixos-rebuild switch --flake .#doni --impure; then nix run nixpkgs#nvd -- diff $(ls -d1v /nix/var/nix/profiles/system-*-link | tail -2); notify-send -a 'NixOS' -i 'nix-snowflake' -u normal -t 5000 'Rebuild Complete' 'System configuration successfully applied'; else notify-send -a 'NixOS' -i 'dialog-error' -u critical 'Rebuild Failed' 'Errors encountered during build'; fi"
        ]
    }

    Process {
        id: updateProc
        command: [
            "kitty", "--hold", "bash", "-lc",
            "cd ~/nixos-config/nix_files && notify-send -a 'NixOS' -i 'nix-snowflake' -u low -t 3000 'Flake Update' 'Updating flake inputs...' && if nix flake update; then notify-send -a 'NixOS' -i 'nix-snowflake' -u normal -t 5000 'Update Complete' 'Flake inputs successfully updated'; else notify-send -a 'NixOS' -i 'dialog-error' -u critical 'Update Failed' 'Errors encountered updating flake inputs'; fi"
        ]
    }
}
