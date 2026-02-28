// Now Playing module — title + hover-to-reveal play/pause & skip controls
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Io
import QtQuick.Effects

ModuleButton {
    id: nowPlayingModule
    noHoverColorChange: true
    property string titleText: "󰎆  Nothing playing"
    property string authorText: "Unknown artist"
    property string playPauseIcon: "󰐊"
    property bool expanded: parentHover.hovered

    HoverHandler {
        id: parentHover
        onHoveredChanged: {
            scrollAnim.stop()
            scrollAnim.restart()
        }

    }

    // Using MPRIS; legacy playerctl state removed
    function refreshAll() { pickPlayer() }


    implicitHeight: expanded ? Theme.moduleHeight + artistInfoRow.implicitHeight : Theme.moduleHeight
    implicitWidth: expanded ? (controlsRow.implicitWidth + titleBtn.implicitWidth): titleBtn.implicitWidth
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: horizontalDuration; easing.type: Easing.OutCubic }
    }
    bottomLeftRadius: expanded ? Theme.moduleEdgeRadius : 0
    bottomRightRadius: Theme.moduleEdgeRadius

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
                Layout.alignment: Qt.AlignCenter

                // 2. Set your fixed width here
                implicitWidth: expanded ? 200 : Math.min(200, scrollingText.paintedWidth + 30)
                onClicked: focusNow()

                // 3. Make the container a direct child (no contentItem:)
                Item {
                    id: textContainer
                    clip: true 
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10

                    Text {
                        id: scrollingText
                        text: nowPlayingModule.titleText
                        
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on x {
                            id: scrollAnim
                            loops: Animation.Infinite
                            running: scrollingText.paintedWidth > textContainer.width

                            onRunningChanged: {
                                if (!running) {
                                    scrollingText.x = 0;
                                }
                            }

                            PropertyAction { target: scrollingText; property: "x"; value: 0 }

                            PauseAnimation { duration: 1500 }

                            NumberAnimation {
                                from: 0
                                to: Math.min(0, textContainer.width - scrollingText.paintedWidth)
                                // Adjust the multiplier (30) to make it scroll faster or slower
                                duration: Math.max(0, scrollingText.paintedWidth - textContainer.width) * 30 
                            }

                            PauseAnimation { duration: 1500 }

                            PropertyAction { target: scrollingText; property: "x"; value: 0 }
                        }
                    }
                }
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
                        implicitWidth: expanded ? 32 : 0

                        label: modelData.action === "playpause" ? nowPlayingModule.playPauseIcon : modelData.icon

                        onClicked: {
                                if (modelData.action === "playpause")
                                    nowPlayingModule.doTogglePlay()
                                else
                                    nowPlayingModule.doNext()
                        }

                        Behavior on implicitWidth {
                            NumberAnimation { duration: horizontalDuration; easing.type: Easing.OutCubic }
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
                implicitWidth: albumArtClip.width + 30
                implicitHeight: albumArtClip.height + 15
                anchors.right: nowPlayingModule.right

                // Changed to an Item since MultiEffect handles the drawing now
                Item { 
                    id: albumArtClip
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    
                    // 1. The fixed width you want
                    width: nowPlayingModule.implicitWidth - 30
                    
                    // 2. Calculate the height dynamically using the image's source dimensions
                    // Formula: Height = Width * (Original Height / Original Width)
                    height: albumArt.sourceSize.width > 0 
                            ? (width * (albumArt.sourceSize.height / albumArt.sourceSize.width)) 
                            : width // Fallback: makes it a perfect square before the image finishes loading

                    Image {
                        id: albumArt
                        anchors.fill: parent
                        // Since the container now perfectly matches the image's ratio, 
                        // PreserveAspectFit or Stretch will both work perfectly without cutting anything off.
                        fillMode: Image.PreserveAspectFit
                        source: currentPlayer && currentPlayer.trackArtUrl ? currentPlayer.trackArtUrl : ""
                        visible: false 
                    }

                    // 3. The Qt 6 way to apply masks and effects
                    MultiEffect {
                        source: albumArt
                        anchors.fill: albumArt
                        visible: albumArt.source.toString() !== ""
                        maskEnabled: true
                        maskSource: maskItem
                    }

                    // 4. The shape of our mask
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
    property string currentTrackId: ""

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
        nowPlayingModule.playPauseIcon = currentPlayer.isPlaying ? "󰏤" : "󰐊"

        if (currentTrackId !== currentPlayer.trackTitle) {
            currentTrackId = currentPlayer.trackTitle
            nowPlayingModule.titleText = "󰎆  " + (currentPlayer.trackTitle || "Nothing playing")
            nowPlayingModule.authorText = currentPlayer.trackArtist || "Unknown artist"
            // Reset scrolling animation when the track actually changes
            scrollAnim.restart()
        }
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

