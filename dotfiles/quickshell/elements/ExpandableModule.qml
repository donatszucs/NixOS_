// ExpandableModule.qml — Base for bar modules that expand downward with an overlay dropdown
// and a unified GPU-accelerated flowing background silhouette.
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

ModuleButton {
    id: root

    // ── Corner & Pill Radii ──────────────────────────────────────
    property int expandedBottomLeftRadius:   Theme.expandedModuleRadius
    property int expandedBottomRightRadius:  Theme.expandedModuleRadius
    property int collapsedBottomLeftRadius:  0
    property int collapsedBottomRightRadius: 0
    property int collapsedPillRadius:        Theme.pillCollapsedRadius
    property int expandedPillRadius:         Theme.pillExpandedRadius

    bottomLeftRadius:  0
    bottomRightRadius: 0

    // Corner styles: "side" (fillet under bar) | "bottom" (screen bezel) | "top" (protruding top) | "none"
    property string leftCornerStyle:  "side"
    property string rightCornerStyle: "side"
    property int inverseCornerSize: Theme.moduleEdgeRadius
    property int topCornerRadius: Theme.topCornerRadius
    property int expandedTopCornerRadius: Theme.expandedTopCornerRadius
    readonly property bool hasProtrudingCorners: leftCornerStyle === "bottom" || rightCornerStyle === "bottom"
                                              || leftCornerStyle === "top"    || rightCornerStyle === "top"

    property real screenEdgeGap: 2 * Theme.moduleEdgeRadius
    readonly property real leftEdgeGap:  leftCornerStyle === "bottom"  ? 0 : screenEdgeGap
    readonly property real rightEdgeGap: rightCornerStyle === "bottom" ? 0 : screenEdgeGap

    readonly property real _globalX: {
        var _rx = root.x
        var _px = root.parent ? root.parent.x : 0
        var _pw = root.parent ? root.parent.width : 0
        void(_rx); void(_px); void(_pw)
        var win = root.Window.window
        if (!win) return 0
        try {
            var pt = root.mapToItem(null, 0, 0)
            return pt ? pt.x : 0
        } catch (e) {
            return 0
        }
    }

    readonly property bool touchesPhysicalLeftEdge:  contentVisible && root.Window.window !== null && (_globalX + _overlay.x <= 1)
    readonly property bool touchesPhysicalRightEdge: contentVisible && root.Window.window !== null && (_globalX + _overlay.x + _overlay.width >= root.Window.window.width - 1)

    property alias flowingBackground: _flowingBg
    readonly property Item activeRegion: (contentVisible || hasProtrudingCorners) ? _flowingBg : null

    // ── Sizing & Stage State ─────────────────────────────────────
    property int cardWidth: 0
    property int titleBarHeight: useDefaultPill ? Theme.moduleHeight * 1.6 : 0

    property bool pillDropped: false
    property bool bodyExpanded: false
    property real expandedHeight: _dropdownColumn.children.length > 0
        ? (_dropdownColumn.implicitHeight + Theme.moduleHeight + titleBarHeight + Theme.dropdownMargin)
        : (Theme.moduleHeight * 2)
    property real _stage2Height: bodyExpanded ? Math.max(Theme.moduleHeight, expandedHeight - Theme.moduleHeight) : Theme.moduleHeight
    implicitHeight: _headerPill.y + _stage2Height

    property bool shrinkEnabled: true
    property real naturalWidth: _headerPill.textImplicitWidth > 0
        ? Math.max(50, Math.round(_headerPill.textImplicitWidth + 38))
        : 50
    property real _latchedWidth: 50
    onNaturalWidthChanged: {
        if (!expanded && !pillDropped && !_headerPillYAnim.running && naturalWidth > 0) {
            _latchedWidth = naturalWidth
        }
    }
    Component.onCompleted: {
        if (naturalWidth > 0) _latchedWidth = naturalWidth
    }

    property int collapsedWidth: Math.round((expanded || pillDropped || _headerPillYAnim.running) ? _latchedWidth : naturalWidth)
    implicitWidth: (root.bodyExpanded && shrinkEnabled) ? 100 : collapsedWidth

    // ── Close Button Configuration ───────────────────────────────
    property bool showCloseButton: shrinkEnabled
    property string closeButtonText: ""
    property real closeButtonWidth: root.width
    property real closeButtonHeight: Theme.pillHeight
    property real closeButtonRadius: Theme.closeButtonRadius
    property real closeButtonInverseRadius: Theme.closeButtonRadius

    clip: false
    noHoverColorChange: expanded || pillDropped
    noPressColorChange: expanded || pillDropped
    color: "transparent"

    // Render above RowLayout siblings when expanded so overlay is on top (and during collapse animation)
    z: (SharedState.activeModule === root) ? 20 : (contentVisible ? 10 : 0)

    // ── Unified Flowing Background ───────────────────────────────
    // Seamlessly renders the header pill, side inverse-radius fillets,
    // dropdown body, and bezel corners as a single GPU-accelerated Shape.
    Item {
        id: _flowingBg
        z: 0

        property color targetColor: (root.expanded || root.pillDropped) ? root.baseColor : root.colorAdaptive
        property color animatedColor: targetColor
        Behavior on animatedColor {
            ColorAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
        }

        readonly property real overlayHeight: Math.max(0, root.height - Theme.moduleHeight)
        readonly property bool isExpanded: root.contentVisible
        readonly property bool hasLeftSideCorner:  isExpanded && overlayHeight > 0.1 && root.leftCornerStyle === "side"  && _overlay.x <= 0.1 && !root.touchesPhysicalLeftEdge
        readonly property bool hasRightSideCorner: isExpanded && overlayHeight > 0.1 && root.rightCornerStyle === "side" && (_overlay.x + _overlay.width) >= root.width - 0.1 && !root.touchesPhysicalRightEdge
        readonly property bool hasLeftBottomCorner:  root.leftCornerStyle === "bottom"
        readonly property bool hasRightBottomCorner: root.rightCornerStyle === "bottom"
        readonly property bool hasLeftTopCorner:     root.leftCornerStyle === "top"
        readonly property bool hasRightTopCorner:    root.rightCornerStyle === "top"

        readonly property real currentTopR: root.topCornerRadius + (root.expandedTopCornerRadius - root.topCornerRadius) * root.contentOpacity
        readonly property real sideR: Math.min(root.inverseCornerSize, (isExpanded ? overlayHeight : 0) / 2)

        readonly property real minX: Math.min(
            hasLeftTopCorner ? -currentTopR : 0,
            hasLeftSideCorner ? (_overlay.x - sideR) : 0
        )
        readonly property real maxX: Math.max(
            hasRightTopCorner ? (root.width + currentTopR) : root.width,
            hasRightSideCorner ? (_overlay.x + _overlay.width + sideR) : root.width
        )
        readonly property real maxY: (isExpanded ? (Theme.moduleHeight + overlayHeight) : Theme.moduleHeight)
                                   + ((hasLeftBottomCorner || hasRightBottomCorner) ? root.inverseCornerSize : 0)

        x: minX
        y: 0
        width: Math.max(1, maxX - minX)
        height: Math.max(Theme.moduleHeight, maxY)

        readonly property string pathData: {
            var R = root.inverseCornerSize
            var ltR = hasLeftTopCorner ? currentTopR : 0
            var rtR = hasRightTopCorner ? currentTopR : 0
            var hw = root.width
            var hh = Theme.moduleHeight
            var ow = _overlay.width
            var dh = isExpanded ? overlayHeight : 0
            var totalY = hh + dh

            var ox = (isExpanded && dh > 0.1) ? (root.leftCornerStyle === "side" ? Math.min(0, _overlay.x) : _overlay.x) : 0
            var rWallX = (isExpanded && dh > 0.1) ? (_overlay.x + ow) : hw

            var topL = hasLeftTopCorner ? 0 : root.topLeftRadius
            var topR = hasRightTopCorner ? 0 : root.topRightRadius

            var cBotL = root.collapsedBottomLeftRadius
            var cBotR = root.collapsedBottomRightRadius
            var eBotL = (root.touchesPhysicalLeftEdge && hasLeftBottomCorner) ? 0 : root.expandedBottomLeftRadius
            var eBotR = (root.touchesPhysicalRightEdge && hasRightBottomCorner) ? 0 : root.expandedBottomRightRadius

            var sR = Math.min(R, dh / 2)

            function calcBot(cR, eR) {
                if (!isExpanded || dh <= 0.1) return cR
                var stage1Target = (eR >= cR) ? Math.min(eR, Math.max(cR, R)) : Math.max(eR, Math.min(cR, R))
                var s1 = (stage1Target >= cR) ? Math.min(stage1Target, cR + dh / 2) : Math.max(stage1Target, cR - dh / 2)
                return s1 + (eR - s1) * root.contentOpacity
            }

            var botL = calcBot(cBotL, eBotL)
            var botR = calcBot(cBotR, eBotR)

            if (hasLeftSideCorner)  botL = Math.min(botL, Math.max(0, dh - sR))
            if (hasRightSideCorner) botR = Math.min(botR, Math.max(0, dh - sR))
            if (hasLeftTopCorner)   botL = Math.min(botL, Math.max(0, totalY - ltR))
            if (hasRightTopCorner)  botR = Math.min(botR, Math.max(0, totalY - rtR))

            var ik = 0.44771525
            function f(v) { return Number(v).toFixed(2) }

            var p = ""

            // 1. Header Top-Left
            if (hasLeftTopCorner && ltR > 0.1) {
                p += "M " + f(-ltR) + " 0 "
            } else if (topL > 0.1) {
                p += "M 0 " + f(topL) + " C 0 " + f(topL * ik) + ", " + f(topL * ik) + " 0, " + f(topL) + " 0 "
            } else {
                p += "M 0 0 "
            }

            // 2. Header Top Edge & Top-Right
            if (hasRightTopCorner && rtR > 0.1) {
                p += "L " + f(hw + rtR) + " 0 C " + f(hw + rtR * ik) + " 0, " + f(hw) + " " + f(rtR * ik) + ", " + f(hw) + " " + f(rtR) + " "
            } else if (topR > 0.1) {
                p += "L " + f(hw - topR) + " 0 C " + f(hw - topR * ik) + " 0, " + f(hw) + " " + f(topR * ik) + ", " + f(hw) + " " + f(topR) + " "
            } else {
                p += "L " + f(hw) + " 0 "
            }

            // 3. Right Side Wall & Transition
            if (hasRightSideCorner && sR > 0.1) {
                p += "L " + f(hw) + " " + f(hh) + " L " + f(rWallX + sR) + " " + f(hh) + " "
                p += "C " + f(rWallX + sR * ik) + " " + f(hh) + ", " + f(rWallX) + " " + f(hh + sR * ik) + ", " + f(rWallX) + " " + f(hh + sR) + " "
                p += "L " + f(rWallX) + " " + f(totalY - botR) + " "
            } else if (hasRightSideCorner || (isExpanded && dh > 0.1 && rWallX > hw + 0.1)) {
                p += "L " + f(hw) + " " + f(hh) + " L " + f(rWallX) + " " + f(hh) + " L " + f(rWallX) + " " + f(totalY - botR) + " "
            } else if (hasRightBottomCorner) {
                p += "L " + f(hw) + " " + f(totalY) + " "
            } else {
                p += "L " + f(hw) + " " + f(totalY - botR) + " "
            }

            // 4. Bottom-Right Corner
            if (hasRightBottomCorner && R > 0.1) {
                p += "L " + f(hw) + " " + f(totalY + R) + " C " + f(hw) + " " + f(totalY + R * ik) + ", " + f(hw - R * ik) + " " + f(totalY) + ", " + f(hw - R) + " " + f(totalY) + " "
            } else if (botR > 0.1) {
                p += "C " + f(rWallX) + " " + f(totalY - botR * ik) + ", " + f(rWallX - botR * ik) + " " + f(totalY) + ", " + f(rWallX - botR) + " " + f(totalY) + " "
            } else {
                p += "L " + f(rWallX) + " " + f(totalY) + " "
            }

            // 5. Bottom Edge
            var lBotCornerX = hasLeftBottomCorner ? R : (ox + botL)
            p += "L " + f(lBotCornerX) + " " + f(totalY) + " "

            // 6. Bottom-Left Corner
            if (hasLeftBottomCorner && R > 0.1) {
                p += "C " + f(R * ik) + " " + f(totalY) + ", 0 " + f(totalY + R * ik) + ", 0 " + f(totalY + R) + " L 0 " + f(totalY) + " "
            } else if (botL > 0.1) {
                p += "C " + f(ox + botL * ik) + " " + f(totalY) + ", " + f(ox) + " " + f(totalY - botL * ik) + ", " + f(ox) + " " + f(totalY - botL) + " "
            } else {
                p += "L " + f(ox) + " " + f(totalY) + " "
            }

            // 7. Left Side Wall & Transition
            if (hasLeftTopCorner && ltR > 0.1) {
                p += "L 0 " + f(ltR) + " C 0 " + f(ltR * ik) + ", " + f(-ltR * ik) + " 0, " + f(-ltR) + " 0 "
            } else if (hasLeftSideCorner && sR > 0.1) {
                p += "L " + f(ox) + " " + f(hh + sR) + " C " + f(ox) + " " + f(hh + sR * ik) + ", " + f(ox - sR * ik) + " " + f(hh) + ", " + f(ox - sR) + " " + f(hh) + " "
                p += "L 0 " + f(hh) + " L 0 " + f(topL) + " "
            } else if (hasLeftSideCorner || (isExpanded && dh > 0.1 && ox < -0.1)) {
                p += "L " + f(ox) + " " + f(hh) + " L 0 " + f(hh) + " L 0 " + f(topL) + " "
            } else {
                p += "L 0 " + f(topL) + " "
            }

            return p + "Z"
        }

        Shape {
            x: -_flowingBg.minX
            y: 0
            antialiasing: true
            smooth: true
            asynchronous: false
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: _flowingBg.animatedColor
                strokeColor: "transparent"
                strokeWidth: 0
                PathSvg { path: _flowingBg.pathData }
            }
        }

        HoverHandler { id: _flowingBgHover }
    }

    // ── Hover Collapse ───────────────────────────────────────────
    property bool collapseOnHoverExit: true
    property bool extraHovered: false

    readonly property bool rawHovered: root.hovered || _overlayHover.hovered || _flowingBgHover.hovered
                                    || _headerPillHover.hovered
                                    || (_barTabMouseArea.containsMouse && (root.expanded || root.pillDropped))
                                    || _expandedLabel.hovered || extraHovered
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

    onIsHoveredChanged: {
        if (!isHovered && expanded && collapseOnHoverExit) {
            root.expanded = false
        }
    }

    onCollapseOnHoverExitChanged: {
        if (collapseOnHoverExit && !isHovered && expanded) {
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
            if (!pillDropped && naturalWidth > 0) _latchedWidth = naturalWidth
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

    // ── Size & Opacity Animations ────────────────────────────────
    property int expandEasingType: Easing.OutQuint
    property int collapseEasingType: Easing.OutQuint

    Behavior on _stage2Height {
        NumberAnimation {
            id: _heightAnim
            duration: Theme.verticalDuration
            easing.type: root.bodyExpanded ? root.expandEasingType : root.collapseEasingType
            onRunningChanged: if (!running) root._checkStage2CollapseDone()
        }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            id: _widthAnim
            duration: Theme.horizontalDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
            onRunningChanged: if (!running) root._checkStage2CollapseDone()
        }
    }

    property real contentOpacity: bodyExpanded ? 1.0 : 0.0
    Behavior on contentOpacity {
        NumberAnimation {
            id: _opacityAnim
            duration: Theme.verticalDuration
            easing.type: root.bodyExpanded ? root.expandEasingType : root.collapseEasingType
        }
    }

    readonly property bool contentVisible: expanded || pillDropped || bodyExpanded
                                        || _heightAnim.running || _overlayWidthAnim.running
                                        || _opacityAnim.running || _headerPillYAnim.running
                                        || contentOpacity > 0.01 || implicitHeight > Theme.moduleHeight + 1

    // ── Overlay (Dropdown Container) ─────────────────────────────
    property alias overlay: _overlay
    property alias dropdownLayout: _dropdownColumn
    property alias dropdownContent: _dropdownColumn.data

    property real expandedDropdownWidth: cardWidth > 0 ? (cardWidth + Theme.dropdownMargin * 2) : root.implicitWidth
    property string dropdownAlignment: "right"

    Item {
        id: _overlay
        z: 2
        y: _headerPill.y
        width: root.bodyExpanded ? root.expandedDropdownWidth : root.collapsedWidth
        height: root._stage2Height
        clip: true

        x: {
            var rw = root.width
            var w = width
            var align = root.dropdownAlignment
            var gx = root._globalX
            var win = root.Window.window
            var winWidth = (win && win.width > 0) ? win.width : Screen.width

            var prefX = 0
            if (align === "left") {
                prefX = 0
            } else if (align === "center") {
                prefX = (rw - w) / 2
            } else if (align === "right") {
                prefX = rw - w
            } else {
                prefX = (winWidth > 0 && gx < winWidth / 2) ? 0 : (rw - w)
            }

            if (winWidth > 0) {
                var minX = root.leftEdgeGap - gx
                var maxX = winWidth - root.rightEdgeGap - gx - w
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
                onRunningChanged: if (!running) root._checkStage2CollapseDone()
            }
        }

        ColumnLayout {
            id: _dropdownColumn
            visible: children.length > 0 && root.contentVisible
            opacity: root.contentOpacity
            width: root.cardWidth > 0 ? root.cardWidth : implicitWidth
            spacing: Theme.cardMargin
            anchors {
                top: parent.top
                topMargin: root.titleBarHeight
                horizontalCenter: parent.horizontalCenter
            }

            scale: root.bodyExpanded ? 1 : 0
            transformOrigin: Item.Top
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.verticalDuration
                    easing.type: root.bodyExpanded ? root.expandEasingType : root.collapseEasingType
                }
            }
        }

        HoverHandler { id: _overlayHover }
    }

    // ── Header Pill & Bar Close Tab ──────────────────────────────
    property bool useDefaultPill: true

    signal pillWheel(var wheel)
    signal pillRightClicked(var mouse)

    property string pillText: ""
    property real   pillPercent: 0
    property string pillVariant: "neutral"
    property real   pillColorOpacity: Theme.moduleOpacity
    property var    pillBorderColor: null
    property var    pillFillColor: null
    property string expandedPillLabel: ""
    property int    expandedLabelPixelSize: Theme.fontSize + 5
    property string pillBgImageSource: ""
    property real   pillBgImageOpacity: 0.35
    property real   pillBgImageBrightness: 0.35
    property real   pillBgImageContrast: 0.0
    property real   pillBgImageDarkOverlayOpacity: 0.0

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

        onClicked: root.collapseModule()
        onWheel: (wheel) => root.pillWheel(wheel)

        property color buttonColor: Qt.rgba(
            Theme.palettePaper.r,
            Theme.palettePaper.g,
            Theme.palettePaper.b,
            pressed ? 0.08 : (containsMouse ? 0.18 : 0.10)
        )

        Behavior on buttonColor {
            ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        Item {
            id: _closeButtonContainer
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.closeButtonWidth
            height: root.closeButtonHeight
            y: (_barTabMouseArea.closeProgress - 1.0) * height

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

                ShapePath {
                    fillColor: _barTabMouseArea.buttonColor
                    strokeColor: "transparent"
                    strokeWidth: 0
                    startX: 0; startY: 0

                    PathLine { x: _closeButtonShape.width; y: 0 }
                    PathArc  { x: _closeButtonShape.rightX; y: _closeButtonShape.invR; radiusX: _closeButtonShape.invR; radiusY: _closeButtonShape.invR; direction: PathArc.Counterclockwise }
                    PathLine { x: _closeButtonShape.rightX; y: _closeButtonShape.botY - _closeButtonShape.botR }
                    PathArc  { x: _closeButtonShape.rightX - _closeButtonShape.botR; y: _closeButtonShape.botY; radiusX: _closeButtonShape.botR; radiusY: _closeButtonShape.botR }
                    PathLine { x: _closeButtonShape.leftX + _closeButtonShape.botR; y: _closeButtonShape.botY }
                    PathArc  { x: _closeButtonShape.leftX; y: _closeButtonShape.botY - _closeButtonShape.botR; radiusX: _closeButtonShape.botR; radiusY: _closeButtonShape.botR }
                    PathLine { x: _closeButtonShape.leftX; y: _closeButtonShape.invR }
                    PathArc  { x: 0; y: 0; radiusX: _closeButtonShape.invR; radiusY: _closeButtonShape.invR; direction: PathArc.Counterclockwise }
                }
            }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: _barTabMouseArea.pressed ? 1 : (_barTabMouseArea.containsMouse ? -2 : 0)
                text: root.closeButtonText
                color: Qt.rgba(
                    Theme.textPrimary.r,
                    Theme.textPrimary.g,
                    Theme.textPrimary.b,
                    _barTabMouseArea.pressed ? 0.90 : (_barTabMouseArea.containsMouse ? 1.0 : 0.70)
                )
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
    property alias pillContent: _headerPill.pillContent

    PillBarButton {
        id: _headerPill
        visible: root.useDefaultPill
        z: 1

        variant: "transparent"
        color: "transparent"
        colorOpacity: 0.5

        pillText:    root.pillText
        percent:     root.pillPercent
        pillVariant: root.pillVariant
        pillColorOpacity: root.pillColorOpacity
        pillBorderColor: root.pillBorderColor
        pillFillColor: root.pillFillColor
        bgImageSource: root.pillBgImageSource
        bgImageOpacity: root.pillBgImageOpacity
        bgImageBrightness: root.pillBgImageBrightness
        bgImageContrast: root.pillBgImageContrast
        bgImageDarkOverlayOpacity: root.pillBgImageDarkOverlayOpacity

        pillTopLeftRadius:  root.bodyExpanded ? Theme.pillCollapsedRadius + 10 : Theme.pillCollapsedRadius
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

        HoverHandler { id: _headerPillHover }

        MouseArea {
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
            onWheel: (wheel) => root.pillWheel(wheel)
        }

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
                NumberAnimation {
                    duration: Theme.verticalDuration
                    easing.type: root.bodyExpanded ? root.expandEasingType : root.collapseEasingType
                }
            }
        }
    }
}
