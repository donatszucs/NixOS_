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
    property real _savedVolume: 0.5

    // ── Derived capability flags (avoid repeating long expressions) ──
    readonly property bool canPrev: currentPlayer && currentPlayer.canGoPrevious !== false
    readonly property bool canNext: currentPlayer && currentPlayer.canGoNext !== false
    readonly property bool canSeek: currentPlayer && (currentPlayer.canSeek || currentPlayer.positionSupported) && trackLength > 0
    readonly property bool hasVolume: currentPlayer && currentPlayer.volumeSupported

    pillPercent: expanded ? 0 : (trackLength > 0 ? Math.round((currentPosition / trackLength) * 100) : 0)
    pillVariant: expanded ? "neutral" : "dark"
    pillBorderColor: expanded ? null : Qt.darker(Theme.palette("light").border, 1.4)
    pillColorOpacity: 0.8
    pillBgImageSource: currentPlayer && currentPlayer.trackArtUrl ? currentPlayer.trackArtUrl : ""

    property int cardWidth: 260
    property real cardHeight: 260

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

    // ── Helper: time formatter (seconds -> mm:ss) ────────────────
    function formatTime(seconds) {
        if (isNaN(seconds) || seconds === undefined || seconds === null || seconds < 0) return "0:00"
        var totalSec = Math.floor(seconds)
        var mins = Math.floor(totalSec / 60)
        var secs = totalSec % 60
        return mins + ":" + (secs < 10 ? "0" : "") + secs
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

    function toggleMute() {
        if (!currentPlayer || !currentPlayer.volumeSupported) return
        if (currentPlayer.volume > 0.01) {
            nowPlayingModule._savedVolume = currentPlayer.volume
            currentPlayer.volume = 0.0
        } else {
            currentPlayer.volume = nowPlayingModule._savedVolume > 0.05 ? nowPlayingModule._savedVolume : 0.5
        }
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

    Component {
        id: cardShadowEffect
        MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.65)
            shadowBlur: 0.8
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
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
        spacing: nowPlayingModule.expanded ? 8 : 6
        z: 10

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
            implicitWidth: nowPlayingModule.expanded ? 18 : 16
            implicitHeight: nowPlayingModule.expanded ? 18 : 16
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 4

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
        }
    }

    // ── Expanded art / carousel / controls ──────────────────
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

            Rectangle {
                id: carouselPanel
                anchors.fill: parent
                color: Theme.bgBlurColor
                radius: Theme.moduleEdgeRadius / 2 + 10
                clip: true
                border.width: 2
                border.color: Theme.cardBorder

                layer.enabled: true
                layer.smooth: true
                layer.effect: cardShadowEffect
                    // Multi-player: carousel
                    ListView {
                        id: playerCarousel
                        anchors.top: parent.top
                        anchors.topMargin: 22
                        anchors.bottom: middleControls.top
                        anchors.bottomMargin: 35
                        anchors.left: parent.left
                        anchors.right: parent.right

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
                    spacing: -60

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
                            id: delegateWrapper
                            width: 200
                            height: playerCarousel.height
                            anchors.centerIn: parent

                            scale: 1.0 - 0.25 * delegateRoot.absDist
                                + Math.max(0, 1.0 - delegateRoot.absCenterDist / 50) * 0.05

                            transform: Translate {
                                x: -Math.pow(delegateRoot.effectiveNormDist, 3) * 130
                            }

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
                                    brightness: -delegateRoot.absDist * 0.35
                                    contrast: -delegateRoot.absDist * 0.8
                                    shadowEnabled: true
                                    shadowColor: "black"
                                    shadowBlur: 1.0
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

                                // Clicking art selects carousel item
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (playerCarousel.currentIndex !== index) {
                                            playerCarousel.currentIndex = index
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

                    // Carousel Pagination Dots (multi-source direction indicators)
                    Item {
                        id: carouselIndicators
                        anchors.top: playerCarousel.bottom
                        anchors.bottom: middleControls.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: indicatorsRow.width
                        visible: opacity > 0
                        opacity: (nowPlayingModule.playerCount > 1) ? 1.0 : 0.0
                        z: 10

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

                                    width: isActive ? 20 : 10
                                    height: 20

                                    Behavior on width {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                    }

                                    Rectangle {
                                        id: dotVisual
                                        anchors.centerIn: parent
                                        width: dotDelegate.isActive ? 16 : 6
                                        height: 6
                                        radius: 3
                                        color: dotDelegate.isActive ? Theme.light.base : Theme.textPrimary
                                        opacity: dotDelegate.isActive ? 1.0 : (dotMouseArea.containsMouse ? 0.75 : 0.35)

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
                        height: 35
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
                            size: 13
                        }

                        InverseRadius {
                            cornerPosition: "bottomRight"
                            anchors.bottom: authorBar.top
                            anchors.right: authorBar.right
                            color: authorBar.color
                            size: 13
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            // Previous Button
                            ModuleButton {
                                id: prevBtn
                                variant: "neutral"
                                cursorShape: nowPlayingModule.canPrev ? Qt.PointingHandCursor : Qt.ArrowCursor
                                textFont: 15
                                Layout.preferredWidth: 25
                                Layout.preferredHeight: 25
                                Layout.alignment: Qt.AlignVCenter
                                bottomLeftRadius: 11
                                topLeftRadius: 11

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
                                Layout.preferredWidth: 25
                                Layout.preferredHeight: 25
                                Layout.alignment: Qt.AlignVCenter
                                Layout.leftMargin: -6
                                bottomRightRadius: 11
                                topRightRadius: 11

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
                                textMaxWidth: 200
                                fontFamily: Theme.font
                                pixelSize: Theme.fontSize - 1
                                textColor: Theme.textPrimary
                                opacity: 0.9
                                fontBold: false
                            }

                            // Mute / Volume Button
                            ModuleButton {
                                id: volumeBtn
                                variant: "neutral"
                                cursorShape: Qt.PointingHandCursor
                                textFont: 15
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 25
                                Layout.alignment: Qt.AlignVCenter
                                radius: 11

                                label: {
                                    if (!nowPlayingModule.hasVolume) return ""
                                    var v = nowPlayingModule.currentPlayer.volume !== undefined ? nowPlayingModule.currentPlayer.volume : 1.0
                                    if (v <= 0.01) return "󰖁"
                                    if (v < 0.33) return ""
                                    if (v < 0.66) return ""
                                    return ""
                                }
                                textColor: (nowPlayingModule.hasVolume && currentPlayer.volume <= 0.01)
                                    ? Theme.statusRed : Theme.textPrimary
                                opacity: nowPlayingModule.hasVolume ? 1.0 : 0.6

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
