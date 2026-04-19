// Workspaces — uses Hyprland IPC via Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io

import "../elements"

ModuleButton {
    id: root
    property string screenName: ""

    clip: false

    color: Theme.palette("dark").base

    bottomLeftRadius: Theme.moduleEdgeRadius + 2
    bottomRightRadius: Theme.moduleEdgeRadius + 2
    property int overlay: 4

    property alias contextPanel: contextPanelItem

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
                topRightRadius: 5
                bottomRightRadius: 5

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
                        visible: wsButton.modelData.toplevels.values.length > 0
                        width: root.overlay
                        height: Theme.moduleHeight - 15
                        color: Theme.palette("dark").base
                        opacity: 0.5
                        radius: 2
                    }

                    Repeater {
                        model: wsButton.modelData.toplevels.values
                        delegate: IconImage {
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
                                    return steamImagePath !== "" ? steamImagePath : Quickshell.iconPath(steam);
                                }
                                
                                var entries = DesktopEntries.applications.values
                                for (var i = 0; i < entries.length; i++) {
                                    var entryId = entries[i].id.toLowerCase();
                                    var appLower = appId.toLowerCase();
                                    if (entryId === appLower || entryId === appLower + ".desktop" || entryId.indexOf(appLower) >= 0)
                                        return Quickshell.iconPath(entries[i].icon !== "" ? entries[i].icon : appId)
                                }
                                // fallback: match by display name
                                for (var j = 0; j < entries.length; j++) {
                                    if (entries[j].name.toLowerCase() === appLower || entries[j].name.toLowerCase().indexOf(appLower) >= 0)
                                        return Quickshell.iconPath(entries[j].icon !== "" ? entries[j].icon : appId)
                                }
                                // extreme fallback: match window title for electron wrappers
                                if (modelData.title) {
                                    var titleLower = modelData.title.toLowerCase();
                                    
                                    if (titleLower.indexOf("teams") >= 0) return Quickshell.iconPath("teams-for-linux");

                                    for (var k = 0; k < entries.length; k++) {
                                        var entryName = entries[k].name.toLowerCase();
                                        if (titleLower.indexOf(entryName) >= 0 || entryName.indexOf(titleLower) >= 0) {
                                            return Quickshell.iconPath(entries[k].icon !== "" ? entries[k].icon : appId);
                                        }
                                    }
                                }
                                return Quickshell.iconPath(appId)
                            }

                            height: Theme.moduleHeight - 15

                            // Check if we are loading a system icon or a local Steam file
                            readonly property bool isSystemIcon: String(source).indexOf("image://icon/") === 0

                            // If it's a system icon, force a square. If it's Steam, try to preserve aspect ratio.
                            width: {
                                if (isSystemIcon) {
                                    return height; 
                                }
                                // Use implicit width/height or sourceSize to guess aspect ratio
                                var sWidth = implicitWidth > 0 ? implicitWidth : (sourceSize.width > 0 ? sourceSize.width : height);
                                var sHeight = implicitHeight > 0 ? implicitHeight : (sourceSize.height > 0 ? sourceSize.height : height);
                                return (sWidth / sHeight) * height;
                            }

                            source: resolvedIcon
                            
                            visible: appId !== ""
                            
                            Process {
                                id: steamIconProc
                                
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        var output = text.trim(); 
                                        windowIcon.steamImagePath = output;
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        var pos = mapToItem(root, 0, root.implicitHeight + 4)
                                        contextPanelItem.x = pos.x - contextPanelItem.width / 2 + width / 2
                                        contextPanelItem.targetAddress = String(windowIcon.modelData.address)
                                        contextPanelItem.visible = true
                                    } else {
                                        Hyprland.dispatch("focuswindow address:0x" + String(windowIcon.modelData.address))
                                        contextPanelItem.visible = false
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

        ModuleButton {
            label: ""
            variant: "light"
            opacity: 0.6
            implicitWidth: root.implicitHeight - 2 * root.overlay
            implicitHeight: root.implicitHeight - 2 * root.overlay
            
            topLeftRadius: 5
            bottomLeftRadius: 5

            topRightRadius: Theme.moduleEdgeRadius
            bottomRightRadius: Theme.moduleEdgeRadius

            onClicked: Hyprland.dispatch("workspace empty")
            cursorShape: Qt.PointingHandCursor
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

    Rectangle {
        id: contextPanelItem
        property string targetAddress: ""
        
        visible: false
        z: 100
        y: root.implicitHeight + 6
        implicitWidth: 160
        implicitHeight: contentColumn.implicitHeight + 12
        color: Theme.palette("dark").base
        radius: Theme.moduleEdgeRadius
        border.color: Theme.divider
        border.width: 1

        Behavior on opacity {
            NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
        }
        opacity: visible ? 1.0 : 0.0

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 6
            spacing: 4
            
            ModuleButton {
                Layout.fillWidth: true
                implicitHeight: 34
                label: "Close"
                variant: "red"
                cursorShape: Qt.PointingHandCursor
                radius: Theme.moduleEdgeRadius - 4
                onClicked: {
                    Hyprland.dispatch("closewindow address:0x" + contextPanelItem.targetAddress)
                    contextPanelItem.visible = false
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.divider
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                visible: Hyprland.workspaces.values.length > 0
            }

            Text {
                text: "Send to workspace"
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
                font.bold: true
                Layout.leftMargin: 8
                opacity: 0.6
                visible: Hyprland.workspaces.values.length > 0
            }

            ModuleButton {
                Layout.fillWidth: true
                implicitHeight: 34
                variant: "neutral"
                cursorShape: Qt.PointingHandCursor
                radius: Theme.moduleEdgeRadius - 4
                label: "+ New workspace"
                onClicked: {
                    Hyprland.dispatch("movetoworkspacesilent empty,address:0x" + contextPanelItem.targetAddress)
                    contextPanelItem.visible = false
                }
            }

            Repeater {
                model: Hyprland.workspaces.values
                delegate: ModuleButton {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 34
                    variant: "neutral"
                    cursorShape: Qt.PointingHandCursor
                    radius: Theme.moduleEdgeRadius - 4
                    label: modelData.name
                    onClicked: {
                        Hyprland.dispatch("movetoworkspacesilent " + modelData.id + ",address:0x" + contextPanelItem.targetAddress)
                        contextPanelItem.visible = false
                    }
                }
            }
        }
    }
}
