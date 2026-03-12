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

    // Cover the full screen so children can render below the bar strip
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    // No space reservation here — handled by the spacer window below
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: (launcherModule.expanded || clipboardHistory.expanded || rbwMenu.expanded) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None


    mask: Region {
        
        // Left modules interaction region
        Region {
            item: leftRow
        }

        // Center modules interaction region
        Region {
            item: closeWindowModule
        }

        Region {
            item: workspacesModule
        }

        Region {
            item: addWorkspaceModule
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
    color: "transparent"

    // Background MouseArea to close the launcher when clicking outside of it
    MouseArea {
        anchors.fill: parent
        enabled: launcherModule.expanded
        onClicked: {
            launcherModule.expanded = false
        }
        z: -1
    }

    // Subtle gradient background, like waybar's window#waybar
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Theme.barHeight
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0.33, 0.27, 0.37, 0.13) }
            GradientStop { position: 1.0; color: "transparent" }
        }
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
                opacity: Theme.moduleOpacity
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
            cornerPosition: "topLeft"
            color: nowPlayingModule.color
        }
    }

    // ── CENTER ───────────────────────────────────────────────────────────
    CloseWindowModule {
        id: closeWindowModule
        topMarginButton: Theme.moduleMarginH + Theme.moduleHeight/2 - implicitHeight/2 
        radius: Theme.moduleEdgeRadius
        anchors {
                rightMargin: Theme.moduleEdgeMarginV + 4
                right: workspacesModule.left
            top: parent.top
        }
    }

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
    AddWorkspaceModule {
        topMarginButton: Theme.moduleMarginH + Theme.moduleHeight/2 - implicitHeight/2
        radius: Theme.moduleEdgeRadius
        id: addWorkspaceModule
        anchors {
                left: workspacesModule.right
                leftMargin: Theme.moduleEdgeMarginV + 4
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
            bottomLeftRadius: Theme.moduleEdgeRadius
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
        ModSwitcherModule {
            Layout.alignment: Qt.AlignTop
            id: modSwitcherModule
        }
        ModuleGap {
            Layout.alignment: Qt.AlignTop
            leftColor: modSwitcherModule.color
            leftExpanded: audioModule.expanded
        }
        AudioModule {
            Layout.alignment: Qt.AlignTop
            id: audioModule
        }
        ModuleGap {
            Layout.alignment: Qt.AlignTop

            leftColor: controlCenterModule.color
            leftExpanded: controlCenterModule.expanded

            rightColor: audioModule.color
            rightExpanded: audioModule.expanded
        }
        ControlCenterModule {
            Layout.alignment: Qt.AlignTop
            id: controlCenterModule
        }
        ModuleGap {
            Layout.alignment: Qt.AlignTop
            rightColor: controlCenterModule.color
            rightExpanded: controlCenterModule.expanded
        }
        TrayModule {
            Layout.alignment: Qt.AlignTop
            id: trayModule
            parentWindow: topPanel 
        }
        ModuleGap {
            Layout.alignment: Qt.AlignTop
            leftColor: trayModule.color
            leftExpanded: powerModule.expanded
        }
        PowerModule {
            Layout.alignment: Qt.AlignTop
            id: powerModule
        }
        ModuleGap {
            Layout.alignment: Qt.AlignTop
            leftColor: powerModule.expanded ? powerModule.color : Qt.tint(powerModule.color, powerModule.buttonColor)
            implicitHeight: powerModule.implicitHeight
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
