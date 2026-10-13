import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../elements"

Rectangle {
    id: clipboardPanel
    
    property real targetWidth: 400
    property real targetHeight: 800
    property bool expanded: false
    property int selectedIndex: -1
    focus: expanded
    property string screenName: ""

    color: "transparent"
    clip: true

    onExpandedChanged: {
        if (!expanded && typeof clearAllBtn !== "undefined" && clearAllBtn) {
            clearAllBtn.confirming = false;
        }
    }

    // Animate width for side sliding!
    implicitWidth: expanded ? targetWidth : 0
    Behavior on implicitWidth { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic } }
    implicitHeight: targetHeight + targetHeight / 8
    
    // List model for the clipboard history
    ListModel {
        id: clipboardModel
    }

    // Process to fetch cliphist list
    Process {
        id: fetchCliphist
        command: ["bash", "-c", "cliphist list"]
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() !== "") {
                    // line format: "ID\tDATA" or "ID  DATA"
                    var tabIndex = line.indexOf("\t");
                    if (tabIndex === -1) tabIndex = line.indexOf("  ");
                    var content = line.substring(tabIndex + 1).trim();
                    var idStr = line.substring(0, tabIndex).trim();
                    clipboardModel.append({ "clipLine": line, "clipContent": content, "clipId": idStr });
                }
            }
        }
        onExited: {
            clipboardPanel.expanded = true;
            clipboardPanel.selectedIndex = clipboardModel.count > 0 ? 0 : -1;
            list.currentIndex = clipboardPanel.selectedIndex;
        }
    }

    // Process to decode and copy
    Timer {
        id: applyCliphistTimer
        interval: Theme.horizontalDuration * 1.5
        repeat: false
        onTriggered: {
            clipboardPanel.closeMenu();
            applyCliphist.running = true;
        }
    }
    Process {
        id: applyCliphist
        property string targetLine: ""
        command: ["bash", "-c", "printf '%s\\n' \"$0\" | cliphist decode | wl-copy && sleep 0.1 && wtype -M ctrl -k v -m ctrl", targetLine]
    }

    // ── Public API ────────────────────────────────────────────────────────
    function openMenu() {
        clipboardModel.clear();
        fetchCliphist.running = true;
    }

    function closeMenu() {
        clipboardPanel.expanded = false;
        clipboardPanel.selectedIndex = -1;
        if (typeof clearAllBtn !== "undefined" && clearAllBtn) {
            clearAllBtn.confirming = false;
        }
    }

    function deleteEntry(index, line, idStr) {
        if (index >= 0 && index < clipboardModel.count) {
            clipboardModel.remove(index);
            if (clipboardModel.count === 0) {
                clipboardPanel.selectedIndex = -1;
            } else if (clipboardPanel.selectedIndex >= clipboardModel.count) {
                clipboardPanel.selectedIndex = clipboardModel.count - 1;
            }
            list.currentIndex = clipboardPanel.selectedIndex;
        }
        Quickshell.execDetached([
            "bash", "-c",
            "printf '%s\\n' \"$0\" | cliphist delete; if [ -n \"$1\" ]; then rm -f \"/tmp/qs-cliphist/img-$1.png\"; fi",
            line,
            idStr ? idStr : ""
        ]);
    }

    function wipeAll() {
        clipboardModel.clear();
        clipboardPanel.selectedIndex = -1;
        list.currentIndex = -1;
        Quickshell.execDetached([
            "bash", "-c",
            "cliphist wipe && rm -rf /tmp/qs-cliphist/*"
        ]);
    }

    // IPC Trigger for Super+V
    IpcHandler {
        target: "cliphist-" + clipboardPanel.screenName
        function toggle(): void {
            if (clipboardPanel.expanded) {
                clipboardPanel.closeMenu();
            } else {
                clipboardPanel.openMenu();
            }
        }
    }

    Keys.onPressed: event => {
        if (!expanded) return;
        if (clipboardModel.count === 0) return;
        if (event.key === Qt.Key_Down) {
            if (clipboardPanel.selectedIndex < clipboardModel.count - 1) clipboardPanel.selectedIndex++;
            else clipboardPanel.selectedIndex = 0;
            list.currentIndex = clipboardPanel.selectedIndex;
            list.positionViewAtIndex(clipboardPanel.selectedIndex, ListView.Visible);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            if (clipboardPanel.selectedIndex > 0) clipboardPanel.selectedIndex--;
            else clipboardPanel.selectedIndex = clipboardModel.count - 1;
            list.currentIndex = clipboardPanel.selectedIndex;
            list.positionViewAtIndex(clipboardPanel.selectedIndex, ListView.Visible);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            var item = clipboardModel.get(clipboardPanel.selectedIndex);
            if (item) {
                applyCliphist.targetLine = item.clipLine;
                applyCliphistTimer.start();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete) {
            if (clipboardPanel.selectedIndex >= 0 && clipboardPanel.selectedIndex < clipboardModel.count) {
                var itemToDelete = clipboardModel.get(clipboardPanel.selectedIndex);
                if (itemToDelete) {
                    clipboardPanel.deleteEntry(clipboardPanel.selectedIndex, itemToDelete.clipLine, itemToDelete.clipId);
                }
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            clipboardPanel.closeMenu();
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        InverseRadius {
            cornerPosition: "bottomLeft"
            sizeH: targetWidth / 4
            sizeV: targetWidth / 8
            color: containerRect.color
            Layout.alignment: Qt.AlignLeft
            expandingH: clipboardPanel.expanded
            expandingV: clipboardPanel.expanded
        }

        // ── Visual panel (slides out from the left) ───────────────────────────
        Rectangle {
            id: containerRect
            Layout.fillWidth: true
            Layout.fillHeight: true

            color: Qt.rgba(Theme.dark.base.r, Theme.dark.base.g, Theme.dark.base.b, Theme.moduleOpacity)

            topRightRadius: Theme.moduleEdgeRadius * 2
            bottomRightRadius: Theme.moduleEdgeRadius * 2
            topLeftRadius: 0
            bottomLeftRadius: 0

            clip: true

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 20
                }
                spacing: 20
            
                ModuleButton {
                    label: " Clipboard History"
                    color: "transparent"

                    textFont: 22
                    Layout.fillWidth: true
                }
                
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: list
                        anchors.fill: parent
                        clip: true
                        spacing: 5
                        
                        model: clipboardModel
                        delegate: ModuleButton {
                            id: delegateItem
                            implicitWidth: list.width
                            variant: clipboardPanel.selectedIndex === index ? "light" : "neutral"
                            
                            property string currentClipId: typeof clipId !== "undefined" ? clipId : ""
                            property bool isImage: clipContent.startsWith("[[ binary data") && (clipContent.includes("png") || clipContent.includes("jpg") || clipContent.includes("jpeg") || clipContent.includes("webp"))
                            property string imagePath: currentClipId !== "" ? "/tmp/qs-cliphist/img-" + currentClipId + ".png" : ""

                            implicitHeight: isImage ? Theme.listHeight * 4 : Theme.listHeight
                            radius: Theme.moduleEdgeRadius / 2
                            
                            label: isImage ? "" : (clipContent.length > 34 ? clipContent.substring(0, 31) + "..." : clipContent)
                            textAlign: "left"
                            leftMargin: 20
                            rightMargin: 46

                            border.width: 2

                            Process {
                                id: decodeImage
                                command: ["bash", "-c", "if [ ! -f \"$2\" ]; then mkdir -p \"$(dirname \"$2\")\" && printf '%s\\n' \"$1\" | cliphist decode > \"$2\"; fi", "--", clipLine, delegateItem.imagePath]
                                onExited: {
                                    if (delegateItem.isImage) {
                                        img.source = "file://" + delegateItem.imagePath;
                                    }
                                }
                            }

                            Image {
                                id: img
                                anchors.fill: parent
                                anchors.margins: 10
                                anchors.rightMargin: 46
                                fillMode: Image.PreserveAspectCrop
                                visible: delegateItem.isImage
                            }

                            onCurrentClipIdChanged: {
                                img.source = "";
                                if (delegateItem.isImage) {
                                    decodeImage.running = false;
                                    decodeImage.running = true;
                                }
                            }

                            Component.onCompleted: {
                                if (delegateItem.isImage) {
                                    decodeImage.running = true;
                                }
                            }

                            MouseArea {
                                id: itemMouseArea
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: deleteItemBtn.left
                                anchors.rightMargin: 4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: clipboardPanel.selectedIndex = index;
                                onClicked: {
                                    applyCliphist.targetLine = clipLine;
                                    applyCliphistTimer.start();
                                }
                            }

                            ModuleButton {
                                id: deleteItemBtn
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                z: 10
                                implicitWidth: 28
                                implicitHeight: 28
                                radius: Theme.moduleEdgeRadius / 2
                                variant: deleteItemBtn.hovered ? "red" : (clipboardPanel.selectedIndex === index ? "dark" : "neutral")
                                label: "󰅖"
                                textFont: 13
                                cursorShape: Qt.PointingHandCursor
                                opacity: (itemMouseArea.containsMouse || deleteItemBtn.hovered || clipboardPanel.selectedIndex === index) ? 1.0 : 0.35
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                onHoveredChanged: {
                                    if (hovered) clipboardPanel.selectedIndex = index;
                                }
                                onClicked: {
                                    clipboardPanel.deleteEntry(index, clipLine, currentClipId);
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: clipboardModel.count === 0 && !fetchCliphist.running
                        spacing: 8

                        Text {
                            text: ""
                            font.family: Theme.font
                            font.pixelSize: 32
                            color: Theme.textPrimary
                            opacity: 0.35
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "Clipboard history is empty"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            color: Theme.textPrimary
                            opacity: 0.5
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
                
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    ModuleButton {
                        id: clearAllBtn
                        visible: clipboardModel.count > 0
                        property bool confirming: false
                        label: confirming ? "Confirm Wipe?" : "󰅖 Clear All"
                        cursorShape: Qt.PointingHandCursor
                        radius: Theme.moduleEdgeRadius
                        variant: confirming ? "red" : "neutral"
                        border.width: 2
                        implicitWidth: confirming ? 140 : 120

                        Timer {
                            id: resetConfirmTimer
                            interval: 3000
                            repeat: false
                            onTriggered: clearAllBtn.confirming = false
                        }

                        onClicked: {
                            if (confirming) {
                                confirming = false;
                                resetConfirmTimer.stop();
                                clipboardPanel.wipeAll();
                            } else {
                                confirming = true;
                                resetConfirmTimer.restart();
                            }
                        }
                    }

                    ModuleButton {
                        label: "Close"
                        Layout.alignment: Qt.AlignHCenter
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clipboardPanel.closeMenu()
                        radius: Theme.moduleEdgeRadius

                        variant: "neutral"
                        border.width: 2

                        implicitWidth: 100
                    }
                }
            }
        }

        InverseRadius {
            cornerPosition: "topLeft"
            sizeH: targetWidth / 4
            sizeV: targetWidth / 8
            color: containerRect.color
            Layout.alignment: Qt.AlignLeft
            expandingH: clipboardPanel.expanded
            expandingV: clipboardPanel.expanded
        }
    }
}
