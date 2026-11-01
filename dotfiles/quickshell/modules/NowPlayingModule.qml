// Now Playing module — title + hover-to-reveal controls, scrubber & multi-player carousel
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import QtQuick.Effects

import "../elements"

ExpandableModule {
    id: nowPlayingModule
    collapsedBottomRightRadius: Theme.moduleEdgeRadius
    extraHovered: collapsedRowHover.hovered || collapsedTitleText.hovered

    property string titleText: "Nothing playing"
    property string authorText: "Unknown artist"
    property string albumText: ""
    property string playPauseIcon: ""
    property string defaultPlayerIcon: "󰎆"
    property string defaultPlayerIconSource: ""

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

    readonly property bool isNothingPlaying: !hasPlayer || titleText === "Nothing playing"
    readonly property bool showPlayerIcon: expanded || !isNothingPlaying

    onHasPlayerChanged: {
        if (!hasPlayer && nowPlayingModule.expanded) {
            nowPlayingModule.expanded = false
        }
    }

    onExpandedChanged: {
        if (expanded && !hasPlayer) {
            expanded = false
        }
    }

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

    // ── Derived capability flags (avoid repeating long expressions) ──
    readonly property bool canPrev: currentPlayer && currentPlayer.canGoPrevious !== false
    readonly property bool canNext: currentPlayer && currentPlayer.canGoNext !== false
    readonly property bool canSeek: currentPlayer && (currentPlayer.canSeek || currentPlayer.positionSupported) && trackLength > 0

    pillPercent: expanded ? 0 : (trackLength > 0 ? Math.round((currentPosition / trackLength) * 100) : 0)
    pillVariant: expanded ? "neutral" : "dark"
    pillBorderColor: expanded ? null : Qt.darker(Theme.palette("light").border, 1.2)
    pillFillColor: expanded ? null : Qt.darker(Theme.palettePaper, 1.4)
    pillColorOpacity: 1.0
    pillBgImageSource: currentPlayer && currentPlayer.trackArtUrl ? currentPlayer.trackArtUrl : ""
    pillBgImageBrightness: 0.3
    pillBgImageOpacity: 0.4

    property int cardWidth: 260
    property real cardHeight: 298

    implicitHeight: expanded ? cardHeight + Theme.moduleHeight + nowPlayingModule.titleBarHeight + 15 : Theme.moduleHeight

    readonly property real mediaNaturalWidth: Math.max(70, Math.min(200, Math.round(collapsedRow.implicitWidth + 26)))
    property real lastCollapsedWidth: 100
    onMediaNaturalWidthChanged: {
        if (!expanded && mediaNaturalWidth > 70) {
            lastCollapsedWidth = mediaNaturalWidth
        }
    }
    collapsedWidth: expanded ? lastCollapsedWidth : mediaNaturalWidth

    // Overlay dropdown setup
    expandedDropdownWidth: cardWidth + 30

    dropdownAlignment: "right"

    leftCornerStyle: "side"
    rightCornerStyle: "top"

    onPillRightClicked: {
        nowPlayingModule.doTogglePlay()
    }

    onPillWheel: (wheel) => {
        nowPlayingModule.changeVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
        wheel.accepted = true
    }

    // ── Helper: time formatter (seconds -> [[y:]d:]h:mm:ss) ───────
    function formatTime(seconds, forceHours, forceDays) {
        if (isNaN(seconds) || seconds === undefined || seconds === null || seconds < 0) {
            if (forceDays) return "0d 00:00:00"
            if (forceHours) return "0:00:00"
            return "0:00"
        }
        var totalSec = Math.floor(seconds)
        var years = Math.floor(totalSec / 31536000)
        var remSec = totalSec % 31536000
        var days = Math.floor(remSec / 86400)
        remSec = remSec % 86400
        var hours = Math.floor(remSec / 3600)
        var mins = Math.floor((remSec % 3600) / 60)
        var secs = remSec % 60

        var pad2 = function(n) { return (n < 10 ? "0" : "") + n }

        var prefix = ""
        if (years > 0) {
            prefix = years + "y " + days + "d "
        } else if (days > 0 || forceDays) {
            prefix = days + "d "
        }

        if (prefix !== "") {
            return prefix + pad2(hours) + ":" + pad2(mins) + ":" + pad2(secs)
        }

        if (hours > 0 || forceHours) {
            return hours + ":" + pad2(mins) + ":" + pad2(secs)
        }
        return mins + ":" + pad2(secs)
    }

    // ── Helper: player icon resolver (dynamic from MPRIS API & theme) ──
    function getPlayerIconSource(player) {
        if (!player) return defaultPlayerIconSource

        var candidates = []

        if (player.desktopEntry) {
            candidates.push(player.desktopEntry)
            candidates.push(player.desktopEntry.toLowerCase())
        }

        if (player.identity) {
            var idLower = player.identity.toLowerCase()
            candidates.push(idLower)
            var firstWord = idLower.split(/\s+/)[0]
            if (firstWord !== idLower) candidates.push(firstWord)
        }

        if (player.dbusName) {
            var prefix = "org.mpris.MediaPlayer2."
            if (player.dbusName.indexOf(prefix) === 0) {
                var clean = player.dbusName.substring(prefix.length).split(".")[0].toLowerCase()
                candidates.push(clean)
            }
        }

        for (var i = 0; i < candidates.length; i++) {
            var c = candidates[i]
            if (c && Quickshell.hasThemeIcon(c)) {
                return Quickshell.iconPath(c)
            }
        }

        return ""
    }

    function getPlayerIcon(player) {
        if (!player) return ""
        return getPlayerIconSource(player) !== "" ? "" : defaultPlayerIcon
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

        // Filter out phantom/ghost MPRIS instances (bare duplicates of real players).
        // First, collect titles from "real" players (those with art or artist metadata).
        var realTitles = []
        for (var ri = 0; ri < raw.length; ri++) {
            if (raw[ri].trackArtUrl || (raw[ri].trackArtist || "").trim())
                realTitles.push((raw[ri].trackTitle || "").trim())
        }

        var players = []
        for (var fi = 0; fi < raw.length; fi++) {
            var fp = raw[fi]
            // Keep players that have metadata (art or artist)
            if (fp.trackArtUrl || (fp.trackArtist || "").trim()) {
                players.push(fp)
                continue
            }
            // For bare players, check if their title overlaps a real player's title
            var fTitle = (fp.trackTitle || "").trim()
            var dominated = false
            if (fTitle) {
                for (var r = 0; r < realTitles.length; r++) {
                    if (realTitles[r] && (fTitle.indexOf(realTitles[r]) !== -1 || realTitles[r].indexOf(fTitle) !== -1)) {
                        dominated = true
                        break
                    }
                }
            }
            if (!dominated) players.push(fp)
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

        if (currentPlayer.canTogglePlaying || currentPlayer.togglePlaying) {
            currentPlayer.togglePlaying()
        } else if (currentPlayer.isPlaying && (currentPlayer.canPause || currentPlayer.pause)) {
            currentPlayer.pause()
        } else if (!currentPlayer.isPlaying && (currentPlayer.canPlay || currentPlayer.play)) {
            currentPlayer.play()
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

    function changeVolume(delta) {
        if (!currentPlayer || !currentPlayer.volumeSupported) return
        var currentVol = currentPlayer.volume !== undefined ? currentPlayer.volume : 1.0
        var newVol = Math.max(0.0, Math.min(1.0, currentVol + delta))
        currentPlayer.volume = Math.round(newVol * 100) / 100
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

    // Position updater: active whenever playing (updates scrubber & collapsed progress pill)
    Timer {
        id: positionTimer
        interval: 350
        running: nowPlayingModule.currentPlayer !== null && nowPlayingModule.currentPlayer.isPlaying
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
            color: Qt.rgba(Theme.paletteInk.r, Theme.paletteInk.g, Theme.paletteInk.b, 0.25)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(16, Math.round((parent.height - 52 - height) / 2))
                text: "󰎆"
                font.family: Theme.font
                font.pixelSize: 42
                color: Theme.palette("dark").text
                opacity: 0.35
            }
        }
    }


    // ── Header Content (Icon + Track Title, always visible in headerPill) ──
    RowLayout {
        id: collapsedRow
        parent: nowPlayingModule
        anchors.horizontalCenter: nowPlayingModule.headerPill.horizontalCenter
        anchors.verticalCenter: nowPlayingModule.expanded
            ? nowPlayingModule.headerPill.top
            : nowPlayingModule.headerPill.verticalCenter
        anchors.verticalCenterOffset: nowPlayingModule.expanded
            ? Math.round(nowPlayingModule.titleBarHeight / 2)
            : 0
        spacing: nowPlayingModule.expanded ? 8 : (nowPlayingModule.showPlayerIcon ? 6 : 0)
        z: 10

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.85)
            shadowBlur: 0.6
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
        }

        HoverHandler {
            id: collapsedRowHover
        }

        Behavior on anchors.verticalCenterOffset {
            NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
        }
        Behavior on spacing {
            NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
        }

        Item {
            id: collapsedIconItem
            visible: nowPlayingModule.showPlayerIcon
            implicitWidth: visible ? (nowPlayingModule.expanded ? 18 : 16) : 0
            implicitHeight: visible ? (nowPlayingModule.expanded ? 18 : 16) : 0
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: visible ? 4 : 0

            Behavior on implicitWidth {
                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
            }
            Behavior on implicitHeight {
                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
            }

            Image {
                id: collapsedAppIcon
                anchors.fill: parent
                sourceSize.width: 36
                sourceSize.height: 36
                fillMode: Image.PreserveAspectFit
                smooth: true
                source: nowPlayingModule.getPlayerIconSource(nowPlayingModule.currentPlayer)
                visible: status === Image.Ready && source != ""
            }

            Text {
                anchors.centerIn: parent
                text: nowPlayingModule.getPlayerIcon(nowPlayingModule.currentPlayer)
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: nowPlayingModule.expanded ? Theme.fontSize + 1 : Theme.fontSize
                visible: !collapsedAppIcon.visible
            }
        }

        HoverMarqueeText {
            id: collapsedTitleText
            clip: true
            Layout.alignment: Qt.AlignVCenter
            text: nowPlayingModule.titleText
            textMaxWidth: nowPlayingModule.expanded ? 210 : 150
            fontFamily: Theme.font
            pixelSize: nowPlayingModule.expanded ? Theme.fontSize : Theme.fontSize - 1
            textColor: Theme.textPrimary
            fontBold: true
            horizontalAlignment: nowPlayingModule.isNothingPlaying ? Text.AlignHCenter : Text.AlignLeft
        }
    }

    // ── Expanded card / aspect-preserving art / overlaid controls ──
    ColumnLayout {
        id: baseColumn
        parent: nowPlayingModule.overlay
        spacing: 10
        anchors {
            top: parent.top
            topMargin: nowPlayingModule.titleBarHeight
            horizontalCenter: parent.horizontalCenter
        }

        scale: expanded ? 1 : 0
        transformOrigin: Item.Top
        Behavior on scale { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

        MouseArea {
            visible: nowPlayingModule.contentVisible
            opacity: nowPlayingModule.contentOpacity
            implicitWidth: nowPlayingModule.cardWidth
            Layout.preferredWidth: nowPlayingModule.cardWidth
            implicitHeight: nowPlayingModule.cardHeight
            Layout.preferredHeight: nowPlayingModule.cardHeight
            Layout.alignment: Qt.AlignHCenter
            acceptedButtons: Qt.NoButton

            BaseCard {
                id: carouselPanel
                anchors.fill: parent

                // Artwork stage above authorBar (fixed 256×256 box; only the image changes size per aspect ratio)
                Item {
                    id: artStage
                    anchors.top: parent.top
                    anchors.topMargin: carouselPanel.border.width
                    anchors.left: parent.left
                    anchors.leftMargin: carouselPanel.border.width
                    anchors.right: parent.right
                    anchors.rightMargin: carouselPanel.border.width
                    anchors.bottom: authorBar.top
                    clip: true

                    ListView {
                        id: playerCarousel
                        anchors.fill: parent
                        model: nowPlayingModule.playersList
                        orientation: ListView.Horizontal
                        interactive: nowPlayingModule.playerCount > 1
                        boundsBehavior: Flickable.StopAtBounds
                        preferredHighlightBegin: 0
                        preferredHighlightEnd: width
                        highlightRangeMode: ListView.StrictlyEnforceRange
                        snapMode: ListView.SnapOneItem
                        highlightMoveDuration: 240
                        spacing: 0

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

                        delegate: Item {
                            id: delegateRoot
                            required property var modelData
                            required property int index

                            width: playerCarousel.width
                            height: playerCarousel.height

                            readonly property real itemCenter: x + width / 2
                            readonly property real viewCenter: playerCarousel.contentX + playerCarousel.width / 2
                            readonly property real absDist: playerCarousel.width > 0
                                ? Math.min(1.0, Math.abs(itemCenter - viewCenter) / playerCarousel.width)
                                : 0.0
                            readonly property bool hasArt: !!(modelData && modelData.trackArtUrl)
                            readonly property bool artReady: hasArt && delegateImg.status === Image.Ready

                            // Compute native aspect ratio of this player's thumbnail without resizing the card
                            readonly property real imgAspect: (artReady && delegateImg.implicitWidth > 0 && delegateImg.implicitHeight > 0)
                                ? Math.max(0.65, Math.min(2.4, delegateImg.implicitWidth / delegateImg.implicitHeight))
                                : 1.0
                            readonly property real targetW: artReady
                                ? Math.round(Math.min(width, height * imgAspect))
                                : width
                            readonly property real targetH: artReady
                                ? Math.round(Math.min(height, width / imgAspect))
                                : height
                            readonly property real freeTopH: Math.max(120, height - (nowPlayingModule.playerCount > 1 ? 64 : 48))
                            readonly property real targetY: Math.round(Math.max(0, (freeTopH - targetH) / 2))

                            // Soft SDF alpha mask sized to the thumbnail's exact aspect-ratio bounds
                            Item {
                                id: delegateMask
                                anchors.fill: delegateImgContainer
                                visible: false
                                layer.enabled: width > 0 && height > 0
                                layer.smooth: true

                                RectangularShadow {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    radius: Theme.cardRadius - 3
                                    blur: 15
                                    spread: 0
                                    color: "white"
                                }
                            }

                            Item {
                                id: delegateImgContainer
                                width: delegateRoot.targetW
                                height: delegateRoot.targetH
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: delegateRoot.targetY
                                scale: 1.0 - 0.04 * delegateRoot.absDist
                                opacity: 1.0 - 0.35 * delegateRoot.absDist
                                clip: true

                                layer.enabled: width > 0 && height > 0
                                layer.smooth: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: delegateMask
                                    maskThresholdMin: 0.52
                                    maskSpreadAtMin: 0.96
                                }

                                Loader {
                                    anchors.fill: parent
                                    sourceComponent: artPlaceholder
                                    active: !delegateRoot.artReady
                                    visible: active
                                }

                                Image {
                                    id: delegateImg
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    source: delegateRoot.hasArt ? modelData.trackArtUrl : ""
                                    // Only constrain width so Qt preserves the image's exact native aspect ratio
                                    sourceSize.width: 560
                                    asynchronous: true
                                    smooth: true
                                    mipmap: true
                                    opacity: delegateRoot.artReady ? 1.0 : 0.0

                                    Behavior on opacity {
                                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                    }
                                }

                                // Smooth dark fade at bottom only when tall/square art extends behind middleControls
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: Math.min(parent.height, 92)
                                    opacity: delegateRoot.artReady
                                        ? Math.max(0.0, Math.min(1.0, ((delegateImgContainer.y + delegateImgContainer.height) - (delegateRoot.freeTopH - 6)) / 36))
                                        : 0.0
                                    visible: opacity > 0.01
                                    gradient: Gradient {
                                        orientation: Gradient.Vertical
                                        GradientStop {
                                            position: 0.0
                                            color: "transparent"
                                        }
                                        GradientStop {
                                            position: 0.55
                                            color: Qt.rgba(Theme.paletteInk.r, Theme.paletteInk.g, Theme.paletteInk.b, 0.48)
                                        }
                                        GradientStop {
                                            position: 1.0
                                            color: Qt.rgba(Theme.paletteInk.r, Theme.paletteInk.g, Theme.paletteInk.b, 0.84)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Playback & seeker controls overlaid on the stage above authorBar
                Item {
                    id: controlsOverlay
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: authorBar.top
                    z: 20

                    // Wheel over open artwork area: multi-player switches player; single player adjusts volume
                    MouseArea {
                        anchors.top: parent.top
                        anchors.topMargin: 6
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: carouselIndicators.visible ? carouselIndicators.top : middleControls.top
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

                    // Carousel Pagination Dots (clean, borderless)
                    Item {
                        id: carouselIndicators
                        anchors.bottom: middleControls.top
                        anchors.bottomMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: indicatorsRow.width
                        height: 12
                        visible: opacity > 0
                        opacity: (nowPlayingModule.playerCount > 1) ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }

                        Row {
                            id: indicatorsRow
                            anchors.centerIn: parent
                            spacing: 4

                            Repeater {
                                model: nowPlayingModule.playersList

                                Item {
                                    id: dotDelegate
                                    required property var modelData
                                    required property int index

                                    readonly property bool isActive: index === playerCarousel.currentIndex

                                    width: isActive ? 18 : 9
                                    height: 12

                                    Behavior on width {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                    }

                                    Rectangle {
                                        id: dotVisual
                                        anchors.centerIn: parent
                                        width: dotDelegate.isActive ? 14 : 5
                                        height: 5
                                        radius: 2.5
                                        color: dotDelegate.isActive ? Theme.palette("light").base : Theme.textPrimary
                                        opacity: dotDelegate.isActive ? 1.0 : (dotMouseArea.containsMouse ? 0.75 : 0.38)

                                        Behavior on width {
                                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                        }
                                        Behavior on opacity {
                                            NumberAnimation { duration: 150 }
                                        }
                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }

                                    MouseArea {
                                        id: dotMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (playerCarousel.currentIndex !== dotDelegate.index) {
                                                playerCarousel.currentIndex = dotDelegate.index
                                            }
                                        }
                                        onWheel: function(wheel) {
                                            if (nowPlayingModule.playerCount > 1) {
                                                if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
                                                    if (playerCarousel.currentIndex > 0)
                                                        playerCarousel.decrementCurrentIndex()
                                                } else {
                                                    if (playerCarousel.currentIndex < playerCarousel.count - 1)
                                                        playerCarousel.incrementCurrentIndex()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Middle Controls: Play/Pause + Clean Borderless Pill Seeker & Timestamps
                    RowLayout {
                        id: middleControls
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.bottomMargin: 28
                        spacing: 10
                        height: 34

                        // Play / Pause Button (standard "light" / "neutral" module palette, borderless)
                        ModuleButton {
                            id: playPauseBtn
                            variant: nowPlayingModule.isMediaPlaying ? "light" : "neutral"
                            cursorShape: Qt.PointingHandCursor
                            textFont: 30
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 46
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: false
                            radius: 23
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
                            spacing: 1

                            // Seeker Track (borderless pill bar matching StyledSlider aesthetic)
                            Item {
                                id: seekTrack
                                Layout.fillWidth: true
                                implicitHeight: 16

                                property real progressRatio: {
                                    if (nowPlayingModule.trackLength > 0) {
                                        return Math.max(0.0, Math.min(1.0, nowPlayingModule.currentPosition / nowPlayingModule.trackLength))
                                    }
                                    return 0.0
                                }

                                Rectangle {
                                    id: seekGroove
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: (seekMouseArea.containsMouse || nowPlayingModule.scrubbing) ? 7 : 5
                                    radius: height / 2
                                    color: Theme.palette("neutral").base
                                    clip: true

                                    Behavior on height {
                                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width * seekTrack.progressRatio
                                        radius: parent.radius
                                        color: nowPlayingModule.scrubbing
                                            ? Theme.palette("light").pressed
                                            : Theme.palette("light").base

                                        Behavior on width {
                                            enabled: !nowPlayingModule.scrubbing
                                            NumberAnimation { duration: 150; easing.type: Easing.Linear }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: seekMouseArea
                                    anchors.fill: parent
                                    anchors.topMargin: -4
                                    anchors.bottomMargin: -4
                                    hoverEnabled: true
                                    cursorShape: nowPlayingModule.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor

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
                                id: timestampRow
                                Layout.fillWidth: true
                                implicitHeight: Math.max(posLabel.implicitHeight, lenLabel.implicitHeight, 14)

                                readonly property real gap: 6
                                readonly property real availWidth: Math.max(0, width - gap)
                                readonly property real halfWidth: availWidth / 2

                                Text {
                                    id: posLabel
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: {
                                        if (timestampRow.availWidth <= 0) return 0
                                        var posReq = implicitWidth
                                        var lenReq = lenLabel.implicitWidth
                                        if (posReq + lenReq <= timestampRow.availWidth) return posReq
                                        if (lenReq < timestampRow.halfWidth) return timestampRow.availWidth - lenReq
                                        if (posReq < timestampRow.halfWidth) return posReq
                                        return timestampRow.halfWidth
                                    }
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideRight
                                    text: nowPlayingModule.formatTime(nowPlayingModule.currentPosition, nowPlayingModule.trackLength >= 3600, nowPlayingModule.trackLength >= 86400)
                                    font.family: Theme.font
                                    font.pixelSize: (nowPlayingModule.trackLength >= 31536000 || nowPlayingModule.currentPosition >= 31536000) ? 10 : 12
                                    color: Theme.textPrimary
                                    opacity: 0.65
                                }

                                Text {
                                    id: lenLabel
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: {
                                        if (timestampRow.availWidth <= 0) return 0
                                        var posReq = posLabel.implicitWidth
                                        var lenReq = implicitWidth
                                        if (posReq + lenReq <= timestampRow.availWidth) return lenReq
                                        if (posReq < timestampRow.halfWidth) return timestampRow.availWidth - posReq
                                        if (lenReq < timestampRow.halfWidth) return lenReq
                                        return timestampRow.halfWidth
                                    }
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideRight
                                    text: nowPlayingModule.trackLength > 0 ? nowPlayingModule.formatTime(nowPlayingModule.trackLength) : "--:--"
                                    font.family: Theme.font
                                    font.pixelSize: (nowPlayingModule.trackLength >= 31536000 || nowPlayingModule.currentPosition >= 31536000) ? 10 : 12
                                    color: Theme.textPrimary
                                    opacity: 0.65
                                }
                            }
                        }
                    }
                }

                // Bottom metadata bar with InverseRadius fillets (matching BaseCard headerBar across all modules)
                Rectangle {
                    id: authorBar
                    z: 25
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Theme.cardHeaderHeight
                    color: Theme.topBarBlurColor
                    bottomLeftRadius: carouselPanel.radius
                    bottomRightRadius: carouselPanel.radius
                    topLeftRadius: 0
                    topRightRadius: 0

                    InverseRadius {
                        anchors.bottom: authorBar.top
                        anchors.left: authorBar.left
                        cornerPosition: "bottomLeft"
                        color: authorBar.color
                        size: 15
                    }

                    InverseRadius {
                        cornerPosition: "bottomRight"
                        anchors.bottom: authorBar.top
                        anchors.right: authorBar.right
                        color: authorBar.color
                        size: 15
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        spacing: 6

                        // Previous Button
                        ModuleButton {
                            id: prevBtn
                            variant: "neutral"
                            cursorShape: nowPlayingModule.canPrev ? Qt.PointingHandCursor : Qt.ArrowCursor
                            textFont: 15
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 26
                            Layout.alignment: Qt.AlignVCenter
                            bottomLeftRadius: Theme.cardButtonRadius
                            topLeftRadius: Theme.cardButtonRadius
                            bottomRightRadius: 0
                            topRightRadius: 0

                            label: "󰙣"
                            textColor: nowPlayingModule.canPrev ? Theme.textPrimary : Theme.statusDisabled
                            opacity: nowPlayingModule.canPrev ? 1.0 : 0.45

                            onClicked: nowPlayingModule.doPrevious()
                        }

                        // Next Button
                        ModuleButton {
                            id: nextBtn
                            variant: "neutral"
                            cursorShape: nowPlayingModule.canNext ? Qt.PointingHandCursor : Qt.ArrowCursor
                            textFont: 15
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 26
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: -6
                            bottomRightRadius: Theme.cardButtonRadius
                            topRightRadius: Theme.cardButtonRadius
                            bottomLeftRadius: 0
                            topLeftRadius: 0

                            label: "󰙡"
                            textColor: nowPlayingModule.canNext ? Theme.textPrimary : Theme.statusDisabled
                            opacity: nowPlayingModule.canNext ? 1.0 : 0.45

                            onClicked: nowPlayingModule.doNext()
                        }

                        HoverMarqueeText {
                            id: scrollingAuthorText
                            clip: true
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter

                            text: {
                                var art = nowPlayingModule.authorText
                                var alb = nowPlayingModule.albumText
                                if (art && alb && art !== alb) return art + " — " + alb
                                if (art) return art
                                if (alb) return alb
                                return nowPlayingModule.getPlayerName(nowPlayingModule.currentPlayer)
                            }
                            textMaxWidth: 176
                            fontFamily: Theme.font
                            pixelSize: Theme.fontSize - 1
                            textColor: Theme.textPrimary
                            opacity: 0.9
                            fontBold: false
                        }
                    }
                }
            }
        }
    }
}
