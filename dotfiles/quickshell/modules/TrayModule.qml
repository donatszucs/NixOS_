import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

import "../elements"

ModuleButton {
    id: root
    color: "transparent"
    property int openMenus: 0
    property bool expanded: hovered || openMenus > 0

    // This MUST be assigned when you create the component in your main file
    property var parentWindow: null 

    implicitWidth: expanded ? row.implicitWidth : notificationButton.implicitWidth
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    Process {
        id: missioncenterProcess
        command: ["bash", "-c", "missioncenter"]
    }

    RowLayout {
        id: row
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
        }
        spacing: 0
        layoutDirection: Qt.RightToLeft

        ModuleButton {
            id: notificationButton
            cursorShape: Qt.PointingHandCursor
            label: "󱊖"
            textFont: Theme.fontSize + 2

            onClicked: missioncenterProcess.running = true

        }
        ModuleButton {
            id: trayButton
            color: Theme.palette("dark").base
            Layout.preferredWidth: trayBackground.width + 10
            Layout.preferredHeight: Theme.moduleHeight
            
            // Tray items — revealed by clip as width expands leftward
            Rectangle {
                id: trayBackground
                Layout.alignment: Qt.AlignCenter
                width: trayRow.implicitWidth + 10
                implicitHeight: Theme.moduleHeight * 0.7
                color: Theme.divider
                radius: Theme.moduleEdgeRadius / 2
                anchors.centerIn: parent

                RowLayout {
                    id: trayRow
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    anchors.rightMargin: 5
                    spacing: 5
                    layoutDirection: Qt.RightToLeft

                    Repeater {
                        model: SystemTray.items

                        delegate: ModuleButton {
                            id: trayItemDelegate
                            colorOverride: true
                            noHoverColorChange: true
                            required property var modelData
                            property bool menuOpen: false

                            onMenuOpenChanged: {
                                if (menuOpen) root.openMenus++
                                else root.openMenus--
                            }
                            Component.onDestruction: {
                                if (menuOpen) root.openMenus--
                            }

                            implicitWidth: Theme.moduleHeight * 0.7
                            implicitHeight: Theme.moduleHeight * 0.7
                            radius: 6

                            Image {
                                anchors.centerIn: parent
                                // Quickshell doesn't support the "iconName?path=..." format
                                // that some apps (e.g. Spotify) use. Detect it and build
                                // a direct file:// URL; fall back to the native value otherwise
                                // so Quickshell's image provider still resolves XDG icon names.
                                source: {
                                    var s = String(modelData.icon)
                                    var idx = s.indexOf("?path=")
                                    if (idx !== -1) {
                                        var nameOnly = s.substring(0, idx).split("/").pop()
                                        var dir = s.substring(idx + 6)
                                        return "file://" + dir + "/" + nameOnly + ".png"
                                    }
                                    return modelData.icon
                                }
                                width: Theme.moduleHeight * 0.6
                                height: Theme.moduleHeight * 0.6
                                sourceSize.width: 20
                                sourceSize.height: 20
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            // 1. Define the Menu Anchor
                            QsMenuAnchor {
                                id: menuAnchor
                                menu: modelData.menu
                                
                                // Use the explicitly passed window
                                anchor.window: root.parentWindow 
                                
                                // Width and height can be bound directly
                                anchor.rect.width: trayItemDelegate.width
                                anchor.rect.height: trayItemDelegate.height

                                onOpened: trayItemDelegate.menuOpen = true
                                onClosed: trayItemDelegate.menuOpen = false
                            }

                            // 2. Trigger the anchor to open
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        if (modelData.hasMenu && root.parentWindow !== null) {
                                            // Map the icon's local coordinates to the main scene (window)
                                            let mapped = trayItemDelegate.mapToItem(null, 0, 30)
                                            menuAnchor.anchor.rect.x = mapped.x
                                            menuAnchor.anchor.rect.y = mapped.y
                                            
                                            menuAnchor.open()
                                        } else if (root.parentWindow === null) {
                                            console.warn("Tray Error: parentWindow is null! Did you pass it in main.qml?")
                                        }
                                    } else {
                                        modelData.activate()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
