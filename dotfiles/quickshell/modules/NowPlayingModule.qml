// Now Playing module — title + hover-to-reveal controls, scrubber & multi-player carousel
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Io
import QtQuick.Effects
import Quickshell.Hyprland

import "../elements"

ExpandableModule {
    id: nowPlayingModule
    collapseOnHoverExit: false
    noHoverColorChange: expanded || !isPlaying
    noPressColorChange: true
    collapsedBottomRightRadius: Theme.moduleEdgeRadius

    property string titleText: "Nothing playing"
    property string authorText: "Unknown artist"
    property string albumText: ""
    property string playPauseIcon: ""

    // hasPlayer reflects if a valid player exists
    property bool hasPlayer: currentPlayer !== null
    // isPlaying retained for compatibility with ExpandableModule & Bar
    property bool isPlaying: hasPlayer

    // Optimistic playback state for instant 0ms user feedback
    property bool _optimisticPlaying: false
    property bool _hasOptimisticPlaying: false
    readonly property bool isMediaPlaying: _hasOptimisticPlaying
        ? _optimisticPlaying
        : (currentPlayer ? currentPlayer.isPlaying : false)

    expanded: hasPlayer && expandHover.hovered

    property var currentPlayer: null
    property var manualPlayerOverride: null
    property int playerCount: 0
    property var playersList: []

    // Guard flag to prevent carousel ↔ player feedback loops
    property bool _syncingCarousel: false

    // Timeline / Scrubbing
    property real currentPosition: 0
    property real trackLength: 0
    property bool scrubbing: false
    property real _savedVolume: 0.5

    property real expandedHeight: 290

    implicitHeight: expanded ? expandedHeight : Theme.moduleHeight
    implicitWidth: expanded ? 280 : titleBtn.implicitWidth + 10

    // ── Helper: time formatter (seconds -> mm:ss) ────────────────
    function formatTime(seconds) {
        if (isNaN(seconds) || seconds === undefined || seconds === null || seconds < 0) return "0:00"
        var totalSec = Math.floor(seconds)
        var mins = Math.floor(totalSec / 60)
        var secs = totalSec % 60
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    // ── Helper: player icon resolver ────────────────────────────
    function getPlayerIcon(player) {
        if (!player) return "󰎆"
        var id = ((player.identity || "") + " " + (player.desktopEntry || "")).toLowerCase()
        if (id.indexOf("spotify") !== -1) return ""
        if (id.indexOf("zen") !== -1) return "󰈹"
        if (id.indexOf("firefox") !== -1) return "󰈹"
        if (id.indexOf("chrome") !== -1 || id.indexOf("chromium") !== -1) return ""
        if (id.indexOf("brave") !== -1) return "󰮊"
        if (id.indexOf("mpv") !== -1 || id.indexOf("vlc") !== -1) return "󰕼"
        return "󰎆"
    }

    // ── Helper: player display name ─────────────────────────────
    function getPlayerName(player) {
        if (!player) return ""
        var id = player.identity || player.desktopEntry || "Media"
        if (id.toLowerCase().indexOf("zen") !== -1) return "Zen"
        if (id.toLowerCase().indexOf("spotify") !== -1) return "Spotify"
        if (id.toLowerCase().indexOf("firefox") !== -1) return "Firefox"
        return id
    }

    // ── Helper: reset to idle state ──────────────────────────────
    function resetState() {
        currentPlayer = null
        manualPlayerOverride = null
        playerCount = 0
        playersList = []
        titleText = "Nothing playing"
        authorText = "Unknown artist"
        albumText = ""
        playPauseIcon = ""
        currentPosition = 0
        trackLength = 0
        _hasOptimisticPlaying = false
    }

    // ── Helper: sync UI from currentPlayer ──────────────────────
    function updateFromPlayer() {
        if (!currentPlayer) {
            resetState()
            return
        }
        _hasOptimisticPlaying = false
        playPauseIcon = currentPlayer.isPlaying ? "" : ""
        titleText = (currentPlayer.trackTitle || "").trim() || "Nothing playing"
        authorText = (currentPlayer.trackArtist || "").trim() || "Unknown artist"
        albumText = (currentPlayer.trackAlbum || "").trim()
        trackLength = currentPlayer.length || 0
        if (!scrubbing) {
            currentPosition = currentPlayer.position || 0
        }
    }

    // ── Core: pick & sync the active player ─────────────────────
    function pickPlayer() {
        if (!Mpris || !Mpris.players) { resetState(); return }

        // Collect live players
        var raw = []
        for (var i = 0; i < Mpris.players.values.length; i++) {
            var p = Mpris.players.values[i]
            if (p) raw.push(p)
        }

        // Filter out phantom/ghost MPRIS instances.
        var realPlayers = []
        for (var ri = 0; ri < raw.length; ri++) {
            var rp = raw[ri]
            if (rp.trackArtUrl || (rp.trackArtist || "").trim()) {
                realPlayers.push(rp)
            }
        }

        var players = []
        for (var fi = 0; fi < raw.length; fi++) {
            var fp = raw[fi]
            var isPhantom = false
            if (!fp.trackArtUrl && !(fp.trackArtist || "").trim()) {
                var fTitle = (fp.trackTitle || "").trim()
                for (var r = 0; r < realPlayers.length; r++) {
                    var rTitle = (realPlayers[r].trackTitle || "").trim()
                    if (fTitle && rTitle && (fTitle.indexOf(rTitle) !== -1 || rTitle.indexOf(fTitle) !== -1)) {
                        isPhantom = true
                        break
                    }
                }
            }
            if (!isPhantom) players.push(fp)
        }

        if (players.length === 0) { resetState(); return }

        if (!playersListEqual(playersList, players)) {
            playersList = players
        }
        playerCount = players.length

        // Validate manual override still exists
        if (manualPlayerOverride) {
            var found = false
            for (var j = 0; j < players.length; j++) {
                if (players[j] === manualPlayerOverride) { found = true; break }
            }
            if (!found) manualPlayerOverride = null
        }

        // Pick: manual override > first playing > first in list
        var pick = null
        if (manualPlayerOverride) {
            pick = manualPlayerOverride
        } else {
            for (var k = 0; k < players.length; k++) {
                if (players[k].isPlaying) { pick = players[k]; break }
                if (!pick) pick = players[k]
            }
        }

        currentPlayer = pick
        updateFromPlayer()

        // Sync carousel index to match the picked player
        if (playerCount > 1) {
            _syncingCarousel = true
            for (var ci = 0; ci < playersList.length; ci++) {
                if (playersList[ci] === currentPlayer) {
                    playerCarousel.currentIndex = ci
                    break
                }
            }
            _syncingCarousel = false
        }
    }

    // Shallow identity comparison of two player arrays
    function playersListEqual(a, b) {
        if (!a || !b) return false
        if (a.length !== b.length) return false
        for (var i = 0; i < a.length; i++) {
            if (a[i] !== b[i]) return false
        }
        return true
    }

    // ── Actions ─────────────────────────────────────────────────
    function doTogglePlay() {
        if (!currentPlayer) return
        // Instant optimistic feedback (0ms latency)
        var willPlay = !isMediaPlaying
        _hasOptimisticPlaying = true
        _optimisticPlaying = willPlay
        playPauseIcon = willPlay ? "" : ""

        if (currentPlayer.canTogglePlaying) {
            currentPlayer.togglePlaying()
        } else if (currentPlayer.isPlaying && (currentPlayer.canPause || currentPlayer.pause)) {
            currentPlayer.pause()
        } else if (!currentPlayer.isPlaying && (currentPlayer.canPlay || currentPlayer.play)) {
            currentPlayer.play()
        } else if (currentPlayer.togglePlaying) {
            currentPlayer.togglePlaying()
        }
    }

    function doPrevious() {
        if (!currentPlayer) return
        if (currentPlayer.canGoPrevious !== false && currentPlayer.previous) {
            currentPlayer.previous()
        }
    }

    function doNext() {
        if (!currentPlayer) return
        if (currentPlayer.canGoNext !== false && currentPlayer.next) {
            currentPlayer.next()
        }
    }

    function doStop() {
        if (!currentPlayer) return
        if (currentPlayer.stop) {
            currentPlayer.stop()
            _hasOptimisticPlaying = true
            _optimisticPlaying = false
            playPauseIcon = ""
        }
    }

    function toggleShuffle() {
        if (!currentPlayer || !currentPlayer.shuffleSupported) return
        currentPlayer.shuffle = !currentPlayer.shuffle
    }

    function toggleLoop() {
        if (!currentPlayer || !currentPlayer.loopSupported) return
        var state = currentPlayer.loopState
        if (state === MprisLoopState.None || state === 0) {
            currentPlayer.loopState = MprisLoopState.Playlist
        } else if (state === MprisLoopState.Playlist || state === 2) {
            currentPlayer.loopState = MprisLoopState.Track
        } else {
            currentPlayer.loopState = MprisLoopState.None
        }
    }

    function changeVolume(delta) {
        if (!currentPlayer || !currentPlayer.volumeSupported) return
        var currentVol = currentPlayer.volume !== undefined ? currentPlayer.volume : 1.0
        var newVol = Math.max(0.0, Math.min(1.0, currentVol + delta))
        currentPlayer.volume = Math.round(newVol * 100) / 100
    }

    function toggleMute() {
        if (!currentPlayer || !currentPlayer.volumeSupported) return
        if (currentPlayer.volume > 0.01) {
            nowPlayingModule._savedVolume = currentPlayer.volume
            currentPlayer.volume = 0.0
        } else {
            currentPlayer.volume = nowPlayingModule._savedVolume > 0.05 ? nowPlayingModule._savedVolume : 0.5
        }
    }

    function focusNow() {
        if (!currentPlayer) return
        if (currentPlayer.canRaise && currentPlayer.raise) {
            try { currentPlayer.raise() } catch(e) {}
        }
        var id = (currentPlayer.identity || "").toLowerCase().trim()
        var cls = id.match(/mozilla zen/) ? "zen" : id
        var safeCls = cls.replace(/'/g, "\\'")
        Hyprland.dispatch("hl.dsp.focus({ window = 'class:(?i)" + safeCls + "' })")
    }

    // ── Instant Reactive D-Bus Signals ──────────────────────────
    // Detect player connect/disconnect immediately
    Connections {
        target: Mpris.players
        function onValuesChanged() {
            nowPlayingModule.pickPlayer()
        }
    }

    // Detect currentPlayer state changes immediately
    Connections {
        target: nowPlayingModule.currentPlayer
        function onIsPlayingChanged() { nowPlayingModule.updateFromPlayer() }
        function onPlaybackStateChanged() { nowPlayingModule.updateFromPlayer() }
        function onTrackTitleChanged() { nowPlayingModule.updateFromPlayer() }
        function onTrackArtistChanged() { nowPlayingModule.updateFromPlayer() }
        function onTrackAlbumChanged() { nowPlayingModule.updateFromPlayer() }
        function onTrackArtUrlChanged() { nowPlayingModule.updateFromPlayer() }
        function onLengthChanged() {
            if (nowPlayingModule.currentPlayer) {
                nowPlayingModule.trackLength = nowPlayingModule.currentPlayer.length || 0
            }
        }
        function onPositionChanged() {
            if (nowPlayingModule.currentPlayer && !nowPlayingModule.scrubbing) {
                nowPlayingModule.currentPosition = nowPlayingModule.currentPlayer.position || 0
            }
        }
    }

    // Position updater: active ONLY when expanded and playing (zero idle overhead)
    Timer {
        id: positionTimer
        interval: 350
        running: nowPlayingModule.expanded && nowPlayingModule.currentPlayer !== null && nowPlayingModule.currentPlayer.isPlaying
        repeat: true
        onTriggered: {
            if (!nowPlayingModule.scrubbing && nowPlayingModule.currentPlayer && nowPlayingModule.currentPlayer.positionSupported) {
                nowPlayingModule.currentPosition = nowPlayingModule.currentPlayer.position || 0
            }
        }
    }

    // Fallback polling (1000ms) for external players that don't emit property signals
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: pickPlayer()
    }

    Component.onCompleted: pickPlayer()

    // ══════════════════════════════════════════════════════════════
    //  UI
    // ══════════════════════════════════════════════════════════════

    // Reusable placeholder for sources with no album art
    Component {
        id: artPlaceholder
        Rectangle {
            radius: 12
            color: Theme.palette("dark").base
            border.width: 1
            border.color: Theme.palette("dark").border

            Text {
                anchors.centerIn: parent
                text: "󰎆"
                font.family: Theme.font
                font.pixelSize: parent.width > 100 ? 42 : 36
                color: Theme.palette("dark").text
                opacity: 0.4
            }
        }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.bottomMargin: nowPlayingModule.expanded ? 10 : 0
        spacing: 0

        // ── Title bar ───────────────────────────────────────────
        ModuleButton {
            id: titleBtn
            colorOverride: !nowPlayingModule.expanded
            noHoverColorChange: !nowPlayingModule.expanded
            noPressColorChange: !nowPlayingModule.expanded
            variant: "dark"

            implicitHeight: Theme.moduleHeight - 10
            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.topMargin: nowPlayingModule.expanded ? 10 : 5
            cursorShape: isPlaying ? Qt.PointingHandCursor : Qt.ArrowCursor

            Behavior on Layout.topMargin {
                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
            }

            implicitWidth: scrollingText.implicitWidth + artistText.implicitWidth + 5
            onClicked: focusNow()
            radius: Theme.moduleEdgeRadius - 5

            // Background album art (collapsed only)
            Item {
                anchors.fill: parent

                Item {
                    anchors.fill: parent
                    anchors.margins: 2

                    Item {
                        id: titleArtCropped
                        anchors.fill: parent
                        visible: false
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: currentPlayer && currentPlayer.trackArtUrl
                                ? currentPlayer.trackArtUrl : ""
                            sourceSize.width: 250
                        }
                    }

                    MultiEffect {
                        source: titleArtCropped
                        anchors.fill: parent
                        maskEnabled: true
                        maskSource: titleMaskItem
                        visible: !nowPlayingModule.expanded
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: titleBtn.radius - 2
                        color: Qt.lighter(Theme.palette("dark").base, 2.7)
                        opacity: 0.8
                    }

                    Item {
                        id: titleMaskItem
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Rectangle {
                            anchors.fill: parent
                            radius: titleBtn.radius - 2
                            color: "black"
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: titleBtn.radius
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.palette("light").border
                }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0
                layoutDirection: Qt.RightToLeft

                HoverMarqueeText {
                    id: scrollingText
                    clip: true
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 10
                    Layout.leftMargin: 5

                    text: nowPlayingModule.titleText
                    textMaxWidth: 190
                    fontFamily: Theme.font
                    pixelSize: Theme.fontSize
                    textColor: Theme.textPrimary
                    fontBold: true
                }

                ModuleButton {
                    id: artistText
                    variant: "neutral"
                    clip: false
                    Layout.fillHeight: true
                    implicitWidth: 25

                    topLeftRadius: titleBtn.radius
                    bottomLeftRadius: titleBtn.radius
                    topRightRadius: 0
                    bottomRightRadius: 0

                    label: nowPlayingModule.getPlayerIcon(nowPlayingModule.currentPlayer)
                    leftMargin: 3

                    InverseRadius {
                        anchors.top: parent.top
                        anchors.left: parent.right
                        cornerPosition: "topLeft"
                        color: artistText.color
                        size: 10
                    }
                    InverseRadius {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.right
                        cornerPosition: "bottomLeft"
                        color: artistText.color
                        size: 10
                    }
                }
            }
        }

        // ── Expanded art / carousel / controls ──────────────────
        ModuleButton {
            id: trackArt
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -Theme.moduleHeight - 5
            z: -1
            clip: false
            opacity: nowPlayingModule.expanded ? 1 : 0
            color: "transparent"
            implicitWidth: nowPlayingModule.expanded ? 260 : titleBtn.implicitWidth
            implicitHeight: nowPlayingModule.expanded ? (nowPlayingModule.expandedHeight - 5) : 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
            }
            Behavior on implicitWidth {
                NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }
            Behavior on implicitHeight {
                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
            }

            Item {
                id: albumArtClip
                anchors.fill: parent

                layer.enabled: true
                layer.smooth: true
                layer.effect: MultiEffect {
                    opacity: 0.95
                }

                // Carousel & Metadata Panel (translucent background card)
                Rectangle {
                    id: carouselPanel
                    anchors.top: parent.top
                    anchors.topMargin: Theme.moduleHeight + 15
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    color: Qt.rgba(1, 1, 1, 0.08)
                    radius: Theme.moduleEdgeRadius
                    clip: true
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    // Multi-player: carousel
                    ListView {
                        id: playerCarousel
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        anchors.bottom: middleControls.top
                        anchors.bottomMargin: 8
                        anchors.left: parent.left
                        anchors.right: parent.right
                        visible: true
                        model: nowPlayingModule.playersList
                        orientation: ListView.Horizontal

                    onCurrentIndexChanged: {
                        if (nowPlayingModule._syncingCarousel) return
                        if (nowPlayingModule.playersList.length === 0) return
                        if (currentIndex < 0 || currentIndex >= nowPlayingModule.playersList.length) return

                        var p = nowPlayingModule.playersList[currentIndex]
                        if (nowPlayingModule.manualPlayerOverride !== p) {
                            nowPlayingModule.manualPlayerOverride = p
                            nowPlayingModule.pickPlayer()
                        }
                    }

                    preferredHighlightBegin: width / 2 - 100
                    preferredHighlightEnd: width / 2 + 100
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    snapMode: ListView.SnapToItem
                    spacing: -50

                    delegate: Item {
                        id: delegateRoot
                        width: 200
                        height: playerCarousel.height

                        property real itemCenter: x + width / 2
                        property real viewCenter: playerCarousel.contentX + playerCarousel.width / 2
                        property real centerDist: itemCenter - viewCenter
                        property real absCenterDist: Math.abs(centerDist)
                        property real outOfFocusDist: Math.max(0, absCenterDist - 30)
                        property real absDist: Math.min(1.0, outOfFocusDist / 120)
                        property real effectiveNormDist: (centerDist < 0 ? -1 : 1) * absDist
                        property bool hasArt: !!(modelData && modelData.trackArtUrl)

                        z: 100 - absDist * 100

                        Item {
                            width: 200
                            height: playerCarousel.height
                            anchors.centerIn: parent

                            scale: 1.0 - 0.25 * delegateRoot.absDist
                                + Math.max(0, 1.0 - delegateRoot.absCenterDist / 50) * 0.05

                            transform: Translate {
                                x: -Math.pow(delegateRoot.effectiveNormDist, 3) * 80
                            }

                            Item {
                                id: delegateWrapper
                                anchors.fill: parent

                                property real imgAspect: (delegateImg.implicitWidth > 0 && delegateImg.implicitHeight > 0)
                                    ? delegateImg.implicitWidth / delegateImg.implicitHeight : 1.0
                                property real targetW: Math.min(width, height * imgAspect)
                                property real targetH: Math.min(height, width / imgAspect)

                                Item {
                                    id: delegateImgContainer
                                    anchors.centerIn: parent
                                    width: delegateRoot.hasArt ? delegateWrapper.targetW : Math.min(parent.width, parent.height)
                                    height: delegateRoot.hasArt ? delegateWrapper.targetH : Math.min(parent.width, parent.height)

                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.effect: MultiEffect {
                                        brightness: -delegateRoot.absDist * 0.3
                                        contrast: -delegateRoot.absDist * 0.7
                                        shadowEnabled: true
                                        shadowColor: delegateRoot.absDist > 0 ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.2)
                                        shadowBlur: 0.8
                                        shadowVerticalOffset: 0
                                        shadowHorizontalOffset: 0

                                        Behavior on shadowColor {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }

                                    Loader {
                                        anchors.fill: parent
                                        sourceComponent: artPlaceholder
                                        active: !delegateRoot.hasArt
                                        visible: active
                                    }

                                    Image {
                                        id: delegateImg
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: delegateRoot.hasArt ? modelData.trackArtUrl : ""
                                        sourceSize.width: 250
                                        visible: false
                                    }

                                    MultiEffect {
                                        anchors.fill: parent
                                        source: delegateImg
                                        visible: delegateRoot.hasArt
                                        maskEnabled: true
                                        maskSource: imgMask
                                    }

                                    Item {
                                        id: imgMask
                                        anchors.fill: parent
                                        visible: false
                                        layer.enabled: true
                                        layer.smooth: true

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 15
                                            color: "black"
                                            antialiasing: true
                                        }
                                    }

                                    // Clicking art selects carousel item or focuses player window
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (playerCarousel.currentIndex !== index) {
                                                playerCarousel.currentIndex = index
                                            } else {
                                                nowPlayingModule.focusNow()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                    // Wheel over art: multi-player switches player; single player adjusts volume
                    MouseArea {
                        anchors.fill: playerCarousel
                        acceptedButtons: Qt.NoButton
                        onWheel: function(wheel) {
                            if (nowPlayingModule.playerCount > 1) {
                                if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
                                    if (playerCarousel.currentIndex > 0)
                                        playerCarousel.decrementCurrentIndex()
                                } else {
                                    if (playerCarousel.currentIndex < playerCarousel.count - 1)
                                        playerCarousel.incrementCurrentIndex()
                                }
                            } else {
                                nowPlayingModule.changeVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
                            }
                        }
                    }

                    // Middle Controls: Play/Pause (big) & Seeker Track + Timestamps
                    RowLayout {
                        id: middleControls
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: authorBar.top
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.bottomMargin: 8
                        spacing: 12
                        height: 40

                        // Large Play / Pause Button (Circle)
                        ModuleButton {
                            id: playPauseBtn
                            variant: nowPlayingModule.isMediaPlaying ? "light" : "neutral"
                            cursorShape: Qt.PointingHandCursor
                            textFont: 22
                            implicitHeight: 36
                            implicitWidth: 36
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: false
                            radius: 18
                            clip: true

                            label: nowPlayingModule.playPauseIcon
                            onClicked: nowPlayingModule.doTogglePlay()

                            // Right-click to stop
                            TapHandler {
                                acceptedButtons: Qt.RightButton
                                onTapped: nowPlayingModule.doStop()
                            }
                        }

                        // Right Column: Seeker Track (top) and Timestamps (bottom)
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0

                            // Seeker Track
                            Item {
                                id: seekTrack
                                Layout.fillWidth: true
                                implicitHeight: 20

                                property real progressRatio: {
                                    if (nowPlayingModule.trackLength > 0) {
                                        return Math.max(0.0, Math.min(1.0, nowPlayingModule.currentPosition / nowPlayingModule.trackLength))
                                    }
                                    return 0.0
                                }

                                // Track groove
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 6
                                    radius: 3
                                    color: Theme.palette("neutral").base
                                    border.width: 1
                                    border.color: Theme.palette("neutral").border

                                    // Fill bar
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width * seekTrack.progressRatio
                                        radius: 3
                                        color: Theme.palette("light").base

                                        Behavior on width {
                                            enabled: !nowPlayingModule.scrubbing
                                            NumberAnimation { duration: 150; easing.type: Easing.Linear }
                                        }
                                    }
                                }

                                // Scrubber knob
                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.max(0, Math.min(parent.width - width, (parent.width * seekTrack.progressRatio) - width / 2))
                                    color: Theme.palette("light").text
                                    border.width: 2
                                    border.color: Theme.palette("light").border
                                    visible: nowPlayingModule.trackLength > 0
                                    opacity: (seekMouseArea.containsMouse || nowPlayingModule.scrubbing) ? 1.0 : 0.8
                                    scale: (seekMouseArea.containsMouse || nowPlayingModule.scrubbing) ? 1.2 : 1.0

                                    Behavior on scale {
                                        NumberAnimation { duration: 120 }
                                    }
                                    Behavior on opacity {
                                        NumberAnimation { duration: 120 }
                                    }
                                }

                                MouseArea {
                                    id: seekMouseArea
                                    anchors.fill: parent
                                    anchors.topMargin: -6
                                    anchors.bottomMargin: -6
                                    hoverEnabled: true
                                    cursorShape: (nowPlayingModule.currentPlayer && (nowPlayingModule.currentPlayer.canSeek || nowPlayingModule.currentPlayer.positionSupported) && nowPlayingModule.trackLength > 0)
                                        ? Qt.PointingHandCursor : Qt.ArrowCursor

                                    function updateSeek(mouseX) {
                                        if (!nowPlayingModule.currentPlayer || nowPlayingModule.trackLength <= 0) return
                                        var ratio = Math.max(0.0, Math.min(1.0, mouseX / width))
                                        nowPlayingModule.currentPosition = ratio * nowPlayingModule.trackLength
                                    }

                                    onPressed: function(mouse) {
                                        if (!nowPlayingModule.currentPlayer || nowPlayingModule.trackLength <= 0) return
                                        nowPlayingModule.scrubbing = true
                                        updateSeek(mouse.x)
                                    }

                                    onPositionChanged: function(mouse) {
                                        if (nowPlayingModule.scrubbing) {
                                            updateSeek(mouse.x)
                                        }
                                    }

                                    onReleased: function(mouse) {
                                        if (nowPlayingModule.scrubbing) {
                                            updateSeek(mouse.x)
                                            if (nowPlayingModule.currentPlayer && (nowPlayingModule.currentPlayer.canSeek || nowPlayingModule.currentPlayer.positionSupported)) {
                                                nowPlayingModule.currentPlayer.position = nowPlayingModule.currentPosition
                                            }
                                            nowPlayingModule.scrubbing = false
                                        }
                                    }

                                    onWheel: function(wheel) {
                                        if (!nowPlayingModule.currentPlayer || nowPlayingModule.trackLength <= 0) return
                                        var delta = wheel.angleDelta.y > 0 ? 5 : -5
                                        var newPos = Math.max(0.0, Math.min(nowPlayingModule.trackLength, nowPlayingModule.currentPosition + delta))
                                        nowPlayingModule.currentPosition = newPos
                                        if (nowPlayingModule.currentPlayer.canSeek || nowPlayingModule.currentPlayer.positionSupported) {
                                            nowPlayingModule.currentPlayer.position = newPos
                                        }
                                    }
                                }
                            }

                            // Timestamps below the beginning and end of the seeker track
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 14

                                Text {
                                    id: posLabel
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: nowPlayingModule.formatTime(nowPlayingModule.currentPosition)
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                    color: Theme.textPrimary
                                    opacity: 0.65
                                }

                                Text {
                                    id: lenLabel
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: nowPlayingModule.trackLength > 0 ? nowPlayingModule.formatTime(nowPlayingModule.trackLength) : "--:--"
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                    color: Theme.textPrimary
                                    opacity: 0.65
                                }
                            }
                        }
                    }

                    // Metadata footer bar: Previous/Next + Artist & Album + Mute Button
                    Rectangle {
                        id: authorBar
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 28
                        color: Theme.bgBlurColor
                        bottomLeftRadius: carouselPanel.radius
                        bottomRightRadius: carouselPanel.radius
                        topLeftRadius: 0
                        topRightRadius: 0

                        InverseRadius {
                            anchors.bottom: authorBar.top
                            anchors.left: authorBar.left
                            cornerPosition: "bottomLeft"
                            color: authorBar.color
                            size: 8
                        }

                        InverseRadius {
                            cornerPosition: "bottomRight"
                            anchors.bottom: authorBar.top
                            anchors.right: authorBar.right
                            color: authorBar.color
                            size: 8
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            // Previous Button
                            ModuleButton {
                                id: prevBtn
                                variant: "dark"
                                cursorShape: (currentPlayer && currentPlayer.canGoPrevious !== false) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                textFont: 13
                                implicitHeight: 22
                                implicitWidth: 22
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                Layout.alignment: Qt.AlignVCenter
                                bottomLeftRadius: 11
                                topLeftRadius: 11

                                label: "󰙣"
                                textColor: (currentPlayer && currentPlayer.canGoPrevious !== false) ? Theme.textPrimary : Theme.statusDisabled
                                opacity: (currentPlayer && currentPlayer.canGoPrevious !== false) ? 1.0 : 0.45

                                onClicked: nowPlayingModule.doPrevious()
                            }

                            // Next Button
                            ModuleButton {
                                id: nextBtn
                                variant: "dark"
                                cursorShape: (currentPlayer && currentPlayer.canGoNext !== false) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                textFont: 13
                                implicitHeight: 22
                                implicitWidth: 22
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                Layout.alignment: Qt.AlignVCenter
                                Layout.leftMargin: - 8
                                bottomRightRadius: 11
                                topRightRadius: 11

                                label: "󰙡"
                                textColor: (currentPlayer && currentPlayer.canGoNext !== false) ? Theme.textPrimary : Theme.statusDisabled
                                opacity: (currentPlayer && currentPlayer.canGoNext !== false) ? 1.0 : 0.45

                                onClicked: nowPlayingModule.doNext()
                            }

                            HoverMarqueeText {
                                id: scrollingAuthorText
                                clip: true
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter

                                text: {
                                    var art = nowPlayingModule.authorText
                                    var alb = nowPlayingModule.albumText
                                    if (art && alb && art !== alb) return art + " — " + alb
                                    if (art) return art
                                    if (alb) return alb
                                    return nowPlayingModule.getPlayerName(nowPlayingModule.currentPlayer)
                                }
                                textMaxWidth: 150
                                fontFamily: Theme.font
                                pixelSize: Theme.fontSize - 2
                                textColor: Theme.textPrimary
                                opacity: 0.9
                                fontBold: false
                            }

                            // Mute / Volume Button
                            ModuleButton {
                                id: volumeBtn
                                variant: "dark"
                                cursorShape: Qt.PointingHandCursor
                                textFont: 13
                                implicitHeight: 22
                                implicitWidth: 22
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                Layout.alignment: Qt.AlignVCenter
                                radius: 11

                                label: {
                                    if (!currentPlayer || !currentPlayer.volumeSupported) return ""
                                    var v = currentPlayer.volume !== undefined ? currentPlayer.volume : 1.0
                                    if (v <= 0.01) return "󰖁"
                                    if (v < 0.33) return ""
                                    if (v < 0.66) return ""
                                    return ""
                                }
                                textColor: (currentPlayer && currentPlayer.volumeSupported && currentPlayer.volume <= 0.01)
                                    ? Theme.statusRed : Theme.textPrimary
                                opacity: (currentPlayer && currentPlayer.volumeSupported) ? 1.0 : 0.6

                                onClicked: nowPlayingModule.toggleMute()

                                WheelHandler {
                                    onWheel: function(event) {
                                        nowPlayingModule.changeVolume(event.angleDelta.y > 0 ? 0.05 : -0.05)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
