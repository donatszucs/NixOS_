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
    property string displayMode: "all"
    property bool expanded: false

    signal requestContextMenu(var windowData, var globalPos)

    clip: false

    color: Qt.rgba(Theme.palette("dark").base.r, Theme.palette("dark").base.g, Theme.palette("dark").base.b, Theme.moduleOpacity)

    radius: Theme.moduleEdgeRadius + 2
    property int overlay: 4
    property int activeDragCount: 0
    z: activeDragCount > 0 ? 100 : 0

    anchors.topMargin: 4
    implicitHeight: Theme.moduleHeight - 4

    property var activeSpecialWorkspaces: ({})

    function getCurrentWorkspace() {
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++) {
            if (mons[i].name === root.screenName && mons[i].activeWorkspace) {
                return mons[i].activeWorkspace;
            }
        }
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace) {
            return Hyprland.focusedMonitor.activeWorkspace;
        }
        return null;
    }

    property alias workspacesRow: workspacesRow

    function findDropWorkspaceButton(windowPoint) {
        var modules = [];
        if (root.parent && root.parent.children) {
            for (var i = 0; i < root.parent.children.length; i++) {
                var child = root.parent.children[i];
                if (child && child.workspacesRow) {
                    modules.push(child);
                }
            }
        }
        if (modules.indexOf(root) === -1) {
            modules.push(root);
        }

        for (var m = 0; m < modules.length; m++) {
            var mod = modules[m];
            var row = mod.workspacesRow;
            if (!row || !row.children) continue;
            for (var b = 0; b < row.children.length; b++) {
                var btn = row.children[b];
                if (btn && btn.visible && (btn.isEmptyWorkspace !== undefined || btn.isOtherWorkspace !== undefined)) {
                    var localPt = btn.mapFromItem(null, windowPoint.x, windowPoint.y);
                    if (localPt.x >= 0 && localPt.x <= btn.width && localPt.y >= 0 && localPt.y <= btn.height) {
                        return btn;
                    }
                }
            }
        }
        return null;
    }

    Process {
        id: monitorsInitProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var out = JSON.parse(text.trim());
                    var newState = {};
                    for (var i = 0; i < out.length; i++) {
                        if (out[i].specialWorkspace && out[i].specialWorkspace.name !== "") {
                            newState[out[i].name] = out[i].specialWorkspace.name;
                        }
                    }
                    root.activeSpecialWorkspaces = newState;
                } catch(e) {}
            }
        }
    }

    Component.onCompleted: {
        monitorsInitProc.running = true;
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activespecial") {
                var parts = event.data.split(",");
                var ws = parts[0];
                var mon = parts.length > 1 ? parts[1] : "";
                var newState = Object.assign({}, root.activeSpecialWorkspaces);
                if (ws === "") {
                    delete newState[mon];
                } else {
                    newState[mon] = ws.indexOf("special:") === 0 ? ws : "special:" + ws;
                }
                root.activeSpecialWorkspaces = newState;
            }
        }
    }

    // Only workspaces whose monitor name matches this bar's screen
    readonly property var monitorWorkspaces: {
        var all = Hyprland.workspaces.values
        var out = []
        var others = []
        
        for (var i = 0; i < all.length; i++) {
            var isSpecial = all[i].name && all[i].name.indexOf("special:") === 0
            
            if (isSpecial) {
                var isActiveSpecial = false;
                var activeOnMon = "";
                for (var monName in root.activeSpecialWorkspaces) {
                    if (root.activeSpecialWorkspaces[monName] === all[i].name) {
                        isActiveSpecial = true;
                        activeOnMon = monName;
                        break;
                    }
                }
                
                if (!isActiveSpecial) {
                    continue;
                }

                if (activeOnMon === screenName)
                    out.push(all[i])
                else 
                    others.push(all[i])
                
                continue;
            }

            if (all[i].monitor && all[i].monitor.name === screenName)
                out.push(all[i])
            else 
                others.push(all[i])
        }
        return { workspaces: out, others: others }
    }

    implicitWidth: (displayMode === "other" && monitorWorkspaces.others.length === 0) ? 0 : (workspacesRow.implicitWidth + 2 * overlay)

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.horizontalDuration / 2; easing.type: Easing.OutCubic }
    }

    RowLayout {
        id: workspacesRow
        anchors.centerIn: parent
        spacing: root.overlay - 1

        Repeater {
            model: (root.displayMode === "all" || root.displayMode === "monitor") ? root.monitorWorkspaces.workspaces : []
            delegate: WorkspaceButton {
                isOtherWorkspace: false
                isLastInGroup: false
            }
        }

        WorkspaceButton {
            visible: root.displayMode === "all" || root.displayMode === "monitor"
            isEmptyWorkspace: true
            modelData: null
            index: -1
            isLastInGroup: true
        }

        Rectangle {
            visible: root.displayMode === "all" && root.monitorWorkspaces.others.length > 0
            width: root.overlay
            height: 1
            color: "transparent"
        }

        Repeater {
            model: (root.displayMode === "all" || root.displayMode === "other") ? root.monitorWorkspaces.others : []
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
        
        property bool showApps: !isEmptyWorkspace
        property bool hasApps: !isEmptyWorkspace && modelData !== null && modelData.toplevels && modelData.toplevels.values.length > 0

        implicitHeight: root.implicitHeight - 2 * root.overlay
        implicitWidth: isEmptyWorkspace ? implicitHeight : Math.max(contentRow.implicitWidth, implicitHeight)
        cursorShape: Qt.PointingHandCursor
        clip: activeDragCount === 0
        
        topLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 5
        bottomLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 5
        topRightRadius: isLastInGroup ? Theme.moduleEdgeRadius : 5
        bottomRightRadius: isLastInGroup ? Theme.moduleEdgeRadius : 5

        readonly property bool isSpecial: modelData !== null && modelData.name && modelData.name.indexOf("special:") === 0

        readonly property bool active: !isEmptyWorkspace &&
            Hyprland.focusedMonitor !== null &&
            ((Hyprland.focusedMonitor.activeWorkspace !== null && Hyprland.focusedMonitor.activeWorkspace.id === modelData.id) ||
             (isSpecial && root.activeSpecialWorkspaces[Hyprland.focusedMonitor.name] === modelData.name))

        label: isEmptyWorkspace ? "" : ""

        colorOverride: true
        overrideColor: control.isSpecial ? "transparent" : Qt.darker(control.pal.base, 1.4)

        onClicked: {
            var targetId = isEmptyWorkspace ? 'empty' : (control.isSpecial ? modelData.name : modelData.id);
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
                visible: !control.isSpecial
                color: control.pal.base
                topLeftRadius: control.topLeftRadius
                bottomLeftRadius: control.bottomLeftRadius
                property bool cutoutsActive: hasApps && showApps

                topRightRadius: cutoutsActive ? 0 : control.topRightRadius
                bottomRightRadius: cutoutsActive ? 0 : control.bottomRightRadius
                implicitWidth: control.isSpecial ? 0 : 24
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
                Layout.leftMargin: showApps ? (control.isSpecial ? 7 : 2) : 0
                Layout.rightMargin: showApps ? 7 : 0
                Repeater {
                    model: (hasApps && showApps) ? modelData.toplevels.values : null
                    delegate: WorkspaceAppIcon {
                        workspaceBtn: control
                    }
                }
            }
        }

        Behavior on implicitWidth {
            NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
        }
    }

    component WorkspaceAppIcon : Item {
        id: dragContainer
        
        required property var modelData
        property var workspaceBtn
        
        z: windowIcon.isDragging ? 99 : 0
        
        implicitWidth: windowIcon.width
        implicitHeight: Theme.moduleHeight - 20
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

        Image {
            id: windowIcon
            
            x: 0
            y: 0
            
            property string address: String(modelData.address)
            property bool isDragging: false

            opacity: isDragging ? 0.85 : 1.0
            scale: isDragging ? 1.15 : 1.0

            height: Theme.moduleHeight - 20
            property real imgAspect: (implicitWidth > 0 && implicitHeight > 0) ? (implicitWidth / implicitHeight) : 1.0
            width: height * imgAspect

            fillMode: Image.PreserveAspectFit
            asynchronous: true
            mipmap: true

            property bool isSystemIcon: String(source).indexOf("image://icon/") === 0
            sourceSize: isSystemIcon ? Qt.size(128, 128) : Qt.size(0, 0)

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
                        Quickshell.env("HOME") + "/.config/quickshell/scripts/SteamIcon/SteamIconSearch.sh", 
                        "/home/doni/.steam/root/appcache/librarycache/" + steamId
                    ]);
                    return steamImagePath !== "" ? steamImagePath : Quickshell.iconPath("steam");
                }
                
                var entries = DesktopEntries.applications.values
                var appLower = appId.toLowerCase();
                if (appLower.indexOf("minecraft") >= 0) return Quickshell.iconPath("minecraft");

                for (var i = 0; i < entries.length; i++) {
                    var entryId = entries[i].id.toLowerCase();
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
                    if (titleLower.indexOf("minecraft") >= 0) return Quickshell.iconPath("minecraft");

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
            z: isDragging ? 999 : 0
            
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
                id: dragArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                property point pressPos: Qt.point(0, 0)
                property bool wasDragged: false

                drag.target: windowIcon
                drag.axis: Drag.XAndYAxis
                drag.threshold: 4

                function handleDragStart() {
                    if (windowIcon.isDragging) return;
                    dragArea.wasDragged = true;
                    windowIcon.isDragging = true;
                    if (workspaceBtn) workspaceBtn.activeDragCount++;
                    root.activeDragCount++;
                }

                function handleDragEnd() {
                    if (!windowIcon.isDragging && !dragArea.wasDragged) return;

                    var iconCenterInWindow = windowIcon.mapToItem(null, windowIcon.width / 2, windowIcon.height / 2);
                    var addr = String(modelData.address).trim();
                    if (addr.indexOf("0x") === 0) addr = addr.substring(2);
                    var winSelector = "address:0x" + addr;

                    // 1. Check if dropped on any workspace button (in activeWorkspaces or otherWorkspaces)
                    var targetBtn = root.findDropWorkspaceButton(iconCenterInWindow);
                    if (targetBtn) {
                        if (targetBtn === workspaceBtn) {
                            // Dropped on itself - do nothing
                        } else if (targetBtn.isEmptyWorkspace) {
                            var emptyMon = targetBtn.isOtherWorkspace && targetBtn.modelData && targetBtn.modelData.monitor 
                                           ? targetBtn.modelData.monitor.name : root.screenName;
                            if (emptyMon && emptyMon !== "") {
                                Hyprland.dispatch("hl.dsp.focus({ monitor = '" + emptyMon + "' })) and hl.dispatch(hl.dsp.window.move({ workspace = 'empty', window = '" + winSelector + "', follow = false })");
                            } else {
                                Hyprland.dispatch("hl.dsp.window.move({ workspace = 'empty', window = '" + winSelector + "', follow = false })");
                            }
                        } else if (targetBtn.modelData) {
                            var targetWsId = targetBtn.isSpecial ? targetBtn.modelData.name : targetBtn.modelData.id;
                            Hyprland.dispatch("hl.dsp.window.move({ workspace = '" + targetWsId + "', window = '" + winSelector + "', follow = false })");
                        }
                    } else {
                        // 2. Check if dropped on the desktop (current monitor or other monitor)
                        var originMon = null;
                        var mons = Hyprland.monitors.values;
                        for (var i = 0; i < mons.length; i++) {
                            if (mons[i].name === root.screenName) {
                                originMon = mons[i];
                                break;
                            }
                        }
                        if (!originMon && Hyprland.focusedMonitor) {
                            originMon = Hyprland.focusedMonitor;
                        }

                        var globalX = originMon ? (originMon.x + iconCenterInWindow.x) : iconCenterInWindow.x;
                        var globalY = originMon ? (originMon.y + iconCenterInWindow.y) : iconCenterInWindow.y;

                        var targetMon = null;
                        for (var j = 0; j < mons.length; j++) {
                            var m = mons[j];
                            if (globalX >= m.x && globalX < m.x + m.width &&
                                globalY >= m.y && globalY < m.y + m.height) {
                                targetMon = m;
                                break;
                            }
                        }
                        if (!targetMon) targetMon = originMon;

                        var targetWs = targetMon && targetMon.activeWorkspace ? targetMon.activeWorkspace : null;
                        var isBelowBar = (iconCenterInWindow.y > Theme.moduleHeight + 5) || (targetMon !== originMon);
                        var isCurrentWs = (targetWs && workspaceBtn && workspaceBtn.modelData && 
                                           !workspaceBtn.isSpecial && workspaceBtn.modelData.id === targetWs.id);

                        if (isBelowBar && !isCurrentWs && targetWs) {
                            Hyprland.dispatch("hl.dsp.window.move({ workspace = '" + targetWs.id + "', window = '" + winSelector + "', follow = false })");
                        }
                    }

                    windowIcon.isDragging = false;
                    windowIcon.x = 0;
                    windowIcon.y = 0;
                    if (workspaceBtn) workspaceBtn.activeDragCount = Math.max(0, workspaceBtn.activeDragCount - 1);
                    root.activeDragCount = Math.max(0, root.activeDragCount - 1);
                }

                property bool isDragActive: drag.active
                onIsDragActiveChanged: {
                    if (isDragActive && !windowIcon.isDragging) {
                        handleDragStart();
                    }
                }

                onPressed: (mouse) => {
                    dragArea.wasDragged = false;
                    dragArea.pressPos = Qt.point(mouse.x, mouse.y);
                }

                onPositionChanged: (mouse) => {
                    if (!windowIcon.isDragging && (mouse.buttons & Qt.LeftButton)) {
                        var dx = mouse.x - dragArea.pressPos.x;
                        var dy = mouse.y - dragArea.pressPos.y;
                        if ((dx * dx + dy * dy) > 16) {
                            handleDragStart();
                        }
                    }
                }

                onReleased: (mouse) => {
                    if (windowIcon.isDragging || dragArea.wasDragged) {
                        handleDragEnd();
                    }
                }

                onCanceled: {
                    if (windowIcon.isDragging || dragArea.wasDragged) {
                        handleDragEnd();
                    }
                }

                onClicked: (mouse) => {
                    if (dragArea.wasDragged) return;
                    if (mouse.button === Qt.MiddleButton) {
                        var addr = String(modelData.address).trim();
                        if (addr.indexOf("0x") === 0) addr = addr.substring(2);
                        Hyprland.dispatch("hl.dsp.window.close({ window = 'address:0x" + addr + "' })");
                    } else if (mouse.button === Qt.LeftButton) {
                        if (workspaceBtn && workspaceBtn.modelData) {
                            var targetId = workspaceBtn.isSpecial ? workspaceBtn.modelData.name : workspaceBtn.modelData.id;
                            Hyprland.dispatch("hl.dsp.focus({ workspace = '" + targetId + "' })");
                        }
                    } else if (mouse.button === Qt.RightButton) {
                        var iconCenterBottom = windowIcon.mapToItem(null, windowIcon.width / 2, windowIcon.height + 4);
                        var winData = {
                            address: String(modelData.address),
                            title: modelData.title || windowIcon.appId || "Window",
                            appId: windowIcon.appId,
                            icon: windowIcon.resolvedIcon,
                            isFloating: (modelData.lastIpcObject && modelData.lastIpcObject.floating !== undefined) ? Boolean(modelData.lastIpcObject.floating) : false,
                            isPinned: (modelData.lastIpcObject && modelData.lastIpcObject.pinned !== undefined) ? Boolean(modelData.lastIpcObject.pinned) : false,
                            isFullscreen: (modelData.lastIpcObject && modelData.lastIpcObject.fullscreen !== undefined) ? (modelData.lastIpcObject.fullscreen > 0) : false,
                            workspace: (workspaceBtn && workspaceBtn.modelData) ? (workspaceBtn.isSpecial ? workspaceBtn.modelData.name : workspaceBtn.modelData.id) : ""
                        };
                        root.requestContextMenu(winData, iconCenterBottom);
                    }
                }
            }
        }
    }
}
