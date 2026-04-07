import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../elements"

Rectangle {
    id: wallpaperPanel
    
    // Fit 4 columns (210 cellWidth * 4 = 840 + 40 margins = 880)
    property real targetWidth: 520
    // Fit 3 rows + padding
    property real targetHeight: 800
    property bool expanded: false
    
    property real cornerSize: targetWidth / 8

    color: "transparent"
    
    // Animate width for side sliding!
    implicitWidth: expanded ? targetWidth : 0
    Behavior on implicitWidth { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic } }
    
    implicitHeight: targetHeight

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        InverseRadius {
            cornerPosition: "bottomRight"
            implicitWidth: wallpaperPanel.cornerSize
            implicitHeight: wallpaperPanel.cornerSize
            color: Theme.dark.base
            Layout.alignment: Qt.AlignRight
            expandingH: wallpaperPanel.expanded
        }

        Rectangle {
            id: containerRect

            width: wallpaperPanel.implicitWidth
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.dark.base
            
            topLeftRadius: Theme.moduleEdgeRadius
            bottomLeftRadius: Theme.moduleEdgeRadius
            topRightRadius: 0
            bottomRightRadius: 0
            
            clip: true
            
            // Hide content when collapsed to prevent rendering overlap
            visible: wallpaperPanel.implicitWidth > 10
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
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
                    cellWidth: 240
                    cellHeight: 210
                    clip: true
                    
                    model: FolderListModel {
                        folder: "file://" + Quickshell.env("HOME") + "/Pictures/wallpapers"
                        nameFilters: ["*.png", "*.jpg", "*.jpeg"]
                    }
                    
                    delegate: ModuleButton {
                        implicitWidth: 220
                        implicitHeight: 190
                        variant: "light"
                        radius: Theme.moduleEdgeRadius
                        
                        Image {
                            id: preview
                            anchors.top: parent.top
                            anchors.topMargin: 20
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
                        }
                        
                        label: fileName
                        topMargin: 130
                        
                        onClicked: {
                            var rawPath = String(fileUrl).replace("file://", "");
                            applyProc.targetFile = rawPath;
                            applyProc.running = true;
                        }
                    }
                }
                
                ModuleButton {
                    label: "Close"
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wallpaperPanel.expanded = false
                    radius: Theme.moduleEdgeRadius
                    Layout.fillWidth: true
                }
            }
        }

        InverseRadius {
            cornerPosition: "topRight"
            implicitWidth: wallpaperPanel.cornerSize
            implicitHeight: wallpaperPanel.cornerSize
            color: Theme.dark.base
            Layout.alignment: Qt.AlignRight
            expandingH: wallpaperPanel.expanded
        }
    }

    Process {
        id: applyProc
        property string targetFile: ""
        command: ["bash", "-c", 
            "MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'); " +
            "CONF_DIR=\"$HOME/.config/hypr\"; " +
            "LINK_NAME=\"$CONF_DIR/temps/wallpaper_$MONITOR\"; " +
            "ln -sf \"" + targetFile + "\" \"$LINK_NAME\"; " +
            "pkill -x hyprpaper || true; " + 
            "setsid -f hyprpaper >/dev/null 2>&1"
        ]
        onRunningChanged: {
            if (!running) {
                wallpaperPanel.expanded = false;
            }
        }
    }
}
