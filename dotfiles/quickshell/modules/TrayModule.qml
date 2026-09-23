import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

import "../elements"

ExpandableModule {
    id: root

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
    
    implicitHeight: expanded ? trayCard.implicitHeight + Theme.moduleHeight + 10 : Theme.moduleHeight

    // Overlay dropdown setup
    expandedDropdownWidth: Math.max(topRow.implicitWidth, trayCard.implicitWidth + 10)
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

        ModuleButton {
            id: notificationButton
            z: 1
            variant: "neutral"
            colorOverride: true
            overrideColor: "transparent"
            hoverColor: Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.22)
            pressedColor: Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.45)
            textColor: notificationButton.pressed
                ? "#ffffff"
                : (notificationButton.hovered ? Qt.lighter(Theme.textPrimary, 1.25) : Theme.textPrimary)

            cursorShape: Qt.PointingHandCursor
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
    ModuleButton {
        id: trayCard
        parent: root.overlay
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 5
        
        color: Theme.divider
        radius: Theme.moduleEdgeRadius

        border.width: 2
        border.color: Qt.rgba(Theme.neutral.base.r, Theme.neutral.base.g, Theme.neutral.base.b, Theme.neutral.base.a)

        layer.enabled: true
        layer.smooth: true
        layer.effect: cardShadowEffect

        implicitWidth: trayColumn.implicitWidth + 10
        implicitHeight: trayColumn.implicitHeight + 10

        // Visible when expanded or animating close (clipped)
        visible: root.contentVisible && trayColumn.implicitHeight > 0
        opacity: root.contentOpacity
        
        // disable default interactions
        noHoverColorChange: true
        noPressColorChange: true

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
