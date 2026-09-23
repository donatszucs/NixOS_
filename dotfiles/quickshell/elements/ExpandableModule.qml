// ExpandableModule.qml — Base for bar modules that expand downward with an overlay dropdown.
import QtQuick
import QtQuick.Layouts

ModuleButton {
    id: root

    property int expandedBottomLeftRadius:   Theme.moduleEdgeRadius + 10
    property int expandedBottomRightRadius:  Theme.moduleEdgeRadius + 10
    property int collapsedBottomLeftRadius:  0
    property int collapsedBottomRightRadius: 0

    bottomLeftRadius:  0
    bottomRightRadius: 0

    property real dropdownLeftOffset: {
        if (!contentVisible) return 0
        return _overlay.x
    }
    property real dropdownRightOffset: {
        if (!contentVisible) return 0
        return (_overlay.x + _overlay.width) - root.width
    }

    property real screenEdgeGap: 2 * Theme.moduleEdgeRadius
    readonly property real leftEdgeGap: (leftCornerStyle === "bottom") ? 0 : screenEdgeGap
    readonly property real rightEdgeGap: (rightCornerStyle === "bottom") ? 0 : screenEdgeGap

    readonly property bool touchesLeftEdge: {
        if (!contentVisible) return false
        var win = root.Window.window
        if (!win) return false
        try {
            var pt = root.mapToItem(null, 0, 0)
            return pt && (pt.x + _overlay.x <= root.leftEdgeGap + 1)
        } catch(e) { return false }
    }
    readonly property bool touchesRightEdge: {
        if (!contentVisible) return false
        var win = root.Window.window
        if (!win) return false
        try {
            var pt = root.mapToItem(null, 0, 0)
            return pt && (pt.x + _overlay.x + _overlay.width >= win.width - root.rightEdgeGap - 1)
        } catch(e) { return false }
    }

    readonly property bool touchesPhysicalLeftEdge: {
        if (!contentVisible) return false
        var win = root.Window.window
        if (!win) return false
        try {
            var pt = root.mapToItem(null, 0, 0)
            return pt && (pt.x + _overlay.x <= 1)
        } catch(e) { return false }
    }
    readonly property bool touchesPhysicalRightEdge: {
        if (!contentVisible) return false
        var win = root.Window.window
        if (!win) return false
        try {
            var pt = root.mapToItem(null, 0, 0)
            return pt && (pt.x + _overlay.x + _overlay.width >= win.width - 1)
        } catch(e) { return false }
    }

    // Corner styles: "side" (fillet under bar) | "bottom" (screen bezel) | "top" (protruding top) | "none"
    property string leftCornerStyle:  "side"
    property string rightCornerStyle: "side"
    property int inverseCornerSize: Theme.moduleEdgeRadius
    property bool inverseCornerSmoothCurve: false
    property real inverseCornerSmoothTolerance: 0.15
    readonly property bool hasOwnInverseCorners: true
    readonly property bool hasProtrudingCorners: (leftCornerStyle === "bottom" || rightCornerStyle === "bottom" || leftCornerStyle === "top" || rightCornerStyle === "top")

    property alias flowingBackground: _flowingBg
    property alias overlayBackground: _flowingBg
    property alias leftSideCorner:     _flowingBg
    property alias rightSideCorner:    _flowingBg
    property alias leftBottomCorner:   _flowingBg
    property alias rightBottomCorner:  _flowingBg
    property alias leftTopCorner:      _flowingBg
    property alias rightTopCorner:     _flowingBg

    // Title bar configuration
    property int titleBarHeight: useDefaultPill ? Theme.moduleHeight *1.6 : 0

    property bool shrinkEnabled: true
    property int shrinkAmount: 10
    property int collapsedWidth: expanded ? lastPillWidth : pillNaturalWidth
    implicitWidth: (root.expanded && shrinkEnabled) ? 100 : collapsedWidth

    // Close button configuration for bar tab
    property bool showCloseButton: shrinkEnabled
    property string closeButtonText: "Close"
    property alias barTabCloseButton: _closeButtonBg

    clip: false
    noHoverColorChange: expanded
    noPressColorChange: expanded
    color: "transparent"

    // Unified flowing background that seamlessly renders the header pill,
    // side inverse-radius fillets, dropdown body, and bezel corners as one continuous piece.
    FlowingBackground {
        id: _flowingBg
        headerWidth: root.width
        headerHeight: Theme.moduleHeight
        overlayX: _overlay.x
        overlayWidth: _overlay.width
        overlayHeight: _overlay.height
        contentVisible: root.contentVisible

        cornerRadius: root.inverseCornerSize
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.collapsedBottomLeftRadius
        bottomRightRadius: root.collapsedBottomRightRadius
        collapsedBottomLeftRadius: root.collapsedBottomLeftRadius
        collapsedBottomRightRadius: root.collapsedBottomRightRadius
        expandedBottomLeftRadius: (root.touchesPhysicalLeftEdge && root.leftCornerStyle === "bottom") ? 0 : root.expandedBottomLeftRadius
        expandedBottomRightRadius: (root.touchesPhysicalRightEdge && root.rightCornerStyle === "bottom") ? 0 : root.expandedBottomRightRadius

        leftCornerStyle: root.leftCornerStyle
        rightCornerStyle: root.rightCornerStyle
        touchesLeftEdge: root.touchesPhysicalLeftEdge
        touchesRightEdge: root.touchesPhysicalRightEdge

        color: (root.expanded || root.noHoverColorChange) ? root.baseColor : root.colorAdaptive
        dontAnimateColor: root.dontAnimateColor

        HoverHandler {
            id: _flowingBgHover
        }
    }

    // Render above RowLayout siblings when expanded so overlay is on top (and during collapse animation)
    z: (SharedState.activeModule === root) ? 20 : (contentVisible ? 10 : 0)

    // ── Hover collapse ───────────────────────────────────────────
    // Set collapseOnHoverExit to false for modules that manage their
    // own collapse logic (e.g. TrayModule with open menus).
    property bool collapseOnHoverExit: true

    // Expose the handler so modules can reference it (e.g. NowPlaying
    // binds expanded to isPlaying && isHovered).
    property alias expandHover: _expandHover

    // Combined hover state: true when mouse is over the pill, overlay, flowing background, or bar tab close button
    readonly property bool rawHovered: _expandHover.hovered || _overlayHover.hovered || _flowingBgHover.hovered || _headerPillHover.hovered || (_barTabMouseArea.containsMouse && root.expanded)
    property bool isHovered: rawHovered || _hoverGraceTimer.running

    Timer {
        id: _hoverGraceTimer
        interval: 120
    }

    onRawHoveredChanged: {
        if (!rawHovered && expanded) {
            _hoverGraceTimer.restart()
        } else if (rawHovered) {
            _hoverGraceTimer.stop()
        }
    }

    HoverHandler {
        id: _expandHover
    }

    onIsHoveredChanged: {
        if (!isHovered && expanded && collapseOnHoverExit) {
            root.expanded = false
        }
    }

    function collapseModule() {
        root.expanded = false
    }

    onExpandedChanged: {
        if (expanded) {
            SharedState.setActiveModule(root)
        } else {
            SharedState.clearActiveModule(root)
        }
    }

    // ── Size animations ──────────────────────────────────────────
    Behavior on implicitHeight {
        NumberAnimation {
            id: _heightAnim
            duration: Theme.verticalDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            id: _widthAnim
            duration: Theme.horizontalDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }

    // ── Opacity animations ───────────────────────────────────────
    property real contentOpacity: expanded ? 1.0 : 0.0
    Behavior on contentOpacity {
        NumberAnimation {
            id: _opacityAnim
            duration: Theme.verticalDuration
            easing.type: Easing.OutCubic
        }
    }

    readonly property bool contentVisible: expanded || _heightAnim.running || _headerPillHeightAnim.running || _overlayWidthAnim.running || _opacityAnim.running || _headerPillYAnim.running || contentOpacity > 0.01 || implicitHeight > Theme.moduleHeight + 1

    // ── Overlay (dropdown container) ─────────────────────────────
    // The overlay renders the wider dropdown content below the header pill.
    // It extends beyond the module's bounds horizontally.
    property alias overlay: _overlay

    // Expanded dropdown width — set by each module (defaults to module width)
    property real expandedDropdownWidth: root.implicitWidth

    // Horizontal alignment: "left" | "right" | "center"
    // Left-side modules should use "left", right-side modules "right".
    property string dropdownAlignment: "right"

    Item {
        id: _overlay
        z: 2

        // Vertical: starts right below the header pill area
        y: Theme.moduleHeight

        // Width: animates from collapsed (module width) to expanded dropdown width
        width: root.expanded ? root.expandedDropdownWidth : root.collapsedWidth

        // Height: fills remaining module height below the pill
        height: Math.max(0, root.height - Theme.moduleHeight)

        clip: true

        // Horizontal position based on alignment preference and clamped to screen boundaries
        x: {
            var _rx = root.x
            var _rw = root.width
            var _pw = root.parent ? root.parent.width : 0
            var _px = root.parent ? root.parent.x : 0
            var _w = width
            var _exp = root.expanded
            var _align = root.dropdownAlignment
            var win = root.Window.window
            var winWidth = (win && win.width > 0) ? win.width : Screen.width

            var gx = 0
            try {
                if (win) {
                    var pt = root.mapToItem(null, 0, 0)
                    if (pt) gx = pt.x
                }
            } catch (e) {
                gx = 0
            }

            var prefX = 0
            if (_align === "left") {
                prefX = 0
            } else if (_align === "center") {
                prefX = (_rw - _w) / 2
            } else if (_align === "right") {
                prefX = _rw - _w
            } else {
                // "auto" or unspecified: align towards screen center
                if (winWidth > 0 && gx < winWidth / 2) {
                    prefX = 0
                } else {
                    prefX = _rw - _w
                }
            }

            // Screen boundary clamping so overlay maintains gap from screen edge
            if (winWidth > 0) {
                var minX = root.leftEdgeGap - gx
                var maxX = winWidth - root.rightEdgeGap - gx - _w
                if (minX <= maxX) {
                    return Math.max(minX, Math.min(prefX, maxX))
                }
            }
            return prefX
        }

        Behavior on width {
            NumberAnimation {
                id: _overlayWidthAnim
                duration: Theme.horizontalDuration
                easing.type: Easing.OutCubic
            }
        }

        // Hover handler for the overlay area (combined with root hover)
        HoverHandler {
            id: _overlayHover
        }
    }


    property bool useDefaultPill: true

    signal pillWheel(var wheel)
    signal pillRightClicked(var mouse)

    property string pillText: ""
    property real   pillPercent: 0
    property string pillVariant: "neutral"
    property string expandedPillLabel: ""
    property string pillBgImageSource: ""

    Text {
        id: _expandedMeasureText
        visible: false
        text: root.expandedPillLabel
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.bold: true
    }
    readonly property real expandedLabelWidth: _expandedMeasureText.implicitWidth > 0 ? Math.round(_expandedMeasureText.implicitWidth + 38) : 0

    Text {
        id: _collapsedMeasureText
        visible: false
        text: root.pillText
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
        font.bold: true
    }

    property real lastPillWidth: 50
    readonly property real pillNaturalWidth: {
        if (!expanded && _collapsedMeasureText.implicitWidth > 0) {
            return Math.max(50, Math.round(_collapsedMeasureText.implicitWidth + 38))
        }
        return lastPillWidth
    }

    onPillNaturalWidthChanged: {
        if (!expanded && pillNaturalWidth > 50) {
            lastPillWidth = pillNaturalWidth
        }
    }

    // ── Bar tab MouseArea & Close Button ─────────────────────────
    // When expanded, the header pill moves down underneath the bar.
    // This MouseArea displays a subtle close button in the bar tab
    // and collapses the module when clicked.
    MouseArea {
        id: _barTabMouseArea
        z: 3
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: Theme.moduleHeight
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        enabled: root.expanded
        visible: root.expanded || _closeButtonBg.opacity > 0.001

        onClicked: {
            root.collapseModule()
        }
        onWheel: (wheel) => {
            root.pillWheel(wheel)
        }

        Rectangle {
            id: _closeButtonBg
            anchors {
                fill: parent
                topMargin: 5
                bottomMargin: 5
                leftMargin: 6
                rightMargin: 6
            }
            radius: 8
            visible: opacity > 0.001
            opacity: (root.expanded && root.showCloseButton) ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.horizontalDuration
                    easing.type: Easing.OutCubic
                }
            }

            color: _barTabMouseArea.pressed
                ? Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.16)
                : (_barTabMouseArea.containsMouse
                    ? Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.10)
                    : Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.04))

            Behavior on color {
                ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            Text {
                id: _closeButtonText
                anchors.centerIn: parent
                text: root.closeButtonText
                color: _barTabMouseArea.containsMouse
                    ? Qt.lighter(Theme.textPrimary, 1.15)
                    : Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
                font.bold: true

                Behavior on color {
                    ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    property alias headerPill: _headerPill

    PillBarButton {
        id: _headerPill
        visible: root.useDefaultPill
        z: 1

        colorOpacity: 0.5
        pillColorOpacity: Theme.moduleOpacity

        pillText:    root.pillText
        percent:     root.pillPercent
        pillVariant: root.pillVariant
        variant:     "neutral"
        colorOverride: true
        bgImageSource: root.pillBgImageSource

        noHoverColorChange: true
        noPressColorChange: true

        x: root.contentVisible ? _overlay.x : 0
        y: root.expanded ? Theme.moduleHeight : 0
        width: root.contentVisible ? _overlay.width : root.width
        height: root.expanded ? Math.max(Theme.moduleHeight, _overlay.height) : Theme.moduleHeight
        implicitWidth: root.implicitWidth
        openBottom: root.expanded
        pillPaddingH: root.expanded ? 12 : 10
        pillHeight: root.expanded ? Math.max(Theme.moduleHeight - 10, _overlay.height) : (Theme.moduleHeight - 10)
        pillRadius: root.expanded ? 16 : ((Theme.moduleHeight - 10) / 2)

        Behavior on y {
            NumberAnimation {
                id: _headerPillYAnim
                duration: Theme.verticalDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            enabled: !root.expanded
            NumberAnimation {
                id: _headerPillHeightAnim
                duration: Theme.verticalDuration
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            id: _headerPillHover
        }

        MouseArea {
            id: _headerMouseArea
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: root.expanded ? root.titleBarHeight : parent.height
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onPressedChanged: {
                var isPressed = pressed && (pressedButtons & Qt.LeftButton)
                if (!root.expanded) {
                    root.pressed = isPressed
                } else {
                    _headerPill.pressed = isPressed
                }
            }
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    root.pillRightClicked(mouse)
                } else {
                    root.expanded = !root.expanded
                }
            }
            onWheel: (wheel) => {
                root.pillWheel(wheel)
            }
        }
        // ── Expanded title overlay ───────────────────────────────
        // Shows the expandedPillLabel when expanded, hidden when collapsed.
        Text {
            id: _expandedLabel
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            height: root.titleBarHeight
            verticalAlignment: Text.AlignVCenter
            text: root.expandedPillLabel
            color: Theme.textPrimary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 2
            font.bold: true
            visible: opacity > 0 && root.expandedPillLabel !== ""
            opacity: root.expanded ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
            }
        }
    }

}
