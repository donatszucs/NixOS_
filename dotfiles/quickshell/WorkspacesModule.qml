// Workspaces — uses Hyprland IPC via Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

ModuleButton {
    id: root
    noHoverColorChange: true
    property string screenName: ""

    radius: Theme.moduleEdgeRadius + 2
    property int overlay: 3

    implicitHeight: Theme.moduleHeight * 0.9

    // Only workspaces whose monitor name matches this bar's screen
    readonly property var monitorWorkspaces: {
        var all = Hyprland.workspaces.values
        var out = []
        for (var i = 0; i < all.length; i++)
            if (all[i].monitor && all[i].monitor.name === screenName)
                out.push(all[i])
        return out
    }

    implicitWidth: workspacesRow.implicitWidth + 2 * overlay

    RowLayout {
        id: workspacesRow
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: root.monitorWorkspaces

            delegate: ModuleButton {
                required property var modelData
                required property int index
                variant: active ? "light" : "transparentDark"
                implicitHeight: root.implicitHeight - 2 * root.overlay
                implicitWidth: active ? 35 : 20
                
                // Apply the parent's radius ONLY if this is the absolute last item in the list!
                topLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 0
                bottomLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 0
                topRightRadius: index === root.monitorWorkspaces.length - 1 ? Theme.moduleEdgeRadius : 0
                bottomRightRadius: index === root.monitorWorkspaces.length - 1 ? Theme.moduleEdgeRadius : 0

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
