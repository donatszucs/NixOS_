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

    color: Qt.rgba(Theme.palette("dark").base.r, Theme.palette("dark").base.g, Theme.palette("dark").base.b, Theme.moduleOpacity)

    radius: Theme.moduleEdgeRadius + 2
    property int overlay: 4

    anchors.topMargin: 4
    implicitHeight: Theme.moduleHeight - 4

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
            delegate: WorkspaceButton {
                isOtherWorkspace: false
                isLastInGroup: false
            }
        }

        WorkspaceButton {
            isEmptyWorkspace: true
            modelData: null
            index: -1
            isLastInGroup: true
        }

        Rectangle {
            visible: root.monitorWorkspaces.others.length > 0
            width: root.overlay
            height: 1
            color: "transparent"
        }

        Repeater {
            model: root.monitorWorkspaces.others
            delegate: WorkspaceButton {
                isOtherWorkspace: true
                isLastInGroup: index === root.monitorWorkspaces.others.length - 1
            }
        }
    }


    component WorkspaceButton : ModuleButton {
        id: control
        required property var modelData
        required property int index
        property bool isOtherWorkspace: false
        property bool isLastInGroup: false
        property bool isEmptyWorkspace: false

        variant: active ? "light" : "neutral"
        border.width: 2
        property int activeDragCount: 0
        z: activeDragCount > 0 ? 99 : 0
        
        HoverHandler { id: hoverHandler }
        property bool isHovered: hoverHandler.hovered
        property bool showApps: (!isOtherWorkspace || isHovered) && !isEmptyWorkspace
        property bool hasApps: !isEmptyWorkspace && modelData !== null && modelData.toplevels && modelData.toplevels.values.length > 0

        implicitHeight: root.implicitHeight - 2 * root.overlay
        implicitWidth: isEmptyWorkspace ? implicitHeight : Math.max(contentRow.implicitWidth, implicitHeight)
        cursorShape: Qt.PointingHandCursor
        clip: activeDragCount === 0

        topLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 5
        bottomLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 5
        topRightRadius: isLastInGroup ? Theme.moduleEdgeRadius : 5
        bottomRightRadius: isLastInGroup ? Theme.moduleEdgeRadius : 5

        readonly property bool active: !isEmptyWorkspace &&
            Hyprland.focusedMonitor !== null &&
            Hyprland.focusedMonitor.activeWorkspace !== null &&
            modelData !== null &&
            Hyprland.focusedMonitor.activeWorkspace.id === modelData.id

        label: isEmptyWorkspace ? "" : ""

        colorOverride: true
        overrideColor: dropArea.containsDrag ? hoverColor : Qt.darker(control.pal.base, 1.4)

        DropArea {
            id: dropArea
            anchors.fill: parent
            onDropped: (drop) => {
                if (drop.source && drop.source.address) {
                    var targetId = isEmptyWorkspace ? 'empty' : modelData.id;
                    Hyprland.dispatch("hl.dsp.window.move({ workspace = '" + targetId + "', window = 'address:0x" + drop.source.address + "', follow = false })")
                }
            }
        }

        onClicked: {
            var targetId = isEmptyWorkspace ? 'empty' : modelData.id;
            Hyprland.dispatch("hl.dsp.focus({ workspace = '" + targetId + "' })")
        }

        scale: 0
        Component.onCompleted: {
            scale = 1
        }
        
        Behavior on scale {
            NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutBack }
        }

        RowLayout {
            id: contentRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: 5
            visible: !isEmptyWorkspace

            Rectangle {
                color: control.pal.base
                topLeftRadius: control.topLeftRadius
                bottomLeftRadius: control.bottomLeftRadius
                property bool cutoutsActive: hasApps && showApps

                topRightRadius: cutoutsActive ? 0 : control.topRightRadius
                bottomRightRadius: cutoutsActive ? 0 : control.bottomRightRadius
                implicitWidth: 24
                implicitHeight: control.height

                InverseRadius {
                    visible: parent.cutoutsActive
                    anchors.top: parent.top
                    anchors.left: parent.right
                    cornerPosition: "topLeft"
                    color: parent.color
                    size: 5
                }

                InverseRadius {
                    visible: parent.cutoutsActive
                    anchors.bottom: parent.bottom
                    anchors.left: parent.right
                    cornerPosition: "bottomLeft"
                    color: parent.color
                    size: 5
                }

                Text {
                    anchors.centerIn: parent
                    text: isEmptyWorkspace ? "" : (modelData ? modelData.name : "")
                    color: active ? Theme.textDark : Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }
            }

            RowLayout {
                visible: hasApps && showApps
                spacing: 5
                Layout.leftMargin: showApps ? 2 : 0
                Layout.rightMargin: showApps ? 5 : 0
                Repeater {
                    model: (hasApps && showApps) ? modelData.toplevels.values : null
                    delegate: WorkspaceAppIcon {
                        workspaceBtn: control
                    }
                }
            }
        }

        Behavior on implicitWidth {
            NumberAnimation { duration: Theme.horizontalDuration / 4; easing.type: Easing.Linear }
        }
    }

    component WorkspaceAppIcon : Item {
        id: dragContainer
        
        required property var modelData
        property var workspaceBtn
        
        z: windowIcon.Drag.active ? 99 : 0
        
        implicitWidth: windowIcon.width
        implicitHeight: Theme.moduleHeight - 18
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        visible: windowIcon.appId !== ""

        scale: 0
        Component.onCompleted: {
            scale = 1
        }
        
        Behavior on scale {
            NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutBack }
        }

        IconImage {
            id: windowIcon
            
            anchors.verticalCenter: dragArea.drag.active ? undefined : parent.verticalCenter
            anchors.horizontalCenter: dragArea.drag.active ? undefined : parent.horizontalCenter
            
            property string address: String(modelData.address)

            height: Theme.moduleHeight - 18
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
                        Hyprland.dispatch("hl.dsp.window.close({ window = 'address:0x" + modelData.address + "' })")
                    }
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                ToolTip {
                    id: appToolTip
                    x: parent.width + 10
                    visible: dragArea.containsMouse && !dragArea.drag.active
                    delay: 250
                    text: modelData.title || windowIcon.appId
                    

                    contentItem: Text {
                        text: appToolTip.text
                        color: "white"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                    }

                    background: Rectangle {
                        color: root.color
                        radius: 5
                        border.color: Theme.palette("dark").border
                        border.width: 2
                    }
                }
                
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
                        Hyprland.dispatch("hl.dsp.focus({ workspace = '" + workspaceBtn.modelData.id + "' })")
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
