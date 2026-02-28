import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

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
    WlrLayershell.keyboardFocus: launcherModule.expanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Modules write to this to extend the input region downward when they expand.
    // Use Math.max so multiple modules can contribute independently.
    property real maskHeight: Theme.barHeight

    mask: Region {
        x: 0
        y: 0
        width: topPanel.width
        height: topPanel.maskHeight
    }
    color: "transparent"

    // Background MouseArea to close the launcher when clicking outside of it
    MouseArea {
        anchors.fill: parent
        enabled: launcherModule.expanded
        onClicked: launcherModule.expanded = false
        z: -1
    }

    // Subtle gradient background, like waybar's window#waybar
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Theme.barHeight
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0.05, 0, 0.08, 0.30) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ── LEFT ─────────────────────────────────────────────────────────────
    InverseRadius {
        cornerPosition: "topLeft"
        color: clockModule.color
        anchors {
            top: clockModule.bottom
            left: clockModule.left
        }
    }
    ClockModule {
        id: clockModule
        anchors {
            left: parent.left
            leftMargin: Theme.moduleEdgeMarginV
            top: parent.top
        }
    }
    LauncherModule {
        id: launcherModule
        screenName: modelData.name
        anchors {
            left: clockModule.right
            leftMargin: Theme.moduleMarginV
            top: parent.top
        }

        Binding {
            target: topPanel
            property: "maskHeight"
            value: topPanel.height
            when: launcherModule.expanded
            restoreMode: Binding.RestoreBindingOrValue
        }
    }
    NowPlayingModule {
        id: nowPlayingModule

        bottomRightRadius: Theme.moduleEdgeRadius
        anchors {
            left: launcherModule.right
            leftMargin: Theme.moduleMarginV
            top: parent.top
        }
    }
    InverseRadius {
        cornerPosition: "topLeft"
        color: nowPlayingModule.color
        anchors {
            left: nowPlayingModule.right
            top: parent.top
        }
    }

    // ── CENTER ───────────────────────────────────────────────────────────
    CloseWindowModule {
        topMarginButton: Theme.moduleMarginH + Theme.moduleHeight/2 - implicitHeight/2 + 2
        radius: Theme.moduleEdgeRadius
        anchors {
                rightMargin: Theme.moduleEdgeMarginV + 2
                right: workspacesModule.left
            top: parent.top
        }
    }
    WorkspacesModule {
        topMarginButton: Theme.moduleMarginH + Theme.moduleHeight/2 - implicitHeight/2 + 2
        id: workspacesModule
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        screenName: modelData.name
    }
    AddWorkspaceModule {
        topMarginButton: Theme.moduleMarginH + Theme.moduleHeight/2 - implicitHeight/2 + 2
        radius: Theme.moduleEdgeRadius
        id: addWorkspaceModule
        anchors {
                left: workspacesModule.right
                leftMargin: Theme.moduleEdgeMarginV + 2
            top: parent.top
        }
    }

    // ── RIGHT ────────────────────────────────────────────────────────────
    InverseRadius {
        cornerPosition: "topRight"
        color: lightSwitchModule.color
        anchors {
            right: lightSwitchModule.left
            top: parent.top
        }
    }
    LightSwitch {
        id: lightSwitchModule
        bottomLeftRadius: Theme.moduleEdgeRadius
        anchors {
            right: monitorBrightnessModule.left
            rightMargin: Theme.moduleMarginV
            top: parent.top
        }
    }
    MonitorBrightness {
        screenName: modelData.name
        id: monitorBrightnessModule
        anchors {
            right: virtualKeyboardModule.left
            rightMargin: Theme.moduleMarginV
            top: parent.top
        }
    }
    VirtualKeyboard {
        id: virtualKeyboardModule
        anchors {
            right: modSwitcherModule.left
            rightMargin: Theme.moduleMarginV
            top: parent.top
        }
    }
    ModSwitcherModule {
        id: modSwitcherModule
        anchors {
            right: audioModule.left
            rightMargin: Theme.moduleMarginV
            top: parent.top
        }
    }
    AudioModule {
        id: audioModule
        anchors {
            right: controlCenterModule.left
            rightMargin: Theme.moduleMarginV
            top: parent.top
        }

        Binding {
            target: topPanel
            property: "maskHeight"
            value: audioModule.implicitHeight
            when: audioModule.expanded
            restoreMode: Binding.RestoreBindingOrValue
        }
    }
    ControlCenter {
        id: controlCenterModule
        anchors {
            right: trayModule.left
            rightMargin: Theme.moduleMarginV
            top: parent.top
        }

        Binding {
            target: topPanel
            property: "maskHeight"
            value: controlCenterModule.implicitHeight
            when: controlCenterModule.expanded
            restoreMode: Binding.RestoreBindingOrValue
        }
    }
    Tray { 
        id: trayModule
        parentWindow: topPanel 
        anchors {
            right: powerModule.left
            rightMargin: Theme.moduleMarginV
            top: parent.top
        }
    }
    
    PowerModule {
        id: powerModule
        anchors {
            rightMargin: Theme.moduleEdgeMarginV
            right: parent.right
            top: parent.top
        }

        Binding {
            target: topPanel
            property: "maskHeight"
            value: powerModule.implicitHeight
            when: powerModule.expanded
            restoreMode: Binding.RestoreBindingOrValue
        }
    }
    InverseRadius {
        cornerPosition: "topRight"
        color: powerModule.color
        anchors {
            top: powerModule.bottom
            right: powerModule.right
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
