import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick.Effects

import "../elements"

Rectangle {
    id: wallpaperPanel
    
    property real targetWidth: 500
    property real targetHeight: 900
    property bool expanded: false

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
            sizeH: targetHeight / 4
            sizeV: targetWidth / 8
            color: containerRect.color
            Layout.alignment: Qt.AlignRight
            expandingH: wallpaperPanel.expanded
            expandingV: wallpaperPanel.expanded
        }

        Rectangle {
            id: containerRect

            width: wallpaperPanel.implicitWidth
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.rgba(Theme.dark.base.r, Theme.dark.base.g, Theme.dark.base.b, Theme.moduleOpacity)
            
            topLeftRadius: Theme.moduleEdgeRadius * 2
            bottomLeftRadius: Theme.moduleEdgeRadius * 2
            topRightRadius: 0
            bottomRightRadius: 0
            
            clip: true
            
            // Hide content when collapsed to prevent rendering overlap
            visible: wallpaperPanel.implicitWidth > 10
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20
                
                ModuleButton {
                    label: "󰸉 Select Wallpaper"
                    color: "transparent"

                    textFont: 22
                    Layout.fillWidth: true
                }
                
                ListView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 10
                    focus: true

                    Connections {
                        target: wallpaperPanel
                        function onExpandedChanged() {
                            if (wallpaperPanel.expanded) {
                                grid.forceActiveFocus()
                            }
                        }
                    }

                    Keys.onEscapePressed: wallpaperPanel.expanded = false
                    Keys.onReturnPressed: {
                        if (currentItem) {
                            currentItem.applyWallpaper()
                        }
                    }
                    
                    ScrollBar.vertical: ScrollBar {
                        active: true 
                        rightPadding: 5
                    }

                    model: FolderListModel {
                        folder: "file://" + Quickshell.env("HOME") + "/Pictures/wallpapers"
                        nameFilters: ["*.png", "*.jpg", "*.jpeg"]
                    }
                    
                    delegate: ModuleButton {
                        id: previewButton
                        implicitWidth: wallpaperPanel.targetWidth - 40
                        implicitHeight: previewButton.ListView.isCurrentItem ? 250 : 150
                        variant: previewButton.ListView.isCurrentItem ? "light" : "dark"
                        
                        onHoveredChanged: {
                            if (hovered) {
                                grid.currentIndex = index
                            }
                        }
                        
                        function applyWallpaper() {
                            var rawPath = String(fileUrl).replace("file://", "");
                            applyProc.targetFile = rawPath;
                            applyProc.running = true;
                        }
                        
                        Behavior on implicitHeight { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic } }

                        radius: Theme.moduleEdgeRadius / 2
                        cursorShape: Qt.PointingHandCursor

                        Image {
                            id: preview
                            anchors.fill: parent
                            
                            sourceSize.width: width
                            asynchronous: true
                            
                            source: fileUrl
                            fillMode: Image.PreserveAspectCrop
                            visible: false // Hidden, as the MultiEffect handles the drawing
                        }

                        MultiEffect {
                            // Point this to the ID of the Image component, NOT the fileUrl
                            source: preview 
                            anchors.fill: previewButton
                            maskEnabled: true
                            maskSource: maskItem
                            opacity: previewButton.ListView.isCurrentItem ? 1.0 : 0.6
                            Behavior on opacity { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic } }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 3
                            border.color: previewButton.ListView.isCurrentItem ? Qt.rgba(1, 1, 1, 0.8) : Qt.rgba(1, 1, 1, 0.2)
                            radius: Theme.moduleEdgeRadius / 2
                        }

                        Item {
                            id: maskItem
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true
                            
                            Rectangle {
                                anchors.fill: parent
                                // Matched perfectly to the button's radius
                                radius: Theme.moduleEdgeRadius / 2 
                                color: "black" 
                            }
                        }

                        onClicked: applyWallpaper()
                    }
                }
                
                ModuleButton {
                    label: "Close"
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wallpaperPanel.expanded = false
                    radius: Theme.moduleEdgeRadius
                    Layout.alignment: Qt.AlignHCenter
                    
                    
                    variant: "neutral"
                    border.width: 2

                    implicitWidth: 100
                }
            }
        }

        InverseRadius {
            cornerPosition: "topRight"
            sizeH: targetHeight / 4
            sizeV: targetWidth / 8
            color: containerRect.color
            Layout.alignment: Qt.AlignRight
            expandingH: wallpaperPanel.expanded
            expandingV: wallpaperPanel.expanded
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
