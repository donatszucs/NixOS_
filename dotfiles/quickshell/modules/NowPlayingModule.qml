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


    implicitHeight: expanded ? column.implicitHeight + 10 : Theme.moduleHeight
    implicitWidth: expanded ? topRow.implicitWidth + 20 : topRow.implicitWidth
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
        spacing: 10

        anchors {
            left: parent.left
            top: parent.top
            bottomMargin: 10
        }

        RowLayout {
            id: topRow
            spacing: 0
            Layout.alignment: Qt.AlignTop
            layoutDirection: Qt.RightToLeft
            Layout.leftMargin: nowPlayingModule.expanded ? 10 : 0
            // Title
            ModuleButton {
                colorOverride: !expanded
                noHoverColorChange: !expanded
                noPressColorChange: !expanded
                id: titleBtn
                Layout.alignment: Qt.AlignCenter
                cursorShape: isPlaying ? Qt.PointingHandCursor : Qt.ArrowCursor

                // 2. Set your fixed width here
                implicitWidth: expanded ? 200 : Math.min(200, scrollingText.implicitWidth + 20)
                onClicked: focusNow()

                bottomRightRadius: Theme.moduleEdgeRadius

                // 3. Make the container a direct child (no contentItem:)
                HoverMarqueeText {
                    id: scrollingText
                    clip: true 
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10

                    text: nowPlayingModule.titleText
                    textMaxWidth: 200
                    fontFamily: Theme.font
                    pixelSize: Theme.fontSize
                    textColor: Theme.textPrimary
                    fontBold: false
                }
            }

            Text {
                id: artistText
                text: " 󰎆"
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: textFont
                font.bold: true
                visible: !nowPlayingModule.expanded
            }

            // Controls — only visible when expanded
            RowLayout {
                id: controlsRow
                spacing: 0
                layoutDirection: Qt.RightToLeft

                Repeater {
                    model: [
                        { icon: "󰒭", action: "next" },
                        { icon: "󰐊", action: "playpause" }
                    ]
                    delegate: ModuleButton {
                        required property var modelData
                        visible: (currentPlayer && currentPlayer.canGoNext && modelData.action === "next") || (currentPlayer && currentPlayer.canPause && modelData.action === "playpause")
                        cursorShape: Qt.PointingHandCursor
                        
                        implicitHeight: Theme.moduleHeight
                        implicitWidth: nowPlayingModule.expanded ? 32 : 0

                        label: modelData.action === "playpause" ? nowPlayingModule.playPauseIcon : modelData.icon
                        bottomLeftRadius: modelData.action === "playpause" ? Theme.moduleEdgeRadius : 0

                        onClicked: {
                                if (modelData.action === "playpause")
                                    nowPlayingModule.doTogglePlay()
                                else
                                    nowPlayingModule.doNext()
                        }

                        Behavior on implicitWidth {
                            NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
                        }
                    }
                }

                Item { implicitWidth: 0 }
            }

            Behavior on Layout.leftMargin {
                NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }
        }

        ModuleButton {
            Layout.alignment: Qt.AlignHCenter
            id: trackArt
            visible: nowPlayingModule.expanded
            color: "transparent"
            implicitWidth: albumArtClip.width
            implicitHeight: albumArtClip.height

            Item { 
                id: albumArtClip
                anchors.centerIn: parent

                width: topRow.implicitWidth

                // Formula: Height = Width * (Original Height / Original Width)
                height: albumArt.source.toString() !== "" ? topRow.implicitWidth / 2 : artHover.implicitHeight + 10

                Image {
                    id: albumArt
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: currentPlayer && currentPlayer.trackArtUrl ? currentPlayer.trackArtUrl : ""
                    sourceSize.width: 200
                    visible: false 
                }

                MultiEffect {
                    source: albumArt
                    anchors.fill: albumArt
                    visible: albumArt.source.toString() !== ""
                    maskEnabled: true
                    maskSource: maskItem
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

                ModuleButton {
                    id: artHover
                    
                    noHoverColorChange: true
                    noPressColorChange: true
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: height / 2
                    visible: nowPlayingModule.authorText !== ""

                    label: nowPlayingModule.authorText
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

