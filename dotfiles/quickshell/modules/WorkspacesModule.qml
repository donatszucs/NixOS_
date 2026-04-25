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

    implicitHeight: Theme.moduleHeight

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
                variant: active ? "light" : "neutral"
                border.width: 2
                border.color: pal.pillBorder
                property int activeDragCount: 0
                z: activeDragCount > 0 ? 99 : 0
                
                implicitHeight: root.implicitHeight - 2 * root.overlay
                implicitWidth: active ? 20 + wsContentRow.implicitWidth : 15 + wsContentRow.implicitWidth
                cursorShape: Qt.PointingHandCursor
                clip: false

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

                colorOverride: dropArea.containsDrag
                overrideColor: hoverColor

                DropArea {
                    id: dropArea
                    anchors.fill: parent
                    onDropped: (drop) => {
                        if (drop.source && drop.source.address) {
                            Hyprland.dispatch("movetoworkspacesilent " + wsButton.modelData.id + ",address:0x" + drop.source.address)
                        }
                    }
                }

                onClicked: {
                    Hyprland.dispatch("workspace " + wsButton.modelData.id)
                }

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
                        color: Theme.paletteInk
                        opacity: 0.3
                        radius: 2
                    }

                    Repeater {
                        model: wsButton.modelData.toplevels.values
                        delegate: WorkspaceAppIcon {
                            workspaceBtn: wsButton
                        }
                    } // Repeater
                } // RowLayout

                Behavior on implicitWidth {
                    NumberAnimation { duration: Theme.horizontalDuration / 4; easing.type: Easing.linear }
                }
            }
        }

        ModuleButton {
            label: ""
            variant: "neutral"
            border.width: 2
            border.color: pal.pillBorder
            implicitWidth: root.implicitHeight - 2 * root.overlay
            implicitHeight: root.implicitHeight - 2 * root.overlay
            
            topLeftRadius: 5
            bottomLeftRadius: 5

            topRightRadius: Theme.moduleEdgeRadius
            bottomRightRadius: Theme.moduleEdgeRadius

            colorOverride: emptyDropArea.containsDrag
            overrideColor: hoverColor

            DropArea {
                id: emptyDropArea
                anchors.fill: parent
                onDropped: (drop) => {
                    if (drop.source && drop.source.address) {
                        Hyprland.dispatch("movetoworkspacesilent empty,address:0x" + drop.source.address)
                    }
                }
            }

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
                id: othersButton
                required property var modelData
                required property int index
                variant: active ? "light" : "neutral"
                border.width: 2
                border.color: pal.pillBorder
                property int activeDragCount: 0
                z: activeDragCount > 0 ? 99 : 0
                
                HoverHandler { id: hoverHandler }
                property bool isHovered: hoverHandler.hovered

                implicitHeight: root.implicitHeight - 2 * root.overlay
                implicitWidth: isHovered ? (15 + othersContentRow.implicitWidth) : 25
                cursorShape: Qt.PointingHandCursor
                clip: activeDragCount === 0
                
                // Apply the parent's radius ONLY if this is the absolute last item in the list!
                topLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 5
                bottomLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 5
                topRightRadius: index === root.monitorWorkspaces.others.length - 1 ? Theme.moduleEdgeRadius : 5
                bottomRightRadius: index === root.monitorWorkspaces.others.length - 1 ? Theme.moduleEdgeRadius : 5

                readonly property bool active:
                    Hyprland.focusedMonitor !== null &&
                    Hyprland.focusedMonitor.activeWorkspace !== null &&
                    Hyprland.focusedMonitor.activeWorkspace.id === modelData.id
                    
                colorOverride: othersDropArea.containsDrag
                overrideColor: hoverColor

                DropArea {
                    id: othersDropArea
                    anchors.fill: parent
                    onDropped: (drop) => {
                        if (drop.source && drop.source.address) {
                            Hyprland.dispatch("movetoworkspacesilent " + modelData.id + ",address:0x" + drop.source.address)
                        }
                    }
                }

                label: ""

                RowLayout {
                    id: othersContentRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: modelData.name
                        color: parent.parent.textColor || "white"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                    }

                    Rectangle {
                        visible: isHovered && modelData.toplevels.values.length > 0
                        width: root.overlay
                        height: Theme.moduleHeight - 15
                        color: Theme.paletteInk
                        opacity: 0.3
                        radius: 2
                    }

                    Repeater {
                        model: isHovered ? othersButton.modelData.toplevels.values : null
                        delegate: WorkspaceAppIcon {
                            workspaceBtn: othersButton
                        }
                    } // Repeater
                }

                Behavior on implicitWidth {
                    NumberAnimation { duration: Theme.horizontalDuration / 4; easing.type: Easing.linear }
                }

                onClicked: Hyprland.dispatch("workspace " + modelData.id)
            }
        }
    }


    component WorkspaceAppIcon : Item {
        id: dragContainer
        
        required property var modelData
        property var workspaceBtn
        
        z: windowIcon.Drag.active ? 99 : 0
        
        implicitWidth: windowIcon.width
        implicitHeight: Theme.moduleHeight - 15
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        visible: windowIcon.appId !== ""

        IconImage {
            id: windowIcon
            
            anchors.verticalCenter: dragArea.drag.active ? undefined : parent.verticalCenter
            anchors.horizontalCenter: dragArea.drag.active ? undefined : parent.horizontalCenter
            
            property string address: String(modelData.address)

            height: Theme.moduleHeight - 15
            width: {
                var systemIcon = String(source).indexOf("image://icon/") === 0;
                if (systemIcon) return height;
                var w = Math.max(implicitWidth, 1);
                var h = Math.max(implicitHeight, 1);
                return (w / h) * height;
            }

            readonly property string appId: {
                if (modelData.wayland && modelData.wayland.appId !== "") return modelData.wayland.appId;
                if (modelData.x11 && modelData.x11.appId !== "") return modelData.x11.appId;
                return "";
            }
            
            readonly property bool isSteam: appId.toLowerCase().indexOf("steam_app_") === 0
            readonly property string steamId: isSteam ? appId.substring(10) : ""
            property string steamImagePath: ""

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
                
                for (var j = 0; j < entries.length; j++) {
                    if (entries[j].name.toLowerCase() === appLower || entries[j].name.toLowerCase().indexOf(appLower) >= 0)
                        return Quickshell.iconPath(entries[j].icon !== "" ? entries[j].icon : appId)
                }
                
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

            source: resolvedIcon
            visible: appId !== ""
            z: dragArea.drag.active ? 999 : 0

            Drag.active: dragArea.drag.active
            Drag.source: windowIcon
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
            
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
                acceptedButtons: Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor

                onClicked: function(mouse) {
                    if (mouse.button === Qt.MiddleButton) {
                        Hyprland.dispatch("closewindow address:0x" + modelData.address)
                    }
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                
                drag.target: windowIcon
                drag.axis: Drag.XAndYAxis
                drag.threshold: 4

                onReleased: {
                    if (drag.active) {
                        windowIcon.Drag.drop()
                    }
                }

                onClicked: function(mouse) {
                    if (dragArea.drag.active) return;
                    if (workspaceBtn && workspaceBtn.modelData) {
                        Hyprland.dispatch("workspace " + workspaceBtn.modelData.id)
                    }
                }
            }
            
            Connections {
                target: dragArea.drag
                function onActiveChanged() {
                    if (!workspaceBtn) return;
                    if (dragArea.drag.active) workspaceBtn.activeDragCount++;
                    else workspaceBtn.activeDragCount--;
                }
            }
        }
    }
}
