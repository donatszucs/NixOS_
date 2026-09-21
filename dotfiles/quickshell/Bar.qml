import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import "./modules"
import "./elements"
import "./apps"

PanelWindow {
    id: topPanel

    required property var modelData
    screen: modelData

    property color moduleShadowColor: Qt.rgba(0, 0, 0, 0.55)

    Component {
        id: panelShadowEffect
        MultiEffect {
            shadowEnabled: true
            shadowColor: topPanel.moduleShadowColor
            shadowBlur: 1.0
            shadowVerticalOffset: 4
            shadowHorizontalOffset: 0
        }
    }

    color: "transparent"

    // Cover the full screen so children can render below the bar strip
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    // No space reservation here — handled by the spacer window below
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [topPanel]
        active: launcherModule.expanded || clipboardHistory.expanded || rbwMenu.expanded || notificationCenter.inlineReplyInputFocused || wallpaperPicker.expanded
        onCleared: {
            launcherModule.expanded = false
            wallpaperPicker.expanded = false
            clipboardHistory.expanded = false
            rbwMenu.closeMenu()
            notificationCenter.inlineReplyInputFocused = false
        }
    }

    Rectangle {
        id: screenDimmer
        anchors.fill: parent
        z: -2
        color: "black"
        property bool active: launcherModule.expanded || clipboardHistory.expanded || rbwMenu.expanded || wallpaperPicker.expanded
        opacity: active ? 0.2 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }
    }

    mask: Region {
        
        Region {
            item: screenDimmer.visible ? screenDimmer : null
        }
        Region {
            item: bgMouseArea.enabled ? bgMouseArea : null
        }
        Region {
            item: dragRegionItem.visible ? dragRegionItem : null
        }
        // Left modules interaction region
        Region {
            item: leftRow
        }

        Region {
            item: launcherModule
        }

        // Right modules interaction region
        Region {
            item: rightRow
        }

        // Expandable module interaction regions
        Region { item: (clockModule.contentVisible || clockModule.hasProtrudingCorners) ? clockModule.flowingBackground : null }
        Region { item: (weatherModule.contentVisible || weatherModule.hasProtrudingCorners) ? weatherModule.flowingBackground : null }
        Region { item: (nowPlayingModule.contentVisible || nowPlayingModule.hasProtrudingCorners) ? nowPlayingModule.flowingBackground : null }
        Region { item: (lightSwitchModule.contentVisible || lightSwitchModule.hasProtrudingCorners) ? lightSwitchModule.flowingBackground : null }
        Region { item: (audioModule.contentVisible || audioModule.hasProtrudingCorners) ? audioModule.flowingBackground : null }
        Region { item: (connectionsModule.contentVisible || connectionsModule.hasProtrudingCorners) ? connectionsModule.flowingBackground : null }
        Region { item: (trayModule.contentVisible || trayModule.hasProtrudingCorners) ? trayModule.flowingBackground : null }
        Region { item: (systemModule.contentVisible || systemModule.hasProtrudingCorners) ? systemModule.flowingBackground : null }

        // Wallpaper Picker interaction region (side edge)
        Region {
            item: wallpaperPicker
        }

        // Clipboard History interaction region (left edge)
        Region {
            item: clipboardHistory
        }
        // RbwMenu expanded region (drops below bar from center)
        Region {
            item: rbwMenu
        }

        // Notification Center region (bottom-right)
        Region {
            item: notificationCenter
        }

    }

    BackgroundEffect.blurRegion: Region {
        Region { item: screenDimmer.visible ? screenDimmer : null }
        Region { item: leftRow }
        Region { item: launcherModule }
        Region { item: rightRow }
        Region { item: wallpaperPicker }
        Region { item: clipboardHistory }
        Region { item: rbwMenu }
        Region { item: notificationCenter }
        Region { item: sysmonAppWrapper }

        // Expandable module flowing backgrounds
        Region { item: (clockModule.contentVisible || clockModule.hasProtrudingCorners) ? clockModule.flowingBackground : null }
        Region { item: (weatherModule.contentVisible || weatherModule.hasProtrudingCorners) ? weatherModule.flowingBackground : null }
        Region { item: (nowPlayingModule.contentVisible || nowPlayingModule.hasProtrudingCorners) ? nowPlayingModule.flowingBackground : null }
        Region { item: (lightSwitchModule.contentVisible || lightSwitchModule.hasProtrudingCorners) ? lightSwitchModule.flowingBackground : null }
        Region { item: (audioModule.contentVisible || audioModule.hasProtrudingCorners) ? audioModule.flowingBackground : null }
        Region { item: (connectionsModule.contentVisible || connectionsModule.hasProtrudingCorners) ? connectionsModule.flowingBackground : null }
        Region { item: (trayModule.contentVisible || trayModule.hasProtrudingCorners) ? trayModule.flowingBackground : null }
        Region { item: (systemModule.contentVisible || systemModule.hasProtrudingCorners) ? systemModule.flowingBackground : null }
        Region { item: bottomLeftBorder }
    }

    // Background MouseArea to close the launcher when clicking outside of it
    MouseArea {
        id: bgMouseArea
        anchors.fill: parent
        visible: enabled
        enabled: launcherModule.expanded || clipboardHistory.expanded || rbwMenu.expanded || wallpaperPicker.expanded || notificationCenter.isManuallyOpen
        onClicked: {
            launcherModule.expanded = false
            wallpaperPicker.expanded = false
            clipboardHistory.expanded = false
            rbwMenu.closeMenu()
            notificationCenter.isManuallyOpen = false
        }
        z: -1
    }

    Item {
        id: dragRegionItem
        anchors.fill: parent
        visible: launcherModule.activeDragCount > 0
    }


    // Left-row spacer helpers
    readonly property real _clockSpacerNeed: clockModule.expanded
        ? (clockModule.expandedDropdownWidth + (2 * Theme.moduleEdgeRadius)) 
        - (clockModule.collapsedWidth + weatherModule.collapsedWidth + nowPlayingModule.collapsedWidth)
        : 0

    readonly property real _weatherSpacerNeed: weatherModule.expanded
        ? ((weatherModule.expandedDropdownWidth / 2) + (2 * Theme.moduleEdgeRadius)) - ((weatherModule.collapsedWidth / 2) + nowPlayingModule.collapsedWidth)
        : 0
    readonly property real _leftSpacerWidth: Math.max(_clockSpacerNeed, _weatherSpacerNeed)
    // ── LEFT ─────────────────────────────────────────────────────────────
    RowLayout {
        id: leftRow
        anchors {
            left: parent.left
            top: parent.top
        }
        spacing: 0

        layer.enabled: true
        layer.effect: panelShadowEffect

        ClockModule {
            Layout.alignment: Qt.AlignTop
            id: clockModule
        }
        WeatherModule {
            Layout.alignment: Qt.AlignTop
            id: weatherModule
        }
        // Spacer: grows when an expanded dropdown would overflow NowPlaying's right edge
        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitHeight: Theme.moduleHeight
            implicitWidth: _leftSpacerWidth
            Behavior on implicitWidth {
                NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }
            color: nowPlayingModule.baseColor
        }
        NowPlayingModule {
            Layout.alignment: Qt.AlignTop
            id: nowPlayingModule
        }
    }

    // ── CENTER ───────────────────────────────────────────────────────────

    LauncherModule {
        id: launcherModule
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        screenName: modelData.name

        onToggleWallpaperPicker: wallpaperPicker.expanded = !wallpaperPicker.expanded
        onToggleBitwardenMenu: {
            if (rbwMenu.expanded) {
                rbwMenu.closeMenu();
            } else {
                rbwMenu.openMenu();
            }
        }
        onToggleClipboardHistory: {
            if (clipboardHistory.expanded) {
                clipboardHistory.closeMenu();
            } else {
                clipboardHistory.openMenu();
            }
        }

        layer.enabled: activeDragCount === 0
        layer.effect: Component {
            MultiEffect {
                shadowEnabled: true
                shadowHorizontalOffset: 0

                property real shadowPulse: 1.0

                SequentialAnimation on shadowPulse {
                    loops: Animation.Infinite
                    running: launcherModule.expanded
                    
                    NumberAnimation { 
                        to: 0.3
                        duration: 1000
                        easing.type: Easing.InOutSine 
                    }
                    NumberAnimation { 
                        to: 1.0
                        duration: 1500
                        easing.type: Easing.InOutSine 
                    }
                }

                shadowBlur: launcherModule.expanded ? (0.5 + shadowPulse * 1.5) : 1.0
                shadowVerticalOffset: launcherModule.expanded ? (2 + shadowPulse * 2) : 4

                shadowColor: launcherModule.expanded 
                    ? Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.8 * shadowPulse) 
                    : moduleShadowColor
            }
        }
    }

    // ── RIGHT ────────────────────────────────────────────────────────────
    RowLayout {
        id: rightRow
        anchors {
            right: parent.right
            top: parent.top
        }
        spacing: 0

        layer.enabled: true
        layer.effect: panelShadowEffect

        LightSwitchModule {
            Layout.alignment: Qt.AlignTop
            id: lightSwitchModule
        }
        VirtualKeyboardModule {
            Layout.alignment: Qt.AlignTop
            id: virtualKeyboardModule
        }
        MonitorBrightnessModule {
            Layout.alignment: Qt.AlignTop
            screenName: modelData.name
            id: monitorBrightnessModule
        }
        AudioModule {
            Layout.alignment: Qt.AlignTop
            id: audioModule
        }
        ConnectionsModule {
            Layout.alignment: Qt.AlignTop
            id: connectionsModule
        }
        TrayModule {
            Layout.alignment: Qt.AlignTop
            id: trayModule
            parentWindow: topPanel
        }
        SystemModule {
            Layout.alignment: Qt.AlignTop
            id: systemModule
        }
    }

    // ── OTHER MODULES ────────────────────────────────────────────────────────────

    WallpaperPicker {
        id: wallpaperPicker
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
        }

        layer.enabled: true
        layer.effect: panelShadowEffect
    }

    ClipboardHistory {
        id: clipboardHistory
        screenName: modelData.name
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
        }

        layer.enabled: true
        layer.effect: panelShadowEffect
    }

    RbwMenu {
        id: rbwMenu
        screenName: modelData.name
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }

        layer.enabled: true
        layer.effect: panelShadowEffect
    }

    Item {
        id: sysmonAppWrapper
        anchors.left: launcherModule.right
        anchors.right: rightRow.left
        anchors.top: launcherModule.top
        height: launcherModule.height

        ResourceWatcherApp {
            id: sysmonApp
            screenName: modelData.name
            anchors.centerIn: parent
        }

        layer.enabled: true
        layer.effect: panelShadowEffect
    }


    NotificationCenter {
        id: notificationCenter 
        screenName: modelData.name

        anchors {
            bottom: parent.bottom
            right: parent.right
        }

        layer.enabled: true
        layer.effect: panelShadowEffect
    }


    // Borders

    InverseRadius {
        id: bottomLeftBorder
        cornerPosition: "bottomLeft"
        color: Theme.palette("dark").base
        anchors {
            bottom: parent.bottom
            left: parent.left
        }
    }

    // Invisible spacer window — its sole job is to reserve barHeight so that
    // tiled/maximised windows start below the bar
    PanelWindow {
        screen: topPanel.modelData
        anchors { top: true; left: true; right: true }
        implicitHeight: Theme.moduleHeight
        color: "transparent"
        mask: Region {}
    }
    
}
