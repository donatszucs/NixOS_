// System group — system icon stays fixed right, action buttons slide out below
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import "../elements"

ExpandableModule {
    id: systemModule
    expandedBottomRightRadius: 0
    property int cardWidth: 200

    pillText: ""
    expandedPillLabel: "System"
    pillPercent: 0
    pillVariant: "neutral"

    leftCornerStyle: "side"
    rightCornerStyle: "bottom"

    expandedHeight: baseColumn.implicitHeight + Theme.moduleHeight + systemModule.titleBarHeight + Theme.dropdownMargin

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


        scale: bodyExpanded ? 1 : 0
        transformOrigin: Item.Top
        Behavior on scale { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutQuint } }

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
                            left: parent.left
                            right: parent.right
                            margins: Theme.cardPadding
                        }
                        spacing: 6

                        Repeater {
                            model: [
                                { icon: "", text: "Shutdown", cmd: "systemctl poweroff", hasWinBtn: false, isPrimary: true },
                                { icon: "󰌪", text: "Suspend",  cmd: "systemctl suspend",  hasWinBtn: false, isPrimary: false },
                                { icon: "", text: "Reboot",   cmd: "systemctl reboot",   hasWinBtn: true,  isPrimary: false },
                                { icon: "", text: "Lock",     cmd: "hyprlock",           hasWinBtn: false, isPrimary: false }
                            ]
                            delegate: RowLayout {
                                id: actionRow
                                required property var modelData
                                readonly property int splitRadius: Math.max(5, Theme.innerElementRadius)

                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.listHeight - 8
                                implicitHeight: Theme.listHeight - 8
                                spacing: 4

                                ListButton {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    implicitHeight: actionRow.implicitHeight

                                    icon: actionRow.modelData.icon
                                    text: actionRow.modelData.text
                                    trailingIcon: actionRow.modelData.hasWinBtn ? "" : "󰅂"
                                    accent: Theme.palette("red").base
                                    accentText: Theme.palette("red").text
                                    active: actionRow.modelData.isPrimary
                                    rightPadding: actionRow.modelData.hasWinBtn ? 8 : 10
                                    topRightRadius: actionRow.modelData.hasWinBtn ? actionRow.splitRadius : Theme.cardItemRadius
                                    bottomRightRadius: actionRow.modelData.hasWinBtn ? actionRow.splitRadius : Theme.cardItemRadius

                                    Process {
                                        id: actionProc
                                        command: ["bash", "-c", actionRow.modelData.cmd]
                                    }
                                    onClicked: actionProc.running = true
                                }

                                ListButton {
                                    visible: actionRow.modelData.hasWinBtn
                                    Layout.preferredWidth: actionRow.implicitHeight
                                    Layout.fillHeight: true
                                    implicitWidth: actionRow.implicitHeight
                                    implicitHeight: actionRow.implicitHeight

                                    iconOnly: true
                                    icon: "󰨡"
                                    accent: Theme.statusBlue
                                    topLeftRadius: actionRow.splitRadius
                                    bottomLeftRadius: actionRow.splitRadius

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
