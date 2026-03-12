// Workspaces — uses Hyprland IPC via Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

import "../elements"

ModuleButton {
    id: root
    property string screenName: ""

    color: Theme.palette("dark").base

    bottomLeftRadius: Theme.moduleEdgeRadius + 2
    bottomRightRadius: Theme.moduleEdgeRadius + 2
    property int overlay: 3

    implicitHeight: Theme.moduleHeight * 0.9

    // Only workspaces whose monitor name matches this bar's screen
    readonly property var monitorWorkspaces: {
        var all = Hyprland.workspaces.values
        var out = []
        var others = []
        for (var i = 0; i < all.length; i++)
            if (all[i].monitor && all[i].monitor.name === screenName)
                out.push(all[i])
            else 
                others.push(all[i])
        return { workspaces: out, others: others }
    }

    implicitWidth: workspacesRow.implicitWidth + 2 * overlay

    RowLayout {
        id: workspacesRow
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: root.monitorWorkspaces.workspaces

            delegate: ModuleButton {
                id: wsButton
                required property var modelData
                required property int index
                variant: "light"
                opacity: active ? 1.0 : 0.6
                implicitHeight: root.implicitHeight - 2 * root.overlay
                implicitWidth: wsContentRow.implicitWidth + 20
                cursorShape: Qt.PointingHandCursor

                // Apply the parent's radius ONLY if this is the absolute last item in the list!
                topLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 0
                bottomLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 0
                topRightRadius: index === root.monitorWorkspaces.workspaces.length - 1 ? Theme.moduleEdgeRadius : 0
                bottomRightRadius: index === root.monitorWorkspaces.workspaces.length - 1 ? Theme.moduleEdgeRadius : 0

                readonly property bool active:
                    Hyprland.focusedMonitor !== null &&
                    Hyprland.focusedMonitor.activeWorkspace !== null &&
                    Hyprland.focusedMonitor.activeWorkspace.id === modelData.id

                label: ""

                onClicked: Hyprland.dispatch("workspace " + modelData.id)

                RowLayout {
                    id: wsContentRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: wsButton.modelData.name
                        color: wsButton.textColor
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                    }

                    Repeater {
                        model: wsButton.modelData.toplevels.values
                        delegate: IconImage {
                            required property var modelData
                            readonly property string appId: modelData.wayland ? modelData.wayland.appId : ""

                            // Look up the desktop entry by appId to get the correct icon name,
                            // exactly like LauncherModule does via DesktopEntries.
                            readonly property string resolvedIcon: {
                                if (appId === "") return ""
                                var entries = DesktopEntries.applications.values
                                for (var i = 0; i < entries.length; i++) {
                                    if (entries[i].id.toLowerCase() === appId.toLowerCase())
                                        return entries[i].icon !== "" ? entries[i].icon : appId
                                }
                                // fallback: match by display name
                                for (var j = 0; j < entries.length; j++) {
                                    if (entries[j].name.toLowerCase() === appId.toLowerCase())
                                        return entries[j].icon !== "" ? entries[j].icon : appId
                                }
                                return appId
                            }

                            implicitSize: Theme.moduleHeight - 15
                            source: resolvedIcon !== "" ? ("image://icon/" + resolvedIcon) : ""
                            visible: appId !== ""
                            asynchronous: true
                            mipmap: true
                        }
                    }
                }

                Behavior on implicitWidth {
                    NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                }
            }
        }
        // Spacer between "my" workspaces and the others (if any)
        Rectangle {
            width: root.overlay
            height: 1
            color: "transparent"
        }

        Repeater {
            model: root.monitorWorkspaces.others

            delegate: ModuleButton {
                required property var modelData
                required property int index
                variant: "light"
                opacity: active ? 1.0 : 0.6
                implicitHeight: root.implicitHeight - 2 * root.overlay
                implicitWidth: active ? 35 : 25
                cursorShape: Qt.PointingHandCursor
                
                // Apply the parent's radius ONLY if this is the absolute last item in the list!
                topLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 0
                bottomLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 0
                topRightRadius: index === root.monitorWorkspaces.others.length - 1 ? Theme.moduleEdgeRadius : 0
                bottomRightRadius: index === root.monitorWorkspaces.others.length - 1 ? Theme.moduleEdgeRadius : 0

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
