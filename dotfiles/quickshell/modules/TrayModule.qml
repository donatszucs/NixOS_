import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

import "../elements"

ExpandableModule {
    id: root

    collapseOnHoverExit: false   // managed manually (menu-aware)
    useDefaultPill: false

    property int openMenus: 0

    HoverHandler {
        id: parentHover
        onHoveredChanged: {
            if (!parentHover.hovered && !root.isHovered && expanded && openMenus === 0) expanded = false
            else if (parentHover.hovered && !expanded) expanded = true
        }
    }

    onIsHoveredChanged: {
        if (!isHovered && !parentHover.hovered && expanded && openMenus === 0) {
            expanded = false
        }
    }

    onOpenMenusChanged: {
        if (openMenus === 0 && !parentHover.hovered && !root.isHovered && expanded) {
            expanded = false
        }
    }

    // This MUST be assigned when you create the component in your main file
    property var parentWindow: null
    shrinkEnabled: false
    
    collapsedWidth: topRow.implicitWidth
    
    implicitHeight: expanded ? trayCard.implicitHeight + Theme.moduleHeight + Theme.pillExpandedMargin * 2 : Theme.moduleHeight

    // Overlay dropdown setup
    expandedDropdownWidth: Math.max(topRow.implicitWidth, trayCard.implicitWidth + Theme.pillExpandedMargin * 2)
    dropdownAlignment: "center"

    expandedBottomLeftRadius: expandedDropdownWidth / 2
    expandedBottomRightRadius: expandedDropdownWidth / 2

    leftCornerStyle: "side"
    rightCornerStyle: "side"

    Process {
        id: missioncenterProcess
        command: ["bash", "-c", "missioncenter"]
    }

    RowLayout {
        id: topRow
        z: 10
        spacing: 0
        layoutDirection: Qt.RightToLeft
        anchors {
            right: parent.right
            top: parent.top
        }

        HeaderButton {
            id: notificationButton
            z: 1
            icon: "󱊖"
            implicitWidth: Theme.moduleHeight + 6
            implicitHeight: Theme.moduleHeight
            label: "󱊖"
            textFont: Theme.fontSize + 1

            bottomRightRadius: root.expanded ? Theme.moduleEdgeRadius : 0
            bottomLeftRadius: root.expanded ? Theme.moduleEdgeRadius : 0

            onClicked: missioncenterProcess.running = true
        }
    }

    // Tray items — revealed in the overlay below the header
    BaseCard {
        id: trayCard
        parent: root.overlay
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.pillExpandedMargin
        
        color: Theme.divider
        radius: implicitWidth / 2

        border.width: Theme.cardBorderWidth
        border.color: Theme.cardBorder

        implicitWidth: trayColumn.implicitWidth + 12
        implicitHeight: trayColumn.implicitHeight + 12

        // Visible when expanded or animating close (clipped)
        visible: root.contentVisible && trayColumn.implicitHeight > 0
        opacity: root.contentOpacity

        ColumnLayout {
            id: trayColumn
            anchors.centerIn: parent
            spacing: 5

            Repeater {
                model: SystemTray.items

                delegate: ModuleButton {
                    variant: "neutral"
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

                    implicitWidth: Theme.moduleHeight * 0.7
                    implicitHeight: Theme.moduleHeight * 0.7
                    radius: implicitHeight / 2
                    border.width: 2

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
                        width: Theme.moduleHeight - 20
                        height: Theme.moduleHeight - 20
                        sourceSize.width: 20
                        sourceSize.height: 20
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    // 1. Define the Menu Anchor
                    QsMenuAnchor {
                        id: menuAnchor
                        menu: modelData.menu
                        
                        // Use explicit parentWindow if provided, otherwise resolve from Window attached property
                        anchor.window: root.parentWindow ?? root.Window.window 
                        
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
                                var win = root.parentWindow ?? root.Window.window
                                if (modelData.hasMenu && win !== null) {
                                    // Map the icon's local coordinates to the main scene (window)
                                    let mapped = trayItemDelegate.mapToItem(null, 0, 30)
                                    menuAnchor.anchor.rect.x = mapped.x
                                    menuAnchor.anchor.rect.y = mapped.y
                                    
                                    menuAnchor.open()
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
