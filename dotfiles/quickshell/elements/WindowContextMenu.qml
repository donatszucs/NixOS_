import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root
    anchors.fill: parent

    property bool isOpen: false
    visible: isOpen || opacity > 0.001
    opacity: isOpen ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    property string targetAddress: ""
    property string targetTitle: ""
    property string targetAppId: ""
    property string targetIcon: ""
    property string targetWorkspace: ""
    property bool isFloating: false
    property bool isPinned: false
    property bool isFullscreen: false

    readonly property string cleanAddress: {
        var a = String(targetAddress).trim();
        return a.indexOf("0x") === 0 ? a.substring(2) : a;
    }

    property real targetOriginX: 0
    property real targetOriginY: 0

    property alias menuCard: card

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
                            break;
                        }
                    }
                } catch(e) {}
            }
        }
    }

    function open(winData, globalPos) {
        if (!winData || !winData.address) return;

        targetAddress = winData.address;
        targetTitle = winData.title || winData.appId || "Window";
        targetAppId = winData.appId || "";
        targetIcon = winData.icon || "";
        targetWorkspace = winData.workspace !== undefined ? String(winData.workspace) : "";
        isFloating = Boolean(winData.isFloating);
        isPinned = Boolean(winData.isPinned);
        isFullscreen = Boolean(winData.isFullscreen);

        targetOriginX = globalPos.x;
        targetOriginY = globalPos.y;

        updatePosition();
        isOpen = true;
        card.forceActiveFocus();

        // Check live properties asynchronously
        clientQueryProc.running = false;
        clientQueryProc.running = true;
    }

    function close() {
        isOpen = false;
    }

    function updatePosition() {
        var cardW = card.width > 0 ? card.width : 230;
        var cardH = card.height > 0 ? card.height : 260;
        var margin = 12;

        card.x = Math.max(margin, Math.min(targetOriginX - (cardW / 2), root.width - cardW - margin));
        card.y = Math.max(margin, Math.min(targetOriginY + 4, root.height - cardH - margin));
    }

    // Dismiss when clicking anywhere outside the menu card
    MouseArea {
        anchors.fill: parent
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
        height: mainCol.implicitHeight + 16

        onHeightChanged: {
            if (root.isOpen) root.updatePosition();
        }

        color: Qt.rgba(Theme.palette("dark").base.r, Theme.palette("dark").base.g, Theme.palette("dark").base.b, 0.94)
        radius: 12
        border.color: Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.22)
        border.width: 1.5

        scale: root.isOpen ? 1.0 : 0.94
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.6)
            shadowBlur: 1.0
            shadowVerticalOffset: 6
            shadowHorizontalOffset: 0
        }

        Keys.onEscapePressed: root.close()

        // Block clicks from propagating to the background dismiss area
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {}
        }

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
                implicitHeight: headerLayout.implicitHeight + 12
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.05)

                HoverHandler { id: headerHover }

                RowLayout {
                    id: headerLayout
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 8
                        rightMargin: 8
                    }
                    spacing: 8

                    Image {
                        source: root.targetIcon
                        sourceSize: Qt.size(48, 48)
                        width: 24
                        height: 24
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        fillMode: Image.PreserveAspectFit
                        visible: root.targetIcon !== ""
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        HoverMarqueeText {
                            text: root.targetTitle
                            textColor: Theme.textPrimary
                            fontFamily: Theme.font
                            pixelSize: 12
                            fontBold: true
                            textMaxWidth: 170
                            forceHovered: headerHover.hovered
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: 4

                            // Floating / Tiled Pill
                            Rectangle {
                                implicitHeight: 14
                                implicitWidth: floatText.implicitWidth + 8
                                radius: 4
                                color: root.isFloating ? Theme.palette("light").base : Qt.rgba(1, 1, 1, 0.12)

                                Text {
                                    id: floatText
                                    anchors.centerIn: parent
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
                                implicitWidth: pinText.implicitWidth + 8
                                radius: 4
                                color: Theme.statusBlue

                                Text {
                                    id: pinText
                                    anchors.centerIn: parent
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
                                implicitWidth: fsText.implicitWidth + 8
                                radius: 4
                                color: Theme.statusGreen

                                Text {
                                    id: fsText
                                    anchors.centerIn: parent
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

            // Divider
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.divider
                Layout.topMargin: 2
                Layout.bottomMargin: 2
            }

            // ── Menu Action Items ──────────────────────────────────────

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

            // 4. Center Window
            ContextMenuItem {
                iconText: "󰆤"
                labelText: "Center on Screen"
                hintText: ""
                onTriggered: {
                    if (!root.isFloating) {
                        Hyprland.dispatch("hl.dsp.window.float({ window = 'address:0x" + root.cleanAddress + "' })");
                    }
                    Hyprland.dispatch("hl.dsp.window.center({ window = 'address:0x" + root.cleanAddress + "' })");
                    root.close();
                }
            }

            // 5. Focus Window
            ContextMenuItem {
                iconText: "󰍉"
                labelText: "Focus Window"
                hintText: ""
                onTriggered: {
                    Hyprland.dispatch("hl.dsp.focus({ window = 'address:0x" + root.cleanAddress + "' })");
                    root.close();
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
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: itemRoot.labelText
                font.family: Theme.font
                font.pixelSize: 11
                font.bold: itemMouse.containsMouse || itemRoot.isActive
                color: itemRoot.isDanger ? Theme.statusRed : Theme.textPrimary
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                text: itemRoot.hintText
                font.family: Theme.font
                font.pixelSize: 9
                color: Qt.rgba(1, 1, 1, 0.35)
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
