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
    
    property real targetWidth: 530
    property real targetHeight: 900
    property bool expanded: false

    color: "transparent"
    clip: true
    
    // Animate width for side sliding!
    implicitWidth: expanded ? targetWidth : 0
    Behavior on implicitWidth { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutQuint } }
    
    implicitHeight: targetHeight

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

            topLeftRadius: Theme.expandedModuleRadius - Theme.pillExpandedMargin
            bottomLeftRadius: Theme.expandedModuleRadius - Theme.pillExpandedMargin
            topRightRadius: 0
            bottomRightRadius: 0

            clip: true

            // Visible as soon as expanded or while animating
            visible: wallpaperPanel.expanded || wallpaperPanel.implicitWidth > 0

            BaseCard {
                id: mainCard
                anchors.fill: parent
                anchors.margins: Theme.cardMargin
                hasHeader: true
                headerIcon: "󰸉"
                headerTitle: "Wallpapers"

                readonly property int currentRealIndex: folderModel.count > 0
                    ? (((grid.currentIndex % folderModel.count) + folderModel.count) % folderModel.count)
                    : 0

                headerControls: [
                    Rectangle {
                        implicitHeight: 20
                        implicitWidth: wpCountText.implicitWidth + 10
                        radius: 10
                        color: Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.2)
                        visible: folderModel.count > 0
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: wpCountText
                            anchors.centerIn: parent
                            text: (mainCard.currentRealIndex + 1) + " / " + folderModel.count
                            color: Theme.statusBlue
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize * 0.7
                            font.bold: true
                        }
                    },

                    HeaderButton {
                        visible: folderModel.count > 0
                        hasBorder: true
                        icon: "󰄬 Apply"
                        iconSize: Math.round(Theme.fontSize * 0.78)
                        onClicked: {
                            if (grid.currentItem && typeof grid.currentItem.applyWallpaper === "function") {
                                grid.currentItem.applyWallpaper();
                            }
                        }
                    },

                    HeaderButton {
                        icon: "󰅖"
                        iconSize: Theme.fontSize + 1
                        onClicked: wallpaperPanel.expanded = false
                    }
                ]

                Item {
                    id: carouselContainer
                    anchors {
                        top: mainCard.headerBar.bottom
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                        margins: Theme.cardPadding
                    }
                    clip: true

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
                                width: 430
                                height: 215
                                anchors.right: parent.right
                                anchors.rightMargin: 25

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
                                            radius: Theme.cardItemRadius
                                            color: "black"
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        radius: Theme.cardItemRadius
                                        border.width: delegateRoot.isCurrent ? 2.5 : 2
                                        border.color: delegateRoot.isCurrent
                                            ? (mouseArea.containsMouse ? Theme.palette("light").hover : Theme.palette("light").border)
                                            : (mouseArea.containsMouse ? Theme.palette("neutral").borderHover : Theme.palette("neutral").border)

                                        Behavior on border.color { ColorAnimation { duration: Theme.horizontalDuration } }
                                        Behavior on border.width { NumberAnimation { duration: Theme.horizontalDuration } }
                                    }

                                    Item {
                                        id: labelPill
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 10
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        height: 30
                                        width: Math.min(parent.width - 32, pillRow.implicitWidth + 24)
                                        opacity: Math.max(0.0, 1.0 - delegateRoot.absCenterDist / 50)
                                        visible: opacity > 0

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.cardButtonRadius
                                            color: Qt.rgba(Theme.paletteInk.r, Theme.paletteInk.g, Theme.paletteInk.b, 0.84)
                                            border.width: 1.5
                                            border.color: Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.35)
                                        }

                                        RowLayout {
                                            id: pillRow
                                            anchors.centerIn: parent
                                            width: Math.min(parent.width - 20, implicitWidth)
                                            spacing: 6

                                            Text {
                                                text: "󰸉"
                                                color: Theme.statusBlue
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontSize - 1
                                                font.bold: true
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            Text {
                                                id: fileNameText
                                                Layout.fillWidth: true
                                                text: delegateRoot.fileName
                                                color: Theme.textPrimary
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontSize - 2
                                                font.bold: true
                                                elide: Text.ElideMiddle
                                                horizontalAlignment: Text.AlignHCenter
                                                Layout.alignment: Qt.AlignVCenter
                                            }
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

                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: folderModel.count === 0
                        spacing: 8

                        Text {
                            text: "󰸉"
                            font.family: Theme.font
                            font.pixelSize: 32
                            color: Theme.textPrimary
                            opacity: 0.35
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "No wallpapers found"
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
