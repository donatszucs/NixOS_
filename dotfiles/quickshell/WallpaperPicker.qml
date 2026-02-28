import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Rectangle {
    id: wallpaperPanel
    
    // Fit 4 columns (210 cellWidth * 4 = 840 + 40 margins = 880)
    property real targetWidth: 880
    // Fit 3 rows + padding
    property real targetHeight: 650
    property bool expanded: false
    
    color: "transparent"
    
    // Animate width for side sliding!
    implicitWidth: expanded ? targetWidth : 0
    Behavior on implicitWidth { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic } }
    
    implicitHeight: targetHeight
    
    Rectangle {
        id: containerRect
        // Anchor to the right, so it slides out
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: wallpaperPanel.implicitWidth
        
        color: Theme.dark.base
        opacity: Theme.moduleOpacity
        
        topLeftRadius: Theme.moduleEdgeRadius
        bottomLeftRadius: Theme.moduleEdgeRadius
        topRightRadius: 0
        bottomRightRadius: 0
        
        clip: true
        
        // Hide content when collapsed to prevent rendering overlap
        visible: wallpaperPanel.implicitWidth > 10
        
        ColumnLayout {
            // Give it a fixed size based on target boundaries so the inner items don't jitter while animating
            width: wallpaperPanel.targetWidth - 40 // Take into account margins
            height: wallpaperPanel.targetHeight - 40
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 20
            spacing: 15
            
            Text {
                text: "󰸉 Select Wallpaper"
                font.family: Theme.font
                font.pixelSize: 24
                color: Theme.textPrimary
                Layout.alignment: Qt.AlignHCenter
            }
            
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                cellWidth: 210
                cellHeight: 180
                clip: true
                
                model: FolderListModel {
                    folder: "file://" + Quickshell.env("HOME") + "/Pictures/wallpapers"
                    nameFilters: ["*.png", "*.jpg", "*.jpeg"]
                }
                
                delegate: Rectangle {
                    width: 200
                    height: 170
                    color: itemMouseArea.containsMouse ? Theme.dark.hover : "transparent"
                    radius: Theme.moduleEdgeRadius
                    
                    Image {
                        id: preview
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 180
                        height: 110
                        
                        // PERFORMANCE FIX: Decode images at thumbnail size to save VRAM 
                        sourceSize.width: 180
                        sourceSize.height: 110
                        asynchronous: true // Load off the main thread to prevent UI stutter
                        
                        source: fileUrl
                        fillMode: Image.PreserveAspectCrop
                        clip: true
                        
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: Theme.dark.border
                            border.width: 1
                            radius: 4
                        }
                    }
                    
                    Text {
                        anchors.top: preview.bottom
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 20
                        text: fileName
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    MouseArea {
                        id: itemMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            var rawPath = String(fileUrl).replace("file://", "");
                            applyProc.targetFile = rawPath;
                            applyProc.running = true;
                        }
                    }
                }
            }
            
            ModuleButton {
                label: "Close"
                Layout.alignment: Qt.AlignHCenter
                onClicked: wallpaperPanel.expanded = false
                radius: Theme.moduleEdgeRadius
            }
        }
    }
    
    // Inverse radiuses attached directly to this component to automatically track it
    InverseRadius {
        cornerPosition: "bottomRight"
        color: Theme.dark.base
        opacity: Theme.moduleOpacity
        anchors {
            bottom: containerRect.top
            right: containerRect.right
        }
        visible: containerRect.visible
    }

    InverseRadius {
        cornerPosition: "topRight"
        color: Theme.dark.base
        opacity: Theme.moduleOpacity
        anchors {
            top: containerRect.bottom
            right: containerRect.right
        }
        visible: containerRect.visible
    }

    Process {
        id: applyProc
        property string targetFile: ""
        command: ["bash", "-c", 
            "MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'); " +
            "CONF_DIR=\"$HOME/.config/hypr\"; " +
            "LINK_NAME=\"$CONF_DIR/temps/wallpaper_$MONITOR\"; " +
            "ln -sf \"" + targetFile + "\" \"$LINK_NAME\"; " +
            "pkill hyprpaper; hyprpaper & disown"
        ]
        onRunningChanged: {
            if (!running) {
                wallpaperPanel.expanded = false;
            }
        }
    }
}
