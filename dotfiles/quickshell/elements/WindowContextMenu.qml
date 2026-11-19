import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: root
    anchors.fill: parent

    property bool isOpen: false
    property bool isPreview: false
    readonly property bool isFullMenu: isOpen && !isPreview
    property bool _animateResize: false

    visible: isOpen || opacity > 0.001
    opacity: isOpen ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    property string targetAddress: ""
    property string targetTitle: ""
    property string targetAppId: ""
    property string targetIcon: ""
    property string targetWorkspace: ""
    property var targetToplevel: null
    property bool isFloating: false
    property bool isPinned: false
    property bool isFullscreen: false

    onVisibleChanged: {
        if (!visible) {
            targetToplevel = null;
        }
    }

    readonly property string cleanAddress: {
        var a = String(targetAddress).trim();
        return a.indexOf("0x") === 0 ? a.substring(2) : a;
    }

    property real targetOriginX: 0
    property real targetOriginY: 0

    property alias menuCard: card

    property var workspacesModule: null

    function getCurrentWorkspace() {
        if (root.workspacesModule && typeof root.workspacesModule.getCurrentWorkspace === "function") {
            return root.workspacesModule.getCurrentWorkspace();
        }
        return null;
    }

    readonly property bool isOnCurrentWorkspace: {
        var cur = getCurrentWorkspace();
        if (!cur) return false;
        var curId = cur.id !== undefined ? String(cur.id) : "";
        var curName = cur.name !== undefined ? String(cur.name) : "";
        return root.targetWorkspace === curId || root.targetWorkspace === curName;
    }

    function pullToCurrentWorkspace() {
        var cur = getCurrentWorkspace();
        if (cur) {
            var targetWsId = cur.isSpecial ? cur.name : (cur.id !== undefined ? cur.id : cur.name);
            Hyprland.dispatch("hl.dsp.window.move({ workspace = '" + targetWsId + "', window = 'address:0x" + root.cleanAddress + "' })");
            Hyprland.dispatch("hl.dsp.focus({ window = 'address:0x" + root.cleanAddress + "' })");
        }
        root.close();
    }

    // Auto-close if another module opens
    Connections {
        target: SharedState
        function onActiveModuleChanged() {
            if (root.isOpen) root.close();
        }
    }

    // Hyprctl query process to ensure live state
    Process {
        id: clientQueryProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var clients = JSON.parse(text.trim());
                    var cleanTarget = root.cleanAddress.toLowerCase();
                    for (var i = 0; i < clients.length; i++) {
                        var c = clients[i];
                        var cAddr = String(c.address).toLowerCase().replace(/^0x/, "");
                        if (cAddr === cleanTarget) {
                            root.isFloating = Boolean(c.floating);
                            root.isPinned = Boolean(c.pinned);
                            root.isFullscreen = (c.fullscreen !== undefined && c.fullscreen > 0);
                            if (c.workspace) {
                                root.targetWorkspace = c.workspace.name || String(c.workspace.id);
                            }
                            break;
                        }
                    }
                } catch(e) {}
            }
        }
    }

    function _applyWindowData(winData, globalPos) {
        if (winData && winData.workspacesModule) {
            workspacesModule = winData.workspacesModule;
        }

        var sameTarget = root.isOpen && root.targetAddress === String(winData.address);

        targetAddress = winData.address;
        targetTitle = winData.title || winData.appId || "Window";
        targetAppId = winData.appId || "";
        targetIcon = winData.icon || "";
        targetWorkspace = winData.workspace !== undefined ? String(winData.workspace) : "";
        targetToplevel = (winData && winData.toplevel) ? winData.toplevel : null;

        if (!sameTarget) {
            isFloating = Boolean(winData.isFloating);
            isPinned = Boolean(winData.isPinned);
            isFullscreen = Boolean(winData.isFullscreen);
        }

        targetOriginX = globalPos.x;
        targetOriginY = globalPos.y;
    }

    function open(winData, globalPos) {
        if (!winData || !winData.address) return;

        _animateResize = root.isOpen && root.isPreview && root.targetAddress === String(winData.address);
        _applyWindowData(winData, globalPos);
        isPreview = false;

        updatePosition();
        isOpen = true;
        card.forceActiveFocus();

        // Check live properties asynchronously
        clientQueryProc.running = false;
        clientQueryProc.running = true;
    }

    function openPreview(winData, globalPos) {
        if (!winData || !winData.address) return;
        if (root.isFullMenu) return;

        _animateResize = false;
        _applyWindowData(winData, globalPos);
        isPreview = true;

        updatePosition();
        isOpen = true;

        // Check live properties asynchronously
        clientQueryProc.running = false;
        clientQueryProc.running = true;
    }

    function closePreview(address) {
        if (!root.isOpen || !root.isPreview) return;
        if (address !== undefined && address !== "" && root.targetAddress !== String(address)) return;
        isOpen = false;
    }

    function close() {
        isOpen = false;
    }

    function updatePosition() {
        var cardW = card.width > 0 ? card.width : 230;
        var cardH = card.height > 0 ? card.height : (root.isPreview ? 70 : 260);
        var margin = 12;

        card.x = Math.round(Math.max(margin, Math.min(targetOriginX - (cardW / 2), root.width - cardW - margin)));
        card.y = Math.round(Math.max(margin, Math.min(targetOriginY + 4, root.height - cardH - margin)));
    }

    // Dismiss when clicking anywhere outside the menu card (only active in full right-click mode)
    MouseArea {
        anchors.fill: parent
        enabled: root.isFullMenu
        visible: enabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: (mouse) => {
            root.close();
            mouse.accepted = false;
        }
    }

    // Menu Card
    Rectangle {
        id: card
        width: 230
        height: Math.round(mainCol.implicitHeight) + 16

        Behavior on height {
            enabled: root._animateResize
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        onHeightChanged: {
            if (root.isOpen) root.updatePosition();
        }

        color: "transparent"
        radius: 12
        border.width: 0

        scale: root.isOpen ? 1.0 : 0.94
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        Rectangle {
            id: background
            anchors.fill: parent
            z: -1
            radius: card.radius
            color: Qt.rgba(Theme.palette("dark").base.r, Theme.palette("dark").base.g, Theme.palette("dark").base.b, 0.94)
            border.color: Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.22)
            border.width: 1

            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.6)
                shadowBlur: 1.0
                shadowVerticalOffset: 6
                shadowHorizontalOffset: 0
            }
        }

        Keys.onEscapePressed: root.close()

        // Block clicks from propagating to the background dismiss area
        MouseArea {
            anchors.fill: parent
            enabled: root.isFullMenu
            visible: enabled
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {}
        }

        Item {
            id: contentClip
            anchors.fill: parent
            clip: true

            ColumnLayout {
                id: mainCol
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 8
                }
                spacing: 4

                // ── Header: App Icon, Title, Status Badges ─────────────────
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(headerLayout.implicitHeight) + 12
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.05)

                    HoverHandler { id: headerHover }

                    RowLayout {
                        id: headerLayout
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 8
                            topMargin: 6
                            bottomMargin: 6
                        }
                        spacing: 8

                        Image {
                            source: root.targetIcon
                            sourceSize: Qt.size(48, 48)
                            width: 24
                            height: 24
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            visible: root.targetIcon !== ""
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            HoverMarqueeText {
                                text: root.targetTitle
                                textColor: Theme.textPrimary
                                fontFamily: Theme.font
                                pixelSize: 12
                                fontBold: true
                                textMaxWidth: 170
                                forceHovered: headerHover.hovered
                                autoScroll: root.isOpen && root.isPreview
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: 4

                                // Floating / Tiled Pill
                                Rectangle {
                                    implicitHeight: 14
                                    implicitWidth: Math.ceil(floatText.contentWidth) + 8
                                    radius: 4
                                    color: root.isFloating ? Theme.palette("light").base : Qt.rgba(1, 1, 1, 0.12)

                                    Text {
                                        id: floatText
                                        anchors.fill: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        text: root.isFloating ? "FLOATING" : "TILED"
                                        font.family: Theme.font
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: root.isFloating ? Theme.palette("dark").base : Theme.textPrimary
                                    }
                                }

                                // Pinned Pill
                                Rectangle {
                                    visible: root.isPinned
                                    implicitHeight: 14
                                    implicitWidth: Math.ceil(pinText.contentWidth) + 8
                                    radius: 4
                                    color: Theme.statusBlue

                                    Text {
                                        id: pinText
                                        anchors.fill: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        text: "PINNED"
                                        font.family: Theme.font
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: Theme.palette("dark").base
                                    }
                                }

                                // Fullscreen Pill
                                Rectangle {
                                    visible: root.isFullscreen
                                    implicitHeight: 14
                                    implicitWidth: Math.ceil(fsText.contentWidth) + 8
                                    radius: 4
                                    color: Theme.statusGreen

                                    Text {
                                        id: fsText
                                        anchors.fill: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        text: "FULLSCREEN"
                                        font.family: Theme.font
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: Theme.palette("dark").base
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Window Live Preview (hover only) ──────────────────────
                ClippingRectangle {
                    id: previewFrame
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.isPreview && root.targetToplevel !== null
                    implicitWidth: screencopy.hasContent ? Math.min(card.width - 16, Math.round(screencopy.implicitWidth)) : 0
                    implicitHeight: screencopy.hasContent ? Math.round(screencopy.implicitHeight) : 0
                    Layout.topMargin: screencopy.hasContent ? 2 : -mainCol.spacing
                    radius: 8
                    color: "transparent"

                    ScreencopyView {
                        id: screencopy
                        anchors.centerIn: parent
                        captureSource: (root.visible && root.isPreview && !SharedState.vramSavingMode) ? root.targetToplevel : null
                        live: root.isOpen && root.isPreview
                        paintCursor: false
                        constraintSize: Qt.size(card.width - 16, 150)
                    }
                }

                // ── Menu Action Items (only visible on right-click) ────────
                ColumnLayout {
                    id: actionsSection
                    Layout.fillWidth: true
                    spacing: 4
                    visible: !root.isPreview
                    opacity: root.isPreview ? 0.0 : 1.0

                    Behavior on opacity {
                        enabled: root._animateResize
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }

                    // Divider
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.divider
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                    }

                    // 1. Float / Tile Window
                    ContextMenuItem {
                        iconText: root.isFloating ? "󰙀" : "󰖲"
                        labelText: root.isFloating ? "Tile Window" : "Make Floating"
                        hintText: root.isFloating ? "Tiled" : "Float"
                        isActive: root.isFloating
                        onTriggered: {
                            Hyprland.dispatch("hl.dsp.window.float({ window = 'address:0x" + root.cleanAddress + "' })");
                            root.close();
                        }
                    }

                    // 2. Fullscreen Window
                    ContextMenuItem {
                        iconText: root.isFullscreen ? "󰊓" : ""
                        labelText: root.isFullscreen ? "Exit Fullscreen" : "Fullscreen"
                        hintText: root.isFullscreen ? "Active" : ""
                        isActive: root.isFullscreen
                        onTriggered: {
                            Hyprland.dispatch("hl.dsp.window.fullscreen({ window = 'address:0x" + root.cleanAddress + "' })");
                            root.close();
                        }
                    }

                    // 3. Pin Window (keep on all workspaces)
                    ContextMenuItem {
                        iconText: root.isPinned ? "󰤰" : "󰤱"
                        labelText: root.isPinned ? "Unpin Window" : "Pin to All Workspaces"
                        hintText: root.isPinned ? "Pinned" : ""
                        isActive: root.isPinned
                        onTriggered: {
                            if (!root.isFloating && !root.isPinned) {
                                Hyprland.dispatch("hl.dsp.window.float({ window = 'address:0x" + root.cleanAddress + "' })");
                            }
                            Hyprland.dispatch("hl.dsp.window.pin({ window = 'address:0x" + root.cleanAddress + "' })");
                            root.close();
                        }
                    }

                    // 4. Pull to Current Workspace
                    ContextMenuItem {
                        iconText: "󰁌"
                        labelText: "Pull to Current Workspace"
                        hintText: root.isOnCurrentWorkspace ? "Current" : ""
                        isActive: root.isOnCurrentWorkspace
                        onTriggered: {
                            root.pullToCurrentWorkspace();
                        }
                    }

                    // Divider
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.divider
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                    }

                    // 6. Close Window
                    ContextMenuItem {
                        iconText: "󰅖"
                        labelText: "Close Window"
                        hintText: "Middle click"
                        onTriggered: {
                            Hyprland.dispatch("hl.dsp.window.close({ window = 'address:0x" + root.cleanAddress + "' })");
                            root.close();
                        }
                    }

                    // 7. Force Kill
                    ContextMenuItem {
                        iconText: "󰩈"
                        labelText: "Force Kill"
                        hintText: "SIGKILL"
                        isDanger: true
                        onTriggered: {
                            Hyprland.dispatch("hl.dsp.window.kill({ window = 'address:0x" + root.cleanAddress + "' })");
                            root.close();
                        }
                    }
                }
            }
        }
    }

    // ── ContextMenuItem Component ──────────────────────────────────────
    component ContextMenuItem : Rectangle {
        id: itemRoot
        property string iconText: ""
        property string labelText: ""
        property string hintText: ""
        property bool isDanger: false
        property bool isActive: false
        signal triggered()

        Layout.fillWidth: true
        implicitHeight: 30
        radius: 6

        color: {
            if (itemMouse.containsMouse) {
                return isDanger 
                    ? Qt.rgba(Theme.red.base.r, Theme.red.base.g, Theme.red.base.b, 0.22)
                    : Qt.rgba(1, 1, 1, 0.1);
            }
            if (isActive) {
                return Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.08);
            }
            return "transparent";
        }
        Behavior on color { ColorAnimation { duration: 80 } }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 8
                rightMargin: 8
            }
            spacing: 8

            Text {
                text: itemRoot.iconText
                font.family: Theme.font
                font.pixelSize: 14
                color: {
                    if (itemRoot.isDanger) return Theme.statusRed;
                    if (itemMouse.containsMouse || itemRoot.isActive) return Theme.palette("light").base;
                    return Theme.textPrimary;
                }
                Layout.preferredWidth: 18
                Layout.fillHeight: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                text: itemRoot.labelText
                font.family: Theme.font
                font.pixelSize: 11
                font.bold: itemMouse.containsMouse || itemRoot.isActive
                color: itemRoot.isDanger ? Theme.statusRed : Theme.textPrimary
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Text {
                text: itemRoot.hintText
                font.family: Theme.font
                font.pixelSize: 9
                color: Qt.rgba(1, 1, 1, 0.35)
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                visible: itemRoot.hintText !== ""
            }
        }

        MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: itemRoot.triggered()
        }
    }
}
