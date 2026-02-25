import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

ModuleButton {
    id: root

    noHoverColorChange: true
    property int openMenus: 0
    property bool expanded: parentHover.hovered || openMenus > 0

    HoverHandler {
        id: parentHover
    }

    // This MUST be assigned when you create the component in your main file
    property var parentWindow: null 

    implicitHeight: 30
    implicitWidth: expanded ? row.implicitWidth - 4 : 32
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
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

        // Tray icon — always visible, fixed at the right
        Text {
            text: "󱊖"
            color: Theme.textPrimary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 1
            font.bold: true
            leftPadding: 11
            rightPadding: 9
        }

        // Tray items — revealed by clip as width expands leftward
        RowLayout {
            visible: root.expanded
            spacing: 6
            layoutDirection: Qt.RightToLeft

            Repeater {
                model: SystemTray.items

                delegate: ModuleButton {
                    id: trayItemDelegate
                    required property var modelData
                    property bool menuOpen: false

                    onMenuOpenChanged: {
                        if (menuOpen) root.openMenus++
                        else root.openMenus--
                    }
                    Component.onDestruction: {
                        if (menuOpen) root.openMenus--
                    }

                    implicitWidth: 28
                    implicitHeight: 24
                    radius: 6

                    Image {
                        anchors.centerIn: parent
                        source: modelData.icon
                        width: 20
                        height: 20
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
                                    let mapped = trayItemDelegate.mapToItem(null, 0, 25)
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

            Item { implicitWidth: 6 }
        }
    }
}
