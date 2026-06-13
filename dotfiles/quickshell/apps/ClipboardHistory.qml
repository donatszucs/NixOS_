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
                    clipboardModel.append({ "clipLine": line, "clipContent": content });
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
        command: ["bash", "-c", "printf '%s\\n' \"$0\" | cliphist decode | wl-copy && sleep 0.5 && wtype -M ctrl -k v -m ctrl", targetLine]
    }

    // ── Public API ────────────────────────────────────────────────────────
    function openMenu() {
        clipboardModel.clear();
        fetchCliphist.running = true;
    }

    function closeMenu() {
        clipboardPanel.expanded = false;
        clipboardPanel.selectedIndex = -1;
    }

    // IPC Trigger for Super+V
    Process {
        id: clipboardListener
        command: ["bash", "-c",
            "rm -f /tmp/qs-cliphist-" + clipboardPanel.screenName + "; " +
            "mkfifo /tmp/qs-cliphist-" + clipboardPanel.screenName + "; " +
            "while true; do read -r _ < /tmp/qs-cliphist-" + clipboardPanel.screenName + " && echo open; done"
        ]
        running: true
        stdout: SplitParser {
            onRead: _ => {
                if (clipboardPanel.expanded) {
                    closeMenu();
                } else {
                    openMenu();
                }
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
                
                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 5
                    
                    model: clipboardModel
                    delegate: ModuleButton {
                        implicitWidth: list.width
                        variant: clipboardPanel.selectedIndex === index ? "light" : "neutral"
                        implicitHeight: Theme.listHeight
                        radius: Theme.moduleEdgeRadius
                        
                        label: clipContent.length > 38? clipContent.substring(0, 35) + "..." : clipContent
                        textAlign: "left"
                        leftMargin: 20

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: clipboardPanel.selectedIndex = index;
                            onClicked: {
                                applyCliphist.targetLine = clipLine;
                                applyCliphistTimer.start();
                            }
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
