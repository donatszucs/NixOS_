import QtQuick
import QtQuick.Shapes

Item {
    id: root

    // ── Geometry Inputs ──────────────────────────────────────────
    property real headerWidth: 0
    property real headerHeight: Theme.moduleHeight
    property real overlayX: 0
    property real overlayWidth: 0
    property real overlayHeight: 0
    property bool contentVisible: false

    // ── Corner Radii ─────────────────────────────────────────────
    property real cornerRadius: Theme.moduleEdgeRadius
    property real topLeftRadius: 0
    property real topRightRadius: 0
    property real bottomLeftRadius: 0
    property real bottomRightRadius: 0
    property real collapsedBottomLeftRadius: 0
    property real collapsedBottomRightRadius: 0
    property real expandedBottomLeftRadius: 0
    property real expandedBottomRightRadius: 0

    // ── Corner Styles ("side" | "bottom" | "top" | "none") ───────
    property string leftCornerStyle: "side"
    property string rightCornerStyle: "side"
    property bool touchesLeftEdge: false
    property bool touchesRightEdge: false

    // ── Appearance ───────────────────────────────────────────────
    property color color: Theme.palette("dark").base
    property bool dontAnimateColor: false

    property color animatedColor: color
    Behavior on animatedColor {
        enabled: !root.dontAnimateColor
        ColorAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    readonly property bool isExpanded: contentVisible
    readonly property bool hasLeftSideCorner: isExpanded && (overlayHeight > 0.1) && (leftCornerStyle === "side") && (overlayX < 0) && !touchesLeftEdge
    readonly property bool hasRightSideCorner: isExpanded && (overlayHeight > 0.1) && (rightCornerStyle === "side") && ((overlayX + overlayWidth) > headerWidth) && !touchesRightEdge
    readonly property bool hasLeftBottomCorner: (leftCornerStyle === "bottom")
    readonly property bool hasRightBottomCorner: (rightCornerStyle === "bottom")
    readonly property bool hasLeftTopCorner: (leftCornerStyle === "top")
    readonly property bool hasRightTopCorner: (rightCornerStyle === "top")

    // Dynamic bounding box covering the entire outer silhouette (used for outer bounds query)
    readonly property real sideR: Math.min(cornerRadius, (isExpanded ? overlayHeight : 0) / 2)
    readonly property real minX: Math.min(
        hasLeftTopCorner ? -cornerRadius : 0,
        (hasLeftSideCorner && overlayHeight > 0.1) ? (overlayX - sideR) : 0
    )
    readonly property real maxX: Math.max(
        hasRightTopCorner ? (headerWidth + cornerRadius) : headerWidth,
        (hasRightSideCorner && overlayHeight > 0.1) ? (overlayX + overlayWidth + sideR) : headerWidth
    )
    readonly property real maxY: (isExpanded ? (headerHeight + overlayHeight) : headerHeight) + ((hasLeftBottomCorner || hasRightBottomCorner) ? cornerRadius : 0)

    x: minX
    y: 0
    width: Math.max(1, maxX - minX)
    height: Math.max(headerHeight, maxY)
    z: 0

    function requestPaint() {}

    // SVG path string generator
    readonly property string pathData: {
        var R = cornerRadius;
        var hw = headerWidth;
        var hh = headerHeight;
        var ow = overlayWidth;
        var dh = isExpanded ? overlayHeight : 0;
        var totalY = hh + dh;

        // Overlay left edge: clamp to <= 0 when using side corner so it never cuts into header pill
        var ox = (isExpanded && dh > 0.1) ? (leftCornerStyle === "side" ? Math.min(0, overlayX) : overlayX) : 0;
        var rWallX = (isExpanded && dh > 0.1) ? (overlayX + ow) : hw;

        var topL = hasLeftTopCorner ? 0 : topLeftRadius;
        var topR = hasRightTopCorner ? 0 : topRightRadius;

        // Effective expanded and collapsed corner targets
        var cBotL = collapsedBottomLeftRadius > 0 ? collapsedBottomLeftRadius : bottomLeftRadius;
        var cBotR = collapsedBottomRightRadius > 0 ? collapsedBottomRightRadius : bottomRightRadius;
        var eBotL = expandedBottomLeftRadius > 0 ? expandedBottomLeftRadius : bottomLeftRadius;
        var eBotR = expandedBottomRightRadius > 0 ? expandedBottomRightRadius : bottomRightRadius;

        // Side inverse fillet size (maximum R, smoothly limited by dh / 2 as height collapses)
        var sR = Math.min(R, dh / 2);

        // Interpolate bottom corner radius smoothly with dh
        function calcBot(cR, eR, isExp, currentDh) {
            if (!isExp) return cR;
            if (eR >= cR) {
                return Math.min(eR, cR + currentDh / 2);
            } else {
                return Math.max(eR, cR - currentDh / 2);
            }
        }

        var botL = calcBot(cBotL, eBotL, isExpanded, dh);
        var botR = calcBot(cBotR, eBotR, isExpanded, dh);

        // When a side inverse fillet exists, ensure bottom corner and side fillet do not exceed available height dh
        if (hasLeftSideCorner) {
            botL = Math.min(botL, Math.max(0, dh - sR));
        }
        if (hasRightSideCorner) {
            botR = Math.min(botR, Math.max(0, dh - sR));
        }
        if (hasLeftTopCorner) {
            botL = Math.min(botL, Math.max(0, totalY - R));
        }
        if (hasRightTopCorner) {
            botR = Math.min(botR, Math.max(0, totalY - R));
        }

        var k = 0.55228475;
        var ik = 1 - k;
        function f(v) { return Number(v).toFixed(2); }

        var p = "";

        // 1. Header Top-Left
        if (hasLeftTopCorner && R > 0.1) {
            p += "M " + f(-R) + " 0 ";
        } else if (topL > 0.1) {
            p += "M 0 " + f(topL) + " ";
            p += "C 0 " + f(topL * ik) + ", " + f(topL * ik) + " 0, " + f(topL) + " 0 ";
        } else {
            p += "M 0 0 ";
        }

        // 2. Header Top Edge & Top-Right
        if (hasRightTopCorner && R > 0.1) {
            p += "L " + f(hw + R) + " 0 ";
            p += "C " + f(hw + R * ik) + " 0, " + f(hw) + " " + f(R * ik) + ", " + f(hw) + " " + f(R) + " ";
        } else if (topR > 0.1) {
            p += "L " + f(hw - topR) + " 0 ";
            p += "C " + f(hw - topR * ik) + " 0, " + f(hw) + " " + f(topR * ik) + ", " + f(hw) + " " + f(topR) + " ";
        } else {
            p += "L " + f(hw) + " 0 ";
        }

        // 3. Right Side Wall & Transition
        if (hasRightSideCorner && sR > 0.1) {
            p += "L " + f(hw) + " " + f(hh) + " ";
            p += "L " + f(rWallX + sR) + " " + f(hh) + " ";
            p += "C " + f(rWallX + sR * ik) + " " + f(hh) + ", " + f(rWallX) + " " + f(hh + sR * ik) + ", " + f(rWallX) + " " + f(hh + sR) + " ";
            p += "L " + f(rWallX) + " " + f(totalY - botR) + " ";
        } else if (hasRightSideCorner || (isExpanded && dh > 0.1 && rWallX > hw + 0.1)) {
            p += "L " + f(hw) + " " + f(hh) + " ";
            p += "L " + f(rWallX) + " " + f(hh) + " ";
            p += "L " + f(rWallX) + " " + f(totalY - botR) + " ";
        } else if (hasRightBottomCorner) {
            p += "L " + f(hw) + " " + f(totalY) + " ";
        } else {
            p += "L " + f(hw) + " " + f(totalY - botR) + " ";
        }

        // 4. Bottom-Right Corner
        if (hasRightBottomCorner && R > 0.1) {
            p += "L " + f(hw) + " " + f(totalY + R) + " ";
            p += "C " + f(hw) + " " + f(totalY + R * ik) + ", " + f(hw - R * ik) + " " + f(totalY) + ", " + f(hw - R) + " " + f(totalY) + " ";
        } else if (botR > 0.1) {
            p += "C " + f(rWallX) + " " + f(totalY - botR * ik) + ", " + f(rWallX - botR * ik) + " " + f(totalY) + ", " + f(rWallX - botR) + " " + f(totalY) + " ";
        } else {
            p += "L " + f(rWallX) + " " + f(totalY) + " ";
        }

        // 5. Bottom Edge
        var lBotCornerX = hasLeftBottomCorner ? R : (ox + botL);
        p += "L " + f(lBotCornerX) + " " + f(totalY) + " ";

        // 6. Bottom-Left Corner
        if (hasLeftBottomCorner && R > 0.1) {
            p += "C " + f(R * ik) + " " + f(totalY) + ", 0 " + f(totalY + R * ik) + ", 0 " + f(totalY + R) + " ";
            p += "L 0 " + f(totalY) + " ";
        } else if (botL > 0.1) {
            p += "C " + f(ox + botL * ik) + " " + f(totalY) + ", " + f(ox) + " " + f(totalY - botL * ik) + ", " + f(ox) + " " + f(totalY - botL) + " ";
        } else {
            p += "L " + f(ox) + " " + f(totalY) + " ";
        }

        // 7. Left Side Wall & Transition
        if (hasLeftTopCorner && R > 0.1) {
            p += "L 0 " + f(R) + " ";
            p += "C 0 " + f(R * ik) + ", " + f(-R * ik) + " 0, " + f(-R) + " 0 ";
        } else if (hasLeftSideCorner && sR > 0.1) {
            p += "L " + f(ox) + " " + f(hh + sR) + " ";
            p += "C " + f(ox) + " " + f(hh + sR * ik) + ", " + f(ox - sR * ik) + " " + f(hh) + ", " + f(ox - sR) + " " + f(hh) + " ";
            p += "L 0 " + f(hh) + " ";
            p += "L 0 " + f(topL) + " ";
        } else if (hasLeftSideCorner || (isExpanded && dh > 0.1 && ox < -0.1)) {
            p += "L " + f(ox) + " " + f(hh) + " ";
            p += "L 0 " + f(hh) + " ";
            p += "L 0 " + f(topL) + " ";
        } else if (hasLeftBottomCorner) {
            p += "L 0 " + f(topL) + " ";
        } else {
            p += "L 0 " + f(topL) + " ";
        }

        p += "Z";
        return p;
    }

    // GPU-accelerated Shape: placed at -minX so its internal coordinate space
    // exactly matches ExpandableModule's coordinate system (0, 0 is header top-left).
    Shape {
        id: _shape
        x: -root.minX
        y: 0
        antialiasing: true
        smooth: true
        asynchronous: false
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.animatedColor
            strokeColor: "transparent"
            strokeWidth: 0

            PathSvg {
                path: root.pathData
            }
        }
    }
}
