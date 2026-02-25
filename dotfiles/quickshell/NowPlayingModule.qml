// Now Playing module — title + hover-to-reveal play/pause & skip controls
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Io

ModuleButton {
    id: nowPlayingModule
    noHoverColorChange: true
    property string titleText: "󰎆  Nothing playing"
    property string authorText: "Unknown artist"
    property string playPauseIcon: "󰐊"
    property bool expanded: parentHover.hovered

    HoverHandler {
        id: parentHover
    }

    // Using MPRIS; legacy playerctl state removed
    function refreshAll() { pickPlayer() }

    // Called once we know current player — update metadata
    function fetchMetadata() { updateFromPlayer() }

    implicitHeight: expanded ? Theme.moduleHeight + artistInfoRow.implicitHeight : Theme.moduleHeight
    implicitWidth: expanded ? (controlsRow.implicitWidth + nowPlayingModule.titleText.length * 8 + 16): titleBtn.implicitWidth
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 0

        anchors {
            left: parent.left
            top: parent.top
        }

        RowLayout {
            id: row
            spacing: 0
            layoutDirection: Qt.RightToLeft
            // Title
            ModuleButton {
                variant: "transparentDark"
                id: titleBtn

                topLeftRadius: nowPlayingModule.expanded ? 0 : Theme.moduleRadius
                bottomLeftRadius: nowPlayingModule.expanded ? 0 : Theme.moduleRadius
                bottomRightRadius: nowPlayingModule.expanded ? 0 : Theme.moduleRadius

                label: nowPlayingModule.titleText
                implicitWidth: expanded ? nowPlayingModule.implicitWidth - controlsRow.implicitWidth : nowPlayingModule.titleText.length * 8 + 16
                implicitHeight: Theme.moduleHeight
                onClicked: focusNow()
            }

            // Controls — only visible when expanded
            RowLayout {
                id: controlsRow
                visible: nowPlayingModule.expanded
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

                        variant: "transparentDark"
                        implicitHeight: Theme.moduleHeight
                        radius: 0

                        topLeftRadius: (modelData.action === "next") ? 0 : Theme.moduleRadius

                        label: modelData.action === "playpause" ? nowPlayingModule.playPauseIcon : modelData.icon

                        onClicked: {
                                if (modelData.action === "playpause")
                                    nowPlayingModule.doTogglePlay()
                                else
                                    nowPlayingModule.doNext()
                        }
                    }
                }

                Item { implicitWidth: 0 }
            }
        }
        ColumnLayout {
            id: artistInfoRow
            implicitWidth: nowPlayingModule.implicitWidth
            implicitHeight: Math.max(artistInfo.implicitHeight, trackArt.implicitHeight)

            ModuleButton {
                id: trackArt
                visible: nowPlayingModule.expanded
                variant: "transparentDark"
                implicitWidth: albumArt.width + 30
                implicitHeight: albumArt.height + 15
                anchors.right: nowPlayingModule.right
            
                Image {
                    id: albumArt
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: nowPlayingModule.implicitWidth - 30
                    height: nowPlayingModule.implicitWidth - 30
                    fillMode: Image.PreserveAspectCrop
                    source: currentPlayer && currentPlayer.trackArtUrl ? currentPlayer.trackArtUrl : ""
                    visible: source !== ""
                }
            }
            ModuleButton {
                id: artistInfo
                visible: nowPlayingModule.expanded
                variant: "transparentDark"
                label: nowPlayingModule.authorText
                Layout.alignment: Qt.AlignCenter

            }
        }
    }
    // Use Quickshell.Services.Mpris
    readonly property var mpris: Mpris
    property var currentPlayer: null

    function pickPlayer() {
        // prefer a playing player, otherwise first available
        var pick = null
        if (!Mpris || !Mpris.players) {
            currentPlayer = null
            nowPlayingModule.titleText = "󰎆  Nothing playing"
            nowPlayingModule.authorText = "Unknown artist"
            nowPlayingModule.playPauseIcon = "󰐊"
            return
        }
        // dictionary-like with `values` array (observed structure)
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
            nowPlayingModule.titleText = "󰎆  Nothing playing"
            nowPlayingModule.authorText = "Unknown artist"
            nowPlayingModule.playPauseIcon = "󰐊"
            return
        }
        nowPlayingModule.titleText = "󰎆  " + (currentPlayer.trackTitle || "Nothing playing")
        nowPlayingModule.authorText = currentPlayer.trackArtist || "Unknown artist"
        nowPlayingModule.playPauseIcon = currentPlayer.isPlaying ? "󰏤" : "󰐊"
    }

    // We poll Mpris.players periodically; dynamic Connections caused issues in some builds

    function doTogglePlay() { if (currentPlayer && currentPlayer.togglePlaying) currentPlayer.togglePlaying() }
    function doNext() { if (currentPlayer && currentPlayer.next) currentPlayer.next() }

    Process {
        id: focusProc
        // command will be set before running in focusNow()
    }

    function focusNow() {
        if (!currentPlayer) return
        var id = currentPlayer.identity.toLowerCase().trim()
        var cls = (id.match(/chromium|chrome/)) ? "google-chrome" : id
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

