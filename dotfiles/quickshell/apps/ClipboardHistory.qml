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
    property real targetHeight: 650
    property bool expanded: false
    property int selectedIndex: -1
    focus: expanded
    property string screenName: ""
    
    color: "transparent"
    
    // Animate width for side sliding!
    implicitWidth: expanded ? targetWidth : 0
    Behavior on implicitWidth { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic } }
    implicitHeight: targetHeight
    
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

            clipboardPanel.expanded = false;
            clipboardPanel.selectedIndex = -1;
            applyCliphist.running = true;
        }
    }
    Process {
        id: applyCliphist
        property string targetLine: ""
        command: ["bash", "-c", "printf '%s\\n' \"$0\" | cliphist decode | wl-copy && sleep 0.1 && wtype -M ctrl -k v -m ctrl", targetLine]
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
                    clipboardPanel.expanded = false;
                } else {
                    clipboardModel.clear();
                    fetchCliphist.running = true;
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
            clipboardPanel.expanded = false;
            event.accepted = true;
        }
    }

    Rectangle {
        id: containerRect
        // Anchor to the left, so it slides out
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: clipboardPanel.implicitWidth
        
        color: Theme.dark.base
        opacity: Theme.moduleOpacity
        
        topRightRadius: Theme.moduleEdgeRadius
        bottomRightRadius: Theme.moduleEdgeRadius
        topLeftRadius: 0
        bottomLeftRadius: 0
        
        clip: true
        
        // Hide content when collapsed to prevent rendering overlap
        visible: clipboardPanel.implicitWidth > 10
        
        ColumnLayout {
            width: clipboardPanel.targetWidth - 40 // Take into account margins
            height: clipboardPanel.targetHeight - 40
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 20
            spacing: 15
            
            Text {
                text: " Clipboard History"
                font.family: Theme.font
                font.pixelSize: 24
                color: Theme.textPrimary
                Layout.alignment: Qt.AlignHCenter
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
                    implicitHeight: 50
                    color: index === clipboardPanel.selectedIndex ? Theme.dark.hover : Theme.dark.base
                    radius: Theme.moduleEdgeRadius
                    
                    label: clipContent.length > 38? clipContent.substring(0, 38) + "..." : clipContent
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
                onClicked: clipboardPanel.expanded = false
                radius: Theme.moduleEdgeRadius
            }
        }
    }
    
    // Inverse radiuses attached directly to this component to automatically track it
    InverseRadius {
        cornerPosition: "bottomLeft"
        color: Theme.dark.base
        opacity: Theme.moduleOpacity
        anchors {
            bottom: containerRect.top
            left: containerRect.left
        }
        visible: containerRect.visible
    }

    InverseRadius {
        cornerPosition: "topLeft"
        color: Theme.dark.base
        opacity: Theme.moduleOpacity
        anchors {
            top: containerRect.bottom
            left: containerRect.left
        }
        visible: containerRect.visible
    }
}
