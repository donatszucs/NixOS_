// Workspaces — uses Hyprland IPC via Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io

import "../elements"

ModuleButton {
    id: root
    property string screenName: ""

    color: Theme.palette("dark").base
    opacity: Theme.moduleOpacity

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
        spacing: root.overlay - 1

        Repeater {
            model: root.monitorWorkspaces.workspaces

            delegate: ModuleButton {
                id: wsButton
                required property var modelData
                required property int index
                variant: "light"
                opacity: active ? 1.0 : 0.6
                implicitHeight: root.implicitHeight - 2 * root.overlay
                implicitWidth: active ? 20 + wsContentRow.implicitWidth : 15 + wsContentRow.implicitWidth
                cursorShape: Qt.PointingHandCursor

                // Apply the parent's radius ONLY if this is the absolute last item in the list!
                topLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 5
                bottomLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 5
                topRightRadius: index === root.monitorWorkspaces.workspaces.length - 1 ? Theme.moduleEdgeRadius : 5
                bottomRightRadius: index === root.monitorWorkspaces.workspaces.length - 1 ? Theme.moduleEdgeRadius : 5

                readonly property bool active:
                    Hyprland.focusedMonitor !== null &&
                    Hyprland.focusedMonitor.activeWorkspace !== null &&
                    Hyprland.focusedMonitor.activeWorkspace.id === modelData.id

                label: ""

                onClicked: Hyprland.dispatch("workspace " + modelData.id)

                RowLayout {
                    id: wsContentRow
                    anchors.centerIn: parent
                    spacing: active ? 10 : 5

                    Text {
                        text: wsButton.modelData.name
                        color: wsButton.textColor
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                    }

                    Rectangle {
                        width: root.overlay + 1
                        height: Theme.moduleHeight - 15
                        color: Theme.palette("dark").base
                        opacity: 0.5
                        radius: 2
                    }

                    Repeater {
                        model: wsButton.modelData.toplevels.values
                        delegate: Image {
                            id: windowIcon
                            required property var modelData
                            // Use x11 appId if wayland one is empty or missing (e.g. for Steam games running via XWayland)
                            readonly property string appId: {
                                if (modelData.wayland && modelData.wayland.appId !== "") return modelData.wayland.appId;
                                if (modelData.x11 && modelData.x11.appId !== "") return modelData.x11.appId;
                                return "";
                            }
                            
                            readonly property bool isSteam: appId.toLowerCase().indexOf("steam_app_") === 0
                            readonly property string steamId: isSteam ? appId.substring(10) : ""
                            property string steamImagePath: ""

                            // Look up the desktop entry by appId to get the correct icon name,
                            // exactly like LauncherModule does via DesktopEntries.
                            readonly property string resolvedIcon: {
                                if (appId === "") return ""
                                else if (isSteam) 
                                {
                                    steamIconProc.exec([
                                        "bash", 
                                        "/home/doni/nixos-config/scripts/SteamIcon/SteamIconSearch.sh", 
                                        "/home/doni/.steam/root/appcache/librarycache/" + steamId
                                    ]);
                                    return steamImagePath !== "" ? steamImagePath : "image://icon/steam";
                                }
                                
                                var entries = DesktopEntries.applications.values
                                for (var i = 0; i < entries.length; i++) {
                                    if (entries[i].id.toLowerCase() === appId.toLowerCase())
                                        return "image://icon/" + (entries[i].icon !== "" ? entries[i].icon : appId)
                                }
                                // fallback: match by display name
                                for (var j = 0; j < entries.length; j++) {
                                    if (entries[j].name.toLowerCase() === appId.toLowerCase())
                                        return "image://icon/" + (entries[j].icon !== "" ? entries[j].icon : appId)
                                }
                                return "image://icon/" + appId
                            }

                            height: Theme.moduleHeight - 15

                            // Check if we are loading a system icon or a local Steam file
                            readonly property bool isSystemIcon: String(source).indexOf("image://icon/") === 0

                            // If it's a system icon, force a square. If it's Steam, use the real aspect ratio.
                            width: {
                                if (isSystemIcon) {
                                    return height; 
                                }
                                return implicitHeight > 0 ? (implicitWidth / implicitHeight) * height : height;
                            }

                            sourceSize.height: height
                            sourceSize.width: isSystemIcon ? height : 0

                            fillMode: Image.PreserveAspectFit

                            source: resolvedIcon
                            
                            visible: appId !== ""
                            asynchronous: true
                            mipmap: true
                            
                            Process {
                                id: steamIconProc
                                
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        var output = text.trim(); 
                                        windowIcon.steamImagePath = output;
                                    }
                                }
                            }
                        }
                    }
                }

                Behavior on implicitWidth {
                    NumberAnimation { duration: Theme.horizontalDuration / 4; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
                }
            }
        }
        // Spacer between "my" workspaces and the others (if any)
        Rectangle {
            visible: root.monitorWorkspaces.others.length > 0
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
                implicitWidth: 25
                cursorShape: Qt.PointingHandCursor
                
                // Apply the parent's radius ONLY if this is the absolute last item in the list!
                topLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 5
                bottomLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 5
                topRightRadius: index === root.monitorWorkspaces.others.length - 1 ? Theme.moduleEdgeRadius : 5
                bottomRightRadius: index === root.monitorWorkspaces.others.length - 1 ? Theme.moduleEdgeRadius : 5

                readonly property bool active:
                    Hyprland.focusedMonitor !== null &&
                    Hyprland.focusedMonitor.activeWorkspace !== null &&
                    Hyprland.focusedMonitor.activeWorkspace.id === modelData.id

                label: modelData.name

                onClicked: Hyprland.dispatch("workspace " + modelData.id)

                Behavior on implicitWidth {
                    NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
