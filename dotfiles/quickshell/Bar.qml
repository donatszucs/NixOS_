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
    WlrLayershell.keyboardFocus: launcherModule.expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

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
    ClockModule {
        id: clockModule
        topLeftRadius: Theme.moduleEdgeRadius
        bottomLeftRadius: Theme.moduleEdgeRadius
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
            value: launcherModule.implicitHeight
            when: launcherModule.expanded
            restoreMode: Binding.RestoreBindingOrValue
        }
    }
    NowPlayingModule {
        id: nowPlayingModule

        topRightRadius: Theme.moduleEdgeRadius
        bottomRightRadius: Theme.moduleEdgeRadius
        anchors {
            left: launcherModule.right
            leftMargin: Theme.moduleMarginV
            top: parent.top
        }
    }

    // ── CENTER ───────────────────────────────────────────────────────────
        CloseWindowModule {
            topLeftRadius: Theme.moduleHeight / 2
            bottomLeftRadius: Theme.moduleHeight / 2
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
        AddWorkspaceModule {
            topRightRadius: Theme.moduleHeight / 2
            bottomRightRadius: Theme.moduleHeight / 2
            id: addWorkspaceModule
            anchors {
                left: workspacesModule.right
                top: parent.top
            }
        }

    // ── RIGHT ────────────────────────────────────────────────────────────
    LightSwitch {
        id: lightSwitchModule
        topLeftRadius: Theme.moduleEdgeRadius
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
        topRightRadius: Theme.moduleEdgeRadius
        bottomRightRadius: Theme.moduleEdgeRadius
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
