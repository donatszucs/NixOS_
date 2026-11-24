import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../elements"

Rectangle {
    id: clipboardPanel
    
    property real targetWidth: 400
    property real targetHeight: 810
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
    Behavior on implicitWidth { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutQuint } }
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
            } else if (!SharedState.vramSavingMode) {
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

            topRightRadius: Theme.expandedModuleRadius - Theme.pillExpandedMargin
            bottomRightRadius: Theme.expandedModuleRadius - Theme.pillExpandedMargin
            topLeftRadius: 0
            bottomLeftRadius: 0

            clip: true

            BaseCard {
                id: mainCard
                anchors.fill: parent
                anchors.margins: Theme.cardMargin
                hasHeader: true
                headerIcon: ""
                headerTitle: "Clipboard"

                headerControls: [
                    Rectangle {
                        implicitHeight: 20
                        implicitWidth: clipCountText.implicitWidth + 10
                        radius: 10
                        color: Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.2)
                        visible: clipboardModel.count > 0
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: clipCountText
                            anchors.centerIn: parent
                            text: clipboardModel.count + (clipboardModel.count === 1 ? " item" : " items")
                            color: Theme.statusBlue
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize * 0.7
                            font.bold: true
                        }
                    },

                    HeaderButton {
                        id: clearAllBtn
                        visible: clipboardModel.count > 0
                        property bool confirming: false
                        hasBorder: true
                        icon: confirming ? "Confirm?" : "󰆴 Clear"
                        iconSize: Math.round(Theme.fontSize * 0.78)
                        iconColor: confirming ? Theme.statusRed : Theme.textPrimary
                        normalBorderColor: confirming
                            ? Qt.rgba(Theme.statusRed.r, Theme.statusRed.g, Theme.statusRed.b, 0.65)
                            : Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.35)
                        hoverBorderColor: confirming
                            ? Theme.statusRed
                            : Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.75)
                        normalBgColor: confirming
                            ? Qt.rgba(Theme.statusRed.r, Theme.statusRed.g, Theme.statusRed.b, 0.18)
                            : "transparent"
                        hoverBgColor: confirming
                            ? Qt.rgba(Theme.statusRed.r, Theme.statusRed.g, Theme.statusRed.b, 0.28)
                            : Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.08)

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
                    },

                    HeaderButton {
                        icon: "󰅖"
                        iconSize: Theme.fontSize + 1
                        onClicked: clipboardPanel.closeMenu()
                    }
                ]

                Item {
                    id: listMask
                    anchors.fill: listContainer
                    visible: false
                    layer.enabled: true
                    layer.smooth: true

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cardItemRadius
                        color: "black"
                    }
                }

                Item {
                    id: listContainer
                    anchors {
                        top: mainCard.headerBar.bottom
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                        margins: Theme.cardPadding
                    }
                    clip: true
                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: listMask
                    }

                    ListView {
                        id: list
                        anchors.fill: parent
                        clip: true
                        spacing: 5

                        model: clipboardModel
                        delegate: ListButton {
                            id: delegateItem
                            width: list.width
                            implicitWidth: list.width

                            readonly property bool isSelected: clipboardPanel.selectedIndex === index
                            property string currentClipId: typeof clipId !== "undefined" ? clipId : ""
                            property bool isImage: clipContent.startsWith("[[ binary data") && (clipContent.includes("png") || clipContent.includes("jpg") || clipContent.includes("jpeg") || clipContent.includes("webp"))
                            property string imagePath: currentClipId !== "" ? "/tmp/qs-cliphist/img-" + currentClipId + ".png" : ""

                            implicitHeight: isImage ? 136 : Theme.listHeight
                            height: implicitHeight
                            highlighted: isSelected
                            hoverEnabled: false
                            rightPadding: 8

                            Process {
                                id: decodeImage
                                command: ["bash", "-c", "if [ ! -f \"$2\" ]; then mkdir -p \"$(dirname \"$2\")\" && printf '%s\\n' \"$1\" | cliphist decode > \"$2\"; fi", "--", clipLine, delegateItem.imagePath]
                                onExited: {
                                    if (delegateItem.isImage) {
                                        img.source = "file://" + delegateItem.imagePath;
                                    }
                                }
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

                            onEntered: clipboardPanel.selectedIndex = index
                            onClicked: {
                                applyCliphist.targetLine = clipLine;
                                applyCliphistTimer.start();
                            }

                            iconContent: ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    text: delegateItem.isImage ? "󰋩" : "󰅌"
                                    color: delegateItem.iconColor
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize + 2
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }

                                Text {
                                    text: "#" + (index + 1)
                                    color: delegateItem.iconColor
                                    opacity: delegateItem.lit ? 0.75 : 0.55
                                    font.family: Theme.font
                                    font.pixelSize: Math.round(Theme.fontSize * 0.68)
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }
                            }

                            content: [
                                // Text entry content
                                ColumnLayout {
                                    visible: !delegateItem.isImage
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: clipContent
                                        color: delegateItem.primaryTextColor
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize
                                        font.bold: true
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: clipContent.length + (clipContent.length === 1 ? " character" : " characters")
                                        color: delegateItem.primaryTextColor
                                        opacity: delegateItem.lit ? 0.72 : 0.55
                                        font.family: Theme.font
                                        font.pixelSize: Math.round(Theme.fontSize * 0.75)
                                        elide: Text.ElideRight
                                    }
                                },

                                // Image entry content
                                Item {
                                    id: imgWrapper
                                    visible: delegateItem.isImage
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.topMargin: 6
                                    Layout.bottomMargin: 6

                                    Image {
                                        id: img
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        smooth: true
                                        visible: false
                                    }

                                    Item {
                                        id: imgMask
                                        anchors.fill: parent
                                        visible: false
                                        layer.enabled: true
                                        layer.smooth: true

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.innerElementRadius
                                            color: "black"
                                        }
                                    }

                                    MultiEffect {
                                        anchors.fill: parent
                                        source: img
                                        maskEnabled: true
                                        maskSource: imgMask
                                        visible: img.status === Image.Ready
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.innerElementRadius
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.15)
                                    }
                                }
                            ]

                            trailing: ListButton {
                                id: deleteItemBtn
                                iconOnly: true
                                icon: "󰅖"
                                iconSize: 12
                                variant: "red"
                                implicitWidth: 28
                                implicitHeight: 28
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: Theme.innerElementRadius + 3
                                opacity: (delegateItem.lit || deleteItemBtn.hovered) ? 1.0 : 0.45
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                onClicked: clipboardPanel.deleteEntry(index, clipLine, currentClipId)
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
                            font.bold: true
                            color: Theme.textPrimary
                            opacity: 0.65
                            Layout.alignment: Qt.AlignHCenter
                        }
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
