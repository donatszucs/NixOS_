// Workspaces — uses Hyprland IPC via Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

ModuleButton {
    id: root
    noHoverColorChange: true
    property string screenName: ""

    // Only workspaces whose monitor name matches this bar's screen
    readonly property var monitorWorkspaces: {
        var all = Hyprland.workspaces.values
        var out = []
        for (var i = 0; i < all.length; i++)
            if (all[i].monitor && all[i].monitor.name === screenName)
                out.push(all[i])
        return out
    }

    implicitWidth: workspacesRow.implicitWidth + 8

    RowLayout {
        id: workspacesRow
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.monitorWorkspaces

            delegate: ModuleButton {
                required property var modelData

                variant: active ? "light" : "dark"
                implicitWidth: active ? 30 : 20
                implicitHeight: 20

                radius: Theme.moduleRadius / 2


                readonly property bool active:
                    Hyprland.focusedMonitor !== null &&
                    Hyprland.focusedMonitor.activeWorkspace !== null &&
                    Hyprland.focusedMonitor.activeWorkspace.id === modelData.id

                label: modelData.name

                onClicked: Hyprland.dispatch("workspace " + modelData.id)

                Behavior on implicitWidth {
                    NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
