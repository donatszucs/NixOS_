import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

import "./modules"
import "./elements"
import "./apps"

PanelWindow {
    id: topPanel

    required property var modelData
    screen: modelData

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
    WlrLayershell.keyboardFocus: (launcherModule.expanded || clipboardHistory.expanded || rbwMenu.expanded || notificationCenter.inlineReplyInputFocused) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None


    mask: Region {
        
        Region {
            item: bgMouseArea.enabled ? bgMouseArea : null
        }
        // Left modules interaction region
        Region {
            item: leftRow
        }

        Region {
            item: workspacesModule
        }

        Region {
            item: workspacesModule.contextPanel
        }

        // Right modules interaction region
        Region {
            item: rightRow
        }

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

    // Background MouseArea to close the launcher when clicking outside of it
    MouseArea {
        id: bgMouseArea
        anchors.fill: parent
        visible: enabled
        enabled: launcherModule.expanded || workspacesModule.contextPanel.visible || clipboardHistory.expanded || rbwMenu.expanded || wallpaperPicker.expanded
        onClicked: {
            launcherModule.expanded = false
            workspacesModule.contextPanel.visible = false
            wallpaperPicker.expanded = false
            clipboardHistory.expanded = false
            rbwMenu.closeMenu()
        }
        z: -1
    }

    // ── LEFT ─────────────────────────────────────────────────────────────
    RowLayout {
        id: leftRow
        anchors {
            left: parent.left
            top: parent.top
        }
        spacing: 0

        ModuleGap {
            Layout.alignment: Qt.AlignTop
            rightColor: clockModule.color
        }
        ClockModule {
            Layout.alignment: Qt.AlignTop
            id: clockModule
        }
        ModuleGap {
            Layout.alignment: Qt.AlignTop
            leftColor: launcherModule.color
            leftExpanded: launcherModule.expanded
        }
        LauncherModule {
            Layout.alignment: Qt.AlignTop
            id: launcherModule
            screenName: modelData.name
        }
        ModuleGap {
            Layout.alignment: Qt.AlignTop

            rightColor: launcherModule.color
            rightExpanded: launcherModule.expanded

            leftColor: nowPlayingModule.color
            leftExpanded: nowPlayingModule.expanded

            Rectangle {
                anchors.fill: parent
                color: Theme.palette("dark").base
            }

            Behavior on implicitWidth {
                NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }
            implicitWidth: launcherModule.expanded && nowPlayingModule.expanded ? Theme.moduleEdgeRadius * 2 : 0
        }
        NowPlayingModule {
            Layout.alignment: Qt.AlignTop
            id: nowPlayingModule
            bottomRightRadius: Theme.moduleEdgeRadius
        }
        InverseRadius {
            Layout.alignment: Qt.AlignTop
            color: nowPlayingModule.color
            cornerPosition: "topLeft"
        }
    }

    // ── CENTER ───────────────────────────────────────────────────────────

    InverseRadius {
        cornerPosition: "topRight"
        color: workspacesModule.color
        anchors {
            right: workspacesModule.left
            top: parent.top
        }
    }
    WorkspacesModule {
        id: workspacesModule
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        screenName: modelData.name
    }
    InverseRadius {
        cornerPosition: "topLeft"
        color: workspacesModule.color
        anchors {
            left: workspacesModule.right
            top: parent.top
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

        InverseRadius {
            Layout.alignment: Qt.AlignTop
            cornerPosition: "topRight"
            color: lightSwitchModule.color
        }
        LightSwitchModule {
            Layout.alignment: Qt.AlignTop
            id: lightSwitchModule
            variant: !expanded ? SharedState.lightVariant : monitorBrightnessModule.variant
        }
        ModuleGap {
            Layout.alignment: Qt.AlignTop
            rightColor: monitorBrightnessModule.color
            rightExpanded: lightSwitchModule.expanded
        }
        MonitorBrightnessModule {
            Layout.alignment: Qt.AlignTop
            screenName: modelData.name
            id: monitorBrightnessModule
        }
        VirtualKeyboardModule {
            Layout.alignment: Qt.AlignTop
            id: virtualKeyboardModule

        }
        ModuleGap {
            Layout.alignment: Qt.AlignTop
            leftColor: virtualKeyboardModule.color
            leftExpanded: audioModule.expanded
        }
        AudioModule {
            Layout.alignment: Qt.AlignTop
            id: audioModule
        }
        ModuleGap {
            Layout.alignment: Qt.AlignTop

            leftColor: connectionsModule.color
            leftExpanded: connectionsModule.expanded

            rightColor: audioModule.color
            rightExpanded: audioModule.expanded
        }
        ConnectionsModule {
            Layout.alignment: Qt.AlignTop
            id: connectionsModule
        }
        ModuleGap {
            Layout.alignment: Qt.AlignTop
            rightColor: connectionsModule.color
            rightExpanded: connectionsModule.expanded
        }
        TrayModule {
            Layout.alignment: Qt.AlignTop
            id: trayModule
            parentWindow: topPanel 
        }
        ModuleGap {
            Layout.alignment: Qt.AlignTop
            leftColor: systemModule.color
            leftExpanded: systemModule.expanded
        }
        SystemModule {
            Layout.alignment: Qt.AlignTop
            id: systemModule
        }
        ModuleGap {
            Layout.alignment: Qt.AlignTop
            leftColor: systemModule.color
            implicitHeight: systemModule.implicitHeight
        }
    }

    // ── OTHER MODULES ────────────────────────────────────────────────────────────

    WallpaperPicker {
        id: wallpaperPicker
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
            rightMargin: Theme.moduleEdgeMarginV
        }
    }

    ClipboardHistory {
        id: clipboardHistory
        screenName: modelData.name
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: Theme.moduleEdgeMarginV
        }
    }

    RbwMenu {
        id: rbwMenu
        screenName: modelData.name
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
    }


    NotificationCenter {
        id: notificationCenter 

        anchors {
            bottom: parent.bottom
            right: parent.right
        }
    }


    // Borders

    InverseRadius {
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
        implicitHeight: Theme.barHeight
        color: "transparent"
        mask: Region {}
    }
    
}
