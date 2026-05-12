// Now Playing module — title + hover-to-reveal play/pause & skip controls
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Io
import QtQuick.Effects

import "../elements"

ModuleButton {
    id: nowPlayingModule
    noHoverColorChange: expanded || !isPlaying
    noPressColorChange: true
    property string titleText: "Nothing playing"
    property string authorText: "Unknown artist"
    property string playPauseIcon: "󰐊"
    property bool isPlaying: false
    property bool expanded: isPlaying && parentHover.hovered

    HoverHandler {
        id: parentHover
    }

    // Using MPRIS; legacy playerctl state removed
    function refreshAll() { pickPlayer() }


    implicitHeight: expanded ? albumArtClip.height + 20: Theme.moduleHeight
    implicitWidth: expanded ? albumArtClip.width + 20 : titleBtn.implicitWidth
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.horizontalDuration / 2; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    bottomLeftRadius: expanded ? Theme.moduleEdgeRadius + 10 : 0
    bottomRightRadius: expanded ? Theme.moduleEdgeRadius + 10 : Theme.moduleEdgeRadius

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.bottomMargin: 10
        spacing: 0

        // Title
        ModuleButton {
            colorOverride: !expanded
            noHoverColorChange: !expanded
            noPressColorChange: !expanded
            id: titleBtn
            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.topMargin: nowPlayingModule.expanded ? 15 : 0
            cursorShape: isPlaying ? Qt.PointingHandCursor : Qt.ArrowCursor


            Behavior on Layout.topMargin {
                NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }
            
            implicitWidth: scrollingText.implicitWidth + artistText.implicitWidth + 20
            onClicked: focusNow()

            radius: Theme.moduleEdgeRadius
            colorOpacity: 0.9

            RowLayout {
                id: topRow
                anchors.centerIn: parent
                spacing: 0
                layoutDirection: Qt.RightToLeft

                HoverMarqueeText {
                    id: scrollingText
                    clip: true 
                    Layout.alignment: Qt.AlignVCenter

                    text: nowPlayingModule.titleText
                    textMaxWidth: 200
                    fontFamily: Theme.font
                    pixelSize: Theme.fontSize
                    textColor: Theme.textPrimary
                    fontBold: true
                }

                Text {
                    id: artistText
                    text: "󰎆 "
                    color: Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: textFont
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }


        ModuleButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: - Theme.moduleHeight - 5
            z: -1
            id: trackArt
            visible: nowPlayingModule.expanded
            color: "transparent"
            implicitWidth: albumArtClip.width
            implicitHeight: albumArtClip.height

            Item { 
                id: albumArtClip
                anchors.centerIn: parent

                width: 250
                // Formula: Height = Width * (Original Height / Original Width)
                height: albumArt.source.toString() !== "" ? albumArtClip.width / 2 : artHover.implicitHeight + 45

                Image {
                    id: albumArt
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: currentPlayer && currentPlayer.trackArtUrl ? currentPlayer.trackArtUrl : ""
                    sourceSize.width: 250
                    
                    visible: false 
                }

                MultiEffect {
                    source: albumArt
                    anchors.fill: albumArt
                    visible: albumArt.source.toString() !== ""
                    maskEnabled: true
                    maskSource: maskItem
                    opacity: 0.7
                }

                Item {
                    id: maskItem
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.moduleEdgeRadius
                        color: "black" 
                    }
                }

                RowLayout {
                    id: controlsRow
                    spacing: 0
                    layoutDirection: Qt.RightToLeft
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: albumArt.source.toString() !== "" ? 5 : 0
                    anchors.horizontalCenter: parent.horizontalCenter

                    ModuleButton {
                        id: artHover
                        
                        bottomRightRadius: height / 2
                        topRightRadius: height / 2
                        visible: nowPlayingModule.authorText !== ""
                        colorOpacity: 0.9

                        implicitWidth: expanded ? scrollingAuthorText.implicitWidth + 20 : 0

                        HoverMarqueeText {
                            id: scrollingAuthorText
                            clip: true 
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            text: nowPlayingModule.authorText
                            textMaxWidth: albumArtClip.width - 30 - nextButton.implicitWidth - playPauseButton.implicitWidth
                            fontFamily: Theme.font
                            pixelSize: Theme.fontSize
                            textColor: Theme.textPrimary
                            fontBold: false
                        }
                    }

                    ModuleButton {
                        id: nextButton
                        cursorShape: Qt.PointingHandCursor
                        
                        implicitHeight: Theme.moduleHeight
                        implicitWidth: (nowPlayingModule.expanded && currentPlayer.canGoNext) ? Theme.moduleHeight : 0

                        label: "󰒭"

                        colorOpacity: 0.9

                        onClicked: nowPlayingModule.doNext()

                        Behavior on implicitWidth {
                            NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
                        }
                    }

                    ModuleButton {
                        id: playPauseButton
                        cursorShape: Qt.PointingHandCursor
                        
                        implicitHeight: Theme.moduleHeight
                        implicitWidth: nowPlayingModule.expanded ? Theme.moduleHeight : 0

                        label: nowPlayingModule.playPauseIcon

                        topLeftRadius: height / 2
                        bottomLeftRadius: height / 2

                        colorOpacity: 0.9

                        onClicked: nowPlayingModule.doTogglePlay()

                        Behavior on implicitWidth {
                            NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
    }

    readonly property var mpris: Mpris
    property var currentPlayer: null
    property string currentTrackId: ""

    function pickPlayer() {
        var pick = null
        if (!Mpris || !Mpris.players) {
            currentPlayer = null
            nowPlayingModule.titleText = "Nothing playing"
            nowPlayingModule.authorText = "Unknown artist"
            nowPlayingModule.playPauseIcon = "󰐊"
            return
        }
        else {
            for (var vi = 0; vi < Mpris.players.values.length; vi++) {
                var pv = Mpris.players.values[vi]
                if (!pv) continue
                if (pv.isPlaying) { pick = pv; break }
                if (!pick) pick = pv
            }
        }

        currentPlayer = pick
        updateFromPlayer()
    }

    function updateFromPlayer() {
        if (!currentPlayer) {
            nowPlayingModule.isPlaying = false
            nowPlayingModule.titleText = "Nothing playing"
            nowPlayingModule.authorText = "Unknown artist"
            nowPlayingModule.playPauseIcon = "󰐊"
            return
        }
        nowPlayingModule.playPauseIcon = currentPlayer.isPlaying ? "󰏤" : "󰐊"
        nowPlayingModule.isPlaying = true
        if (currentTrackId !== currentPlayer.trackTitle) {
            currentTrackId = currentPlayer.trackTitle
            nowPlayingModule.titleText = (currentPlayer.trackTitle || "Nothing playing")
            nowPlayingModule.authorText = currentPlayer.trackArtist || "Unknown artist"
        }
    }

    function doTogglePlay() { if (currentPlayer && currentPlayer.togglePlaying) currentPlayer.togglePlaying() }
    function doNext() { if (currentPlayer && currentPlayer.next) currentPlayer.next() }

    Process {
        id: focusProc
        // command will be set before running in focusNow()
    }

    function focusNow() {
        if (!currentPlayer) return
        var id = currentPlayer.identity.toLowerCase().trim()
        console.log("Focusing player with identity:", id)
        var cls = (id.match(/mozilla firefox/) || id.match(/mozilla zen/)) ? "zen" : id
        focusProc.command = ["bash", "-c", "hyprctl dispatch focuswindow class:" + cls]
        console.log("Running focus command:", focusProc.command)
        focusProc.running = true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: pickPlayer()
    }

    Component.onCompleted: pickPlayer()
}

