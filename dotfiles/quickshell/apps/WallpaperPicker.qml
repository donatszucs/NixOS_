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
                
                Item {
                    id: carouselContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    FolderListModel {
                        id: folderModel
                        folder: "file://" + Quickshell.env("HOME") + "/Pictures/wallpapers"
                        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
                        showDirs: false
                        onCountChanged: {
                            if (count > 0 && !grid.initialized) {
                                grid.initialized = true;
                                var centerIdx = Math.floor(grid.loopMultiplier / 2) * count;
                                grid.currentIndex = centerIdx;
                                grid.positionViewAtIndex(centerIdx, ListView.Center);
                            }
                        }
                    }

                    ListView {
                        id: grid
                        anchors.fill: parent
                        clip: true
                        focus: true
                        orientation: ListView.Vertical
                        spacing: 16
                        cacheBuffer: 800

                        property int loopMultiplier: 400
                        property bool initialized: false
                        model: folderModel.count > 0 ? folderModel.count * loopMultiplier : 0

                        onCurrentIndexChanged: {
                            if (folderModel.count > 0) {
                                var half = Math.floor(loopMultiplier / 2) * folderModel.count;
                                if (currentIndex <= folderModel.count * 2) {
                                    currentIndex += half;
                                    positionViewAtIndex(currentIndex, ListView.Center);
                                } else if (currentIndex >= (loopMultiplier - 2) * folderModel.count) {
                                    currentIndex -= half;
                                    positionViewAtIndex(currentIndex, ListView.Center);
                                }
                            }
                        }

                        Connections {
                            target: wallpaperPanel
                            function onExpandedChanged() {
                                if (wallpaperPanel.expanded) {
                                    grid.forceActiveFocus();
                                    if (folderModel.count > 0) {
                                        grid.positionViewAtIndex(grid.currentIndex, ListView.Center);
                                    }
                                } else {
                                    if (folderModel.count > 0) {
                                        var real = grid.currentIndex % folderModel.count;
                                        var centerIdx = Math.floor(grid.loopMultiplier / 2) * folderModel.count + real;
                                        grid.currentIndex = centerIdx;
                                        grid.positionViewAtIndex(centerIdx, ListView.Center);
                                    }
                                }
                            }
                        }

                        property real slotHeight: 230

                        preferredHighlightBegin: height / 2 - slotHeight / 2
                        preferredHighlightEnd: height / 2 + slotHeight / 2
                        highlightRangeMode: ListView.StrictlyEnforceRange
                        snapMode: ListView.SnapToItem
                        highlightMoveDuration: Theme.verticalDuration

                        Keys.onEscapePressed: wallpaperPanel.expanded = false
                        Keys.onReturnPressed: {
                            if (currentItem && typeof currentItem.applyWallpaper === "function") {
                                currentItem.applyWallpaper();
                            }
                        }
                        Keys.onUpPressed: event => {
                            grid.decrementCurrentIndex();
                            event.accepted = true;
                        }
                        Keys.onDownPressed: event => {
                            grid.incrementCurrentIndex();
                            event.accepted = true;
                        }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_PageUp) {
                                grid.currentIndex -= 3;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageDown) {
                                grid.currentIndex += 3;
                                event.accepted = true;
                            }
                        }

                        delegate: Item {
                            id: delegateRoot
                            width: grid.width
                            height: grid.slotHeight

                            readonly property int realIndex: folderModel.count > 0 ? (((index % folderModel.count) + folderModel.count) % folderModel.count) : 0
                            readonly property var fileUrl: folderModel.get(realIndex, "fileUrl") || ""
                            readonly property string fileName: folderModel.get(realIndex, "fileName") || ""

                            property real itemCenter: y + height / 2
                            property real viewCenter: grid.contentY + grid.height / 2
                            property real centerDist: itemCenter - viewCenter
                            property real absCenterDist: Math.abs(centerDist)
                            property real outOfFocusDist: Math.max(0, absCenterDist - 25)
                            property real absDist: Math.min(1.0, outOfFocusDist / (height + grid.spacing))
                            property real effectiveNormDist: (centerDist < 0 ? -1 : 1) * absDist
                            readonly property bool isCurrent: index === grid.currentIndex

                            z: 100 - Math.round(absDist * 50)

                            function applyWallpaper() {
                                var rawPath = String(delegateRoot.fileUrl).replace("file://", "");
                                applyProc.targetFile = rawPath;
                                applyProc.running = true;
                            }

                            Item {
                                id: delegateWrapper
                                width: Math.min(grid.width - 24, 430)
                                height: 215
                                anchors.centerIn: parent

                                scale: 1.0 - 0.16 * delegateRoot.absDist
                                    + Math.max(0, 1.0 - delegateRoot.absCenterDist / 70) * 0.04

                                transform: Translate {
                                    y: -Math.pow(delegateRoot.effectiveNormDist, 3) * 52
                                }

                                Item {
                                    id: cardContainer
                                    anchors.fill: parent

                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.effect: MultiEffect {
                                        brightness: -delegateRoot.absDist * 0.35 + (mouseArea.containsMouse ? 0.04 : 0.0)
                                        contrast: -delegateRoot.absDist * 0.4
                                        shadowEnabled: true
                                        shadowColor: delegateRoot.isCurrent ? Qt.rgba(0, 0, 0, 0.75) : Qt.rgba(0, 0, 0, 0.35)
                                        shadowBlur: delegateRoot.isCurrent ? 0.9 : 0.4
                                        shadowVerticalOffset: delegateRoot.isCurrent ? 5 : 2
                                        shadowHorizontalOffset: 0
                                    }

                                    Image {
                                        id: preview
                                        anchors.fill: parent
                                        sourceSize.width: 500
                                        asynchronous: true
                                        source: delegateRoot.fileUrl
                                        fillMode: Image.PreserveAspectCrop
                                        visible: false
                                    }

                                    MultiEffect {
                                        id: previewMasked
                                        source: preview
                                        anchors.fill: parent
                                        maskEnabled: true
                                        maskSource: maskItem
                                        opacity: 1.0 - 0.35 * delegateRoot.absDist
                                    }

                                    Item {
                                        id: maskItem
                                        anchors.fill: parent
                                        visible: false
                                        layer.enabled: true
                                        layer.smooth: true

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.moduleEdgeRadius / 2
                                            color: "black"
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        radius: Theme.moduleEdgeRadius / 2
                                        border.width: delegateRoot.isCurrent ? 3 : 1.5
                                        border.color: delegateRoot.isCurrent
                                            ? (mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.75))
                                            : (mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.4) : Qt.rgba(1, 1, 1, 0.15))

                                        Behavior on border.color { ColorAnimation { duration: Theme.horizontalDuration } }
                                        Behavior on border.width { NumberAnimation { duration: Theme.horizontalDuration } }
                                    }

                                    Item {
                                        id: labelPill
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 10
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        height: 28
                                        width: Math.min(parent.width - 32, fileNameText.implicitWidth + 24)
                                        opacity: Math.max(0.0, 1.0 - delegateRoot.absCenterDist / 50)
                                        visible: opacity > 0

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: height / 2
                                            color: Qt.rgba(0, 0, 0, 0.65)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.2)
                                        }

                                        Text {
                                            id: fileNameText
                                            anchors.centerIn: parent
                                            width: parent.width - 20
                                            text: delegateRoot.fileName
                                            color: Theme.palettePaper
                                            font.family: Theme.font
                                            font.pixelSize: 12
                                            font.bold: true
                                            elide: Text.ElideMiddle
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    MouseArea {
                                        id: mouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (grid.currentIndex !== index) {
                                                grid.currentIndex = index;
                                            } else {
                                                delegateRoot.applyWallpaper();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: function(wheel) {
                            if (wheel.angleDelta.y > 0) {
                                grid.decrementCurrentIndex();
                            } else if (wheel.angleDelta.y < 0) {
                                grid.incrementCurrentIndex();
                            }
                        }
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
        command: [
            "bash",
            "-c",
            "MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'); " +
            "CONF_DIR=\"$HOME/.config/hypr\"; " +
            "LINK_NAME=\"$CONF_DIR/temps/wallpaper_$MONITOR\"; " +
            "mkdir -p \"$CONF_DIR/temps\"; " +
            "ln -sf \"$1\" \"$LINK_NAME\"; " +
            "hyprctl hyprpaper preload \"$1\"; " +
            "hyprctl hyprpaper wallpaper \"$MONITOR,$1\"; " +
            "hyprctl hyprpaper unload all",
            "--",
            targetFile
        ]
        onRunningChanged: {
            if (!running) {
                wallpaperPanel.expanded = false;
            }
        }
    }
}
