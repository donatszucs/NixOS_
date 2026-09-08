// Now Playing module — title + hover-to-reveal play/pause & skip controls
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
    property string playPauseIcon: "󰐊"
    property bool isPlaying: false
    expanded: isPlaying && expandHover.hovered

    property var currentPlayer: null
    property var manualPlayerOverride: null
    property int playerCount: 0
    property var playersList: []

    // Guard flag to prevent carousel ↔ player feedback loops
    property bool _syncingCarousel: false

    property real expandedHeight: 220

    implicitHeight: expanded ? expandedHeight + 20 : Theme.moduleHeight
    implicitWidth: expanded ? 270 : titleBtn.implicitWidth + 10

    // ── Helper: reset to idle state ──────────────────────────────
    function resetState() {
        currentPlayer = null
        manualPlayerOverride = null
        playerCount = 0
        playersList = []
        isPlaying = false
        titleText = "Nothing playing"
        authorText = "Unknown artist"
        playPauseIcon = "󰐊"
    }

    // ── Helper: sync UI from currentPlayer ──────────────────────
    function updateFromPlayer() {
        if (!currentPlayer) {
            isPlaying = false
            titleText = "Nothing playing"
            authorText = "Unknown artist"
            playPauseIcon = "󰐊"
            return
        }
        playPauseIcon = currentPlayer.isPlaying ? "󰏤" : "󰐊"
        isPlaying = true
        titleText = currentPlayer.trackTitle || "Nothing playing"
        authorText = currentPlayer.trackArtist || "Unknown artist"
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
        // Browsers often emit a duplicate media session with no artwork and
        // no artist (just a title, sometimes with notification counts).
        // A player is a ghost if it lacks art/artist AND its title overlaps
        // with the title of a real player.
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

        // Only reassign playersList when the set of players actually changed.
        // This prevents the ListView model from resetting every poll tick,
        // which would destroy currentIndex / scroll position.
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

        // Sync carousel index to match the picked player (without triggering
        // the onCurrentIndexChanged → pickPlayer feedback loop).
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
        if (currentPlayer && currentPlayer.togglePlaying)
            currentPlayer.togglePlaying()
    }
    function doNext() {
        if (currentPlayer && currentPlayer.next)
            currentPlayer.next()
    }
    function focusNow() {
        if (!currentPlayer) return
        var id = currentPlayer.identity.toLowerCase().trim()
        var cls = id.match(/mozilla zen/) ? "zen" : id
        var safeCls = cls.replace(/'/g, "\\'")
        Hyprland.dispatch("hl.dsp.focus({ window = 'class:(?i)" + safeCls + "' })")
    }

    // ── Polling ─────────────────────────────────────────────────
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
        anchors.bottomMargin: 10
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

                    // Show shared art cropped into the title bar shape
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

                    label: "󰎆"
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
            implicitWidth: nowPlayingModule.expanded ? 250 : titleBtn.implicitWidth
            implicitHeight: nowPlayingModule.expanded ? nowPlayingModule.expandedHeight : 0

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
                anchors.centerIn: parent
                width: trackArt.implicitWidth
                height: trackArt.implicitHeight

                // Apply opacity via the layer effect
                layer.enabled: true
                layer.smooth: true
                layer.effect: MultiEffect {
                    opacity: 0.9
                }

                // Multi-player: carousel (also used for single player)
                ListView {
                    id: playerCarousel
                    anchors.fill: parent
                    anchors.topMargin: Theme.moduleHeight + 10
                    anchors.bottomMargin: Theme.moduleHeight + 10
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

                            // Wrapper item for the delegate
                            Item {
                                id: delegateWrapper
                                anchors.fill: parent

                                // Calculate the fitted dimensions to perfectly wrap the image aspect ratio
                                property real imgAspect: (delegateImg.implicitWidth > 0 && delegateImg.implicitHeight > 0) ? delegateImg.implicitWidth / delegateImg.implicitHeight : 1.0
                                property real targetW: Math.min(width, height * imgAspect)
                                property real targetH: Math.min(height, width / imgAspect)

                                // The actual image container, perfectly fitted to the image
                                Item {
                                    id: delegateImgContainer
                                    anchors.centerIn: parent
                                    width: delegateRoot.hasArt ? delegateWrapper.targetW : Math.min(parent.width, parent.height)
                                    height: delegateRoot.hasArt ? delegateWrapper.targetH : Math.min(parent.width, parent.height)

                                    // Apply shadow via the layer effect
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
                                        // Since the container is mathematically fitted, Crop behaves identically to Fit but fills the bounds
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
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    visible: nowPlayingModule.playerCount > 1
                    acceptedButtons: Qt.NoButton
                    onWheel: function(wheel) {
                        if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
                            if (playerCarousel.currentIndex > 0)
                                playerCarousel.decrementCurrentIndex()
                        } else {
                            if (playerCarousel.currentIndex < playerCarousel.count - 1)
                                playerCarousel.incrementCurrentIndex()
                        }
                    }
                }

                // Bottom controls row
                RowLayout {
                    id: controlsRow
                    spacing: 0
                    layoutDirection: Qt.RightToLeft
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 0
                    anchors.horizontalCenter: parent.horizontalCenter

                    ModuleButton {
                        id: artHover
                        variant: "neutral"
                        implicitHeight: Theme.moduleHeight - 10
                        bottomRightRadius: Theme.moduleEdgeRadius - 5
                        topRightRadius: Theme.moduleEdgeRadius - 5
                        visible: nowPlayingModule.authorText !== ""
                        implicitWidth: nowPlayingModule.expanded
                            ? scrollingAuthorText.implicitWidth + 20 : 0

                        HoverMarqueeText {
                            id: scrollingAuthorText
                            clip: true
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            text: nowPlayingModule.authorText
                            textMaxWidth: albumArtClip.width - 30
                                - nextButton.implicitWidth
                                - playPauseButton.implicitWidth
                            fontFamily: Theme.font
                            pixelSize: Theme.fontSize
                            textColor: Theme.textPrimary
                            fontBold: false
                        }
                    }

                    ModuleButton {
                        id: nextButton
                        cursorShape: Qt.PointingHandCursor
                        variant: "neutral"
                        textFont: 18
                        implicitHeight: Theme.moduleHeight - 10
                        implicitWidth: (nowPlayingModule.expanded
                            && currentPlayer && currentPlayer.canGoNext)
                            ? Theme.moduleHeight : 0

                        label: "󰒭"
                        onClicked: nowPlayingModule.doNext()

                        Behavior on implicitWidth {
                            NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
                        }
                    }

                    ModuleButton {
                        id: playPauseButton
                        cursorShape: Qt.PointingHandCursor
                        variant: "neutral"
                        textFont: 18
                        implicitHeight: Theme.moduleHeight - 10
                        implicitWidth: nowPlayingModule.expanded ? Theme.moduleHeight : 0

                        label: nowPlayingModule.playPauseIcon
                        topLeftRadius: Theme.moduleEdgeRadius - 5
                        bottomLeftRadius: Theme.moduleEdgeRadius - 5
                        onClicked: nowPlayingModule.doTogglePlay()

                        Behavior on implicitWidth {
                            NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
                        }
                        clip: true
                    }
                }
            }
        }
    }
}
