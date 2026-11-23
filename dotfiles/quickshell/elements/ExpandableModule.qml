// ExpandableModule.qml — Base for bar modules that expand downward with an overlay dropdown.
import QtQuick
import QtQuick.Shapes

ModuleButton {
    id: root

    property int expandedBottomLeftRadius:   Theme.expandedModuleRadius
    property int expandedBottomRightRadius:  Theme.expandedModuleRadius
    property int collapsedBottomLeftRadius:  0
    property int collapsedBottomRightRadius: 0
    property int collapsedPillRadius:        Theme.pillCollapsedRadius
    property int expandedPillRadius:         Theme.pillExpandedRadius

    bottomLeftRadius:  0
    bottomRightRadius: 0

    property real screenEdgeGap: 2 * Theme.moduleEdgeRadius
    readonly property real leftEdgeGap: (leftCornerStyle === "bottom") ? 0 : screenEdgeGap
    readonly property real rightEdgeGap: (rightCornerStyle === "bottom") ? 0 : screenEdgeGap

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
    property int topCornerRadius: Theme.topCornerRadius
    property int expandedTopCornerRadius: Theme.expandedTopCornerRadius
    readonly property bool hasProtrudingCorners: (leftCornerStyle === "bottom" || rightCornerStyle === "bottom" || leftCornerStyle === "top" || rightCornerStyle === "top")

    property alias flowingBackground: _flowingBg

    // Title bar configuration
    property int titleBarHeight: useDefaultPill ? Theme.moduleHeight * 1.6 : 0

    property bool pillDropped: false
    property bool bodyExpanded: false
    property real expandedHeight: Theme.moduleHeight * 2
    property real _stage2Height: bodyExpanded ? Math.max(Theme.moduleHeight, expandedHeight - Theme.moduleHeight) : Theme.moduleHeight
    implicitHeight: _headerPill.y + _stage2Height

    property bool shrinkEnabled: true
    property int collapsedWidth: (expanded || pillDropped || _headerPillYAnim.running) ? lastPillWidth : pillNaturalWidth
    implicitWidth: (root.bodyExpanded && shrinkEnabled) ? 100 : collapsedWidth

    // Close button configuration for bar tab
    property bool showCloseButton: shrinkEnabled
    property string closeButtonText: ""
    property real closeButtonWidth: root.width
    property real closeButtonHeight: Theme.pillHeight
    property real closeButtonRadius: Theme.pillHeight / 2
    property real closeButtonInverseRadius: Theme.pillHeight / 2

    clip: false
    noHoverColorChange: expanded || pillDropped
    noPressColorChange: expanded || pillDropped
    color: "transparent"

    // Unified flowing background that seamlessly renders the header pill,
    // side inverse-radius fillets, dropdown body, and bezel corners as one continuous piece.
    FlowingBackground {
        id: _flowingBg
        headerWidth: root.width
        headerHeight: Theme.moduleHeight
        overlayX: _overlay.x
        overlayWidth: _overlay.width
        overlayHeight: Math.max(0, root.height - Theme.moduleHeight)
        contentVisible: root.contentVisible
        bodyExpanded: root.bodyExpanded

        cornerRadius: root.inverseCornerSize
        topCornerRadius: root.topCornerRadius
        expandedTopCornerRadius: root.expandedTopCornerRadius
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

        color: (root.expanded || root.pillDropped || root.noHoverColorChange) ? root.baseColor : root.colorAdaptive
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
    property bool extraHovered: false
    readonly property bool rawHovered: _expandHover.hovered || _overlayHover.hovered || _flowingBgHover.hovered || _headerPillHover.hovered || (_barTabMouseArea.containsMouse && (root.expanded || root.pillDropped)) || (_expandedLabel && _expandedLabel.hovered) || extraHovered
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

    function _setPillDropped(dropped) {
        if (root.pillDropped === dropped) return
        _headerPillYAnim.duration = dropped ? Math.round(Theme.verticalDuration * 0.6) : Theme.verticalDuration
        _headerPillYAnim.easing.type = dropped ? root.expandEasingType : root.collapseEasingType
        root.pillDropped = dropped
    }

    Timer {
        id: _stageOverlapTimer
        interval: Math.round(Theme.verticalDuration / 5)
        repeat: false
        onTriggered: {
            if (root.expanded) {
                root.bodyExpanded = true
            } else {
                root._setPillDropped(false)
            }
        }
    }

    function _checkStage2CollapseDone() {
        if (!root.expanded && !root.bodyExpanded && root.pillDropped) {
            if (!_heightAnim.running && !_overlayWidthAnim.running && !_widthAnim.running) {
                _stageOverlapTimer.stop()
                root._setPillDropped(false)
            }
        }
    }

    onExpandedChanged: {
        if (expanded) {
            SharedState.setActiveModule(root)
            root._setPillDropped(true)
            if (!_headerPillYAnim.running && Math.abs(_headerPill.y - Theme.moduleHeight) < 0.5) {
                _stageOverlapTimer.stop()
                root.bodyExpanded = true
            } else {
                _stageOverlapTimer.restart()
            }
        } else {
            SharedState.clearActiveModule(root)
            if (!root.bodyExpanded && !_heightAnim.running && !_overlayWidthAnim.running && !_widthAnim.running) {
                _stageOverlapTimer.stop()
                root._setPillDropped(false)
            } else {
                root.bodyExpanded = false
                _stageOverlapTimer.restart()
                Qt.callLater(root._checkStage2CollapseDone)
            }
        }
    }

    // ── Size animations ──────────────────────────────────────────
    property int expandEasingType: Easing.OutQuint
    property int collapseEasingType: Easing.OutQuint

    Behavior on _stage2Height {
        NumberAnimation {
            id: _heightAnim
            duration: Theme.verticalDuration
            easing.type: root.bodyExpanded ? root.expandEasingType : root.collapseEasingType
            onRunningChanged: {
                if (!running) root._checkStage2CollapseDone()
            }
        }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            id: _widthAnim
            duration: Theme.horizontalDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
            onRunningChanged: {
                if (!running) root._checkStage2CollapseDone()
            }
        }
    }

    // ── Opacity animations ───────────────────────────────────────
    property real contentOpacity: bodyExpanded ? 1.0 : 0.0
    Behavior on contentOpacity {
        NumberAnimation {
            id: _opacityAnim
            duration: Theme.verticalDuration
            easing.type: root.bodyExpanded ? root.expandEasingType : root.collapseEasingType
        }
    }

    readonly property bool contentVisible: expanded || pillDropped || bodyExpanded || _heightAnim.running || _overlayWidthAnim.running || _opacityAnim.running || _headerPillYAnim.running || contentOpacity > 0.01 || implicitHeight > Theme.moduleHeight + 1

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

        // Vertical: tracks the header pill during Stage 1/2 overlap
        y: _headerPill.y

        // Width: animates from collapsed (module width) to expanded dropdown width
        width: root.bodyExpanded ? root.expandedDropdownWidth : root.collapsedWidth

        // Height: follows Stage 2 height
        height: root._stage2Height

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
                easing.type: root.bodyExpanded ? root.expandEasingType : root.collapseEasingType
                onRunningChanged: {
                    if (!running) root._checkStage2CollapseDone()
                }
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
    property real pillColorOpacity: Theme.moduleOpacity
    property var  pillBorderColor: null
    property var  pillFillColor: null
    property string expandedPillLabel: ""
    property int    expandedLabelPixelSize: Theme.fontSize + 5
    property string pillBgImageSource: ""
    property real   pillBgImageOpacity: 0.35
    property real   pillBgImageBrightness: 0.35
    property real   pillBgImageContrast: 0.0
    property real   pillBgImageDarkOverlayOpacity: 0.0

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
        if (!expanded && !pillDropped && !_headerPillYAnim.running && _collapsedMeasureText.implicitWidth > 0) {
            return Math.max(50, Math.round(_collapsedMeasureText.implicitWidth + 38))
        }
        return lastPillWidth
    }

    onPillNaturalWidthChanged: {
        if (!expanded && !pillDropped && !_headerPillYAnim.running && pillNaturalWidth > 50) {
            lastPillWidth = pillNaturalWidth
        }
    }

    // ── Bar tab MouseArea & Close Button ─────────────────────────
    // When expanded, the header pill moves down underneath the bar.
    // The close button smoothly drops down from the top edge with
    // InverseRadius wings, knocking the pill downward.
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
        enabled: (root.expanded || root.pillDropped) && root.showCloseButton
        clip: true

        readonly property real closeProgress: root.showCloseButton
            ? Math.max(0.0, Math.min(1.0, _headerPill.y / Theme.moduleHeight))
            : 0.0

        visible: root.showCloseButton && (root.expanded || root.pillDropped || _closeButtonContainer.y > -_closeButtonContainer.height + 0.1)

        onClicked: {
            root.collapseModule()
        }
        onWheel: (wheel) => {
            root.pillWheel(wheel)
        }

        property color buttonColor: pressed
            ? Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.08)
            : (containsMouse
                ? Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.18)
                : Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.10))

        Behavior on buttonColor {
            ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        Item {
            id: _closeButtonContainer
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.closeButtonWidth
            height: root.closeButtonHeight
            y: (_barTabMouseArea.closeProgress - 1.0) * height

            // Unified GPU-accelerated shape (seamless translucent body + inverse-radius wings)
            Shape {
                id: _closeButtonShape
                anchors.fill: parent
                visible: width > 0.1 && height > 0.1
                antialiasing: true
                smooth: true
                asynchronous: false
                preferredRendererType: Shape.CurveRenderer

                readonly property real invR: Math.max(0, Math.min(root.closeButtonInverseRadius, height, width / 2))
                readonly property real bodyW: Math.max(0, width - 2 * invR)
                readonly property real botR: Math.max(0, Math.min(root.closeButtonRadius, height - invR, bodyW / 2))
                readonly property real leftX: invR
                readonly property real rightX: width - invR
                readonly property real botY: bodyW > 0.1 ? height : invR
                readonly property real k: 0.55228475
                readonly property real ik: 1.0 - k

                ShapePath {
                    fillColor: _barTabMouseArea.buttonColor
                    strokeColor: "transparent"
                    strokeWidth: 0
                    startX: 0; startY: 0

                    PathLine { x: _closeButtonShape.width; y: 0 }
                    PathCubic {
                        control1X: _closeButtonShape.width - _closeButtonShape.invR * _closeButtonShape.k
                        control1Y: 0
                        control2X: _closeButtonShape.rightX
                        control2Y: _closeButtonShape.invR * _closeButtonShape.ik
                        x: _closeButtonShape.rightX
                        y: _closeButtonShape.invR
                    }
                    PathLine { x: _closeButtonShape.rightX; y: _closeButtonShape.botY - _closeButtonShape.botR }
                    PathCubic {
                        control1X: _closeButtonShape.rightX
                        control1Y: _closeButtonShape.botY - _closeButtonShape.botR * _closeButtonShape.ik
                        control2X: _closeButtonShape.rightX - _closeButtonShape.botR * _closeButtonShape.ik
                        control2Y: _closeButtonShape.botY
                        x: _closeButtonShape.rightX - _closeButtonShape.botR
                        y: _closeButtonShape.botY
                    }
                    PathLine { x: _closeButtonShape.leftX + _closeButtonShape.botR; y: _closeButtonShape.botY }
                    PathCubic {
                        control1X: _closeButtonShape.leftX + _closeButtonShape.botR * _closeButtonShape.ik
                        control1Y: _closeButtonShape.botY
                        control2X: _closeButtonShape.leftX
                        control2Y: _closeButtonShape.botY - _closeButtonShape.botR * _closeButtonShape.ik
                        x: _closeButtonShape.leftX
                        y: _closeButtonShape.botY - _closeButtonShape.botR
                    }
                    PathLine { x: _closeButtonShape.leftX; y: _closeButtonShape.invR }
                    PathCubic {
                        control1X: _closeButtonShape.leftX
                        control1Y: _closeButtonShape.invR * _closeButtonShape.ik
                        control2X: _closeButtonShape.invR * _closeButtonShape.k
                        control2Y: 0
                        x: 0
                        y: 0
                    }
                }
            }

            Text {
                id: _closeButtonText
                anchors.centerIn: parent
                anchors.verticalCenterOffset: _barTabMouseArea.pressed ? 1 : (_barTabMouseArea.containsMouse ? -2 : 0)
                text: root.closeButtonText
                color: _barTabMouseArea.pressed
                    ? Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.90)
                    : (_barTabMouseArea.containsMouse
                        ? Theme.textPrimary
                        : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.70))
                font.family: Theme.font
                font.pixelSize: 12
                font.bold: true

                Behavior on anchors.verticalCenterOffset {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

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

        pillText:    root.pillText
        percent:     root.pillPercent
        pillVariant: root.pillVariant
        pillColorOpacity: root.pillColorOpacity
        pillBorderColor: root.pillBorderColor
        pillFillColor: root.pillFillColor
        variant:     "neutral"
        colorOverride: true
        bgImageSource: root.pillBgImageSource
        bgImageOpacity: root.pillBgImageOpacity
        bgImageBrightness: root.pillBgImageBrightness
        bgImageContrast: root.pillBgImageContrast
        bgImageDarkOverlayOpacity: root.pillBgImageDarkOverlayOpacity

        pillTopLeftRadius: root.bodyExpanded ? Theme.pillCollapsedRadius + 10 : Theme.pillCollapsedRadius
        pillTopRightRadius: root.bodyExpanded ? Theme.pillCollapsedRadius + 10 : Theme.pillCollapsedRadius

        noHoverColorChange: true
        noPressColorChange: true
        hasScaleAnimation: !root.expanded && !root.pillDropped

        hovered: _headerPillHover.hovered || root.hovered

        x: root.contentVisible ? _overlay.x : 0
        y: root.pillDropped ? Theme.moduleHeight : 0
        width: root.contentVisible ? _overlay.width : root.width
        height: root._stage2Height
        implicitWidth: root.implicitWidth
        expanded: root.bodyExpanded
        pillPaddingH: root.bodyExpanded ? Theme.pillExpandedPaddingH : Theme.pillCollapsedPaddingH
        pillRadius: root.bodyExpanded ? root.expandedPillRadius : root.collapsedPillRadius

        Behavior on y {
            NumberAnimation {
                id: _headerPillYAnim
                duration: Theme.verticalDuration
                easing.type: root.expandEasingType
                onRunningChanged: {
                    if (!running && root.expanded && root.pillDropped && !root.bodyExpanded) {
                        _stageOverlapTimer.stop()
                        root.bodyExpanded = true
                    }
                }
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
            height: root.bodyExpanded ? root.titleBarHeight : parent.height
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onPressedChanged: {
                var isPressed = pressed && (pressedButtons & Qt.LeftButton)
                root.pressed = isPressed
                _headerPill.pressed = isPressed
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
        HoverMarqueeText {
            id: _expandedLabel
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            height: root.titleBarHeight
            text: root.expandedPillLabel
            textColor: Theme.textPrimary
            fontFamily: Theme.font
            pixelSize: root.expandedLabelPixelSize
            fontBold: true
            textMaxWidth: Math.max(100, parent.width - 40)
            horizontalAlignment: Text.AlignHCenter
            visible: opacity > 0 && root.expandedPillLabel !== ""
            opacity: root.bodyExpanded ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: Theme.verticalDuration; easing.type: root.bodyExpanded ? root.expandEasingType : root.collapseEasingType }
            }
        }
    }

}
