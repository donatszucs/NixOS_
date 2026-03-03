import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Rectangle {
    id: clipboardPanel
    
    property real targetWidth: 400
    property real targetHeight: 650
    property bool expanded: false
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
        }
    }

    // Process to decode and copy
    Process {
        id: applyCliphist
        property string targetLine: ""
        command: ["bash", "-c", "printf '%s\\n' \"$0\" | cliphist decode | wl-copy", targetLine]
        onExited: {
            clipboardPanel.expanded = false;
        }
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
                
                delegate: Rectangle {
                    width: list.width
                    height: 50
                    color: itemMouseArea.containsMouse ? Theme.dark.hover : Theme.dark.base
                    radius: Theme.moduleEdgeRadius
                    
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 15
                        anchors.rightMargin: 15
                        text: clipContent
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    MouseArea {
                        id: itemMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            applyCliphist.targetLine = clipLine;
                            applyCliphist.running = true;
                        }
                    }
                }
            }
            
            ModuleButton {
                label: "Close"
                Layout.alignment: Qt.AlignHCenter
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
