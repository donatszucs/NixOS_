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
    readonly property bool hasLeftSideCorner: isExpanded && (leftCornerStyle === "side") && (overlayX < 0) && !touchesLeftEdge
    readonly property bool hasRightSideCorner: isExpanded && (rightCornerStyle === "side") && ((overlayX + overlayWidth) > headerWidth) && !touchesRightEdge
    readonly property bool hasLeftBottomCorner: (leftCornerStyle === "bottom")
    readonly property bool hasRightBottomCorner: (rightCornerStyle === "bottom")
    readonly property bool hasLeftTopCorner: (leftCornerStyle === "top")
    readonly property bool hasRightTopCorner: (rightCornerStyle === "top")

    // Dynamic bounding box covering the entire outer silhouette (used by Quickshell Regions)
    readonly property real minX: Math.min(
        hasLeftTopCorner ? -cornerRadius : 0,
        hasLeftSideCorner ? (overlayX - cornerRadius) : (isExpanded ? overlayX : 0)
    )
    readonly property real maxX: Math.max(
        hasRightTopCorner ? (headerWidth + cornerRadius) : headerWidth,
        hasRightSideCorner ? (overlayX + overlayWidth + cornerRadius) : (isExpanded ? (overlayX + overlayWidth) : headerWidth)
    )
    readonly property real maxY: (isExpanded ? (headerHeight + overlayHeight) : headerHeight) + ((hasLeftBottomCorner || hasRightBottomCorner) ? cornerRadius : 0)

    // Position and size relative to ExpandableModule
    x: minX
    y: 0
    width: Math.max(1, maxX - minX)
    height: Math.max(1, maxY)
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

        // ── Anti-spike interpolation ──────────────────────────────────────
        // When dh is small the height animation has nearly finished but the width
        // animation may still be running (ox is still negative / rWallX still past hw).
        // If we let ox remain negative while sideR drops below 0.1 and the path switches
        // branches, the shape draws a diagonal spike from (ox, hh) to (0, topL).
        // Fix: linearly interpolate ox → 0 and the right-wall → hw as dh → 0 over a
        // transition zone of 2*R pixels so the shape collapses cleanly.
        var _fadeZone = R * 2;
        var _fadeFactor = (_fadeZone > 0) ? Math.min(1.0, dh / _fadeZone) : 1.0;
        // ox: effective overlay left edge, faded toward 0 as dh → 0
        var ox = overlayX * _fadeFactor;
        // rWallExtentFaded: effective overlay right edge, faded toward hw as dh → 0
        var rWallExtentFaded = hw + (overlayX + ow - hw) * _fadeFactor;

        var topL = hasLeftTopCorner ? 0 : topLeftRadius;
        var topR = hasRightTopCorner ? 0 : topRightRadius;

        // Effective expanded and collapsed corner targets
        var cBotL = collapsedBottomLeftRadius > 0 ? collapsedBottomLeftRadius : bottomLeftRadius;
        var cBotR = collapsedBottomRightRadius > 0 ? collapsedBottomRightRadius : bottomRightRadius;
        var eBotL = expandedBottomLeftRadius > 0 ? expandedBottomLeftRadius : bottomLeftRadius;
        var eBotR = expandedBottomRightRadius > 0 ? expandedBottomRightRadius : bottomRightRadius;

        // Side inverse fillet size (maximum R, limited by dh / 2 so it doesn't collide with bottom corner)
        var sideR = Math.min(R, dh / 2);

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
            botL = Math.min(botL, Math.max(0, dh - sideR));
        }
        if (hasRightSideCorner) {
            botR = Math.min(botR, Math.max(0, dh - sideR));
        }
        if (hasLeftTopCorner) {
            botL = Math.min(botL, Math.max(0, totalY - R));
        }
        if (hasRightTopCorner) {
            botR = Math.min(botR, Math.max(0, totalY - R));
        }

        var p = "";

        // 1. Header Top-Left
        if (hasLeftTopCorner && R > 0.1) {
            // Start at the left-most tip of the top inverse fillet
            p += "M " + (-R) + " 0 ";
        } else if (topL > 0.1) {
            p += "M 0 " + topL + " ";
            p += "A " + topL + " " + topL + " 0 0 1 " + topL + " 0 ";
        } else {
            p += "M 0 0 ";
        }

        // 2. Header Top Edge & Top-Right
        if (hasRightTopCorner && R > 0.1) {
            // Extend top edge along bar to right tip, then curve down to header right edge
            p += "L " + (hw + R) + " 0 ";
            p += "A " + R + " " + R + " 0 0 0 " + hw + " " + R + " ";
        } else if (topR > 0.1) {
            p += "L " + (hw - topR) + " 0 ";
            p += "A " + topR + " " + topR + " 0 0 1 " + hw + " " + topR + " ";
        } else {
            p += "L " + hw + " 0 ";
        }

        // 3. Right Side Wall & Transition
        var rWallX = isExpanded ? rWallExtentFaded : hw;

        if (hasRightSideCorner && sideR > 0.1) {
            // Header button right wall down to bar line, then step outward along bar bottom to inverse fillet
            p += "L " + hw + " " + hh + " ";
            p += "L " + (rWallX + sideR) + " " + hh + " ";
            p += "A " + sideR + " " + sideR + " 0 0 0 " + rWallX + " " + (hh + sideR) + " ";
            p += "L " + rWallX + " " + (totalY - botR) + " ";
        } else if (hasRightBottomCorner) {
            // Screen right bezel wall straight down to totalY
            p += "L " + hw + " " + totalY + " ";
        } else {
            // Flush right wall (NowPlayingModule, top corner, or collapsed pill):
            // Straight vertical wall from top right directly to (totalY - botR).
            // No stop at hh, no spike, no backtracking!
            p += "L " + rWallX + " " + (totalY - botR) + " ";
        }

        // 4. Bottom-Right Corner
        if (hasRightBottomCorner && R > 0.1) {
            p += "L " + hw + " " + (totalY + R) + " ";
            p += "A " + R + " " + R + " 0 0 0 " + (hw - R) + " " + totalY + " ";
        } else if (botR > 0.1) {
            p += "A " + botR + " " + botR + " 0 0 1 " + (rWallX - botR) + " " + totalY + " ";
        } else {
            p += "L " + rWallX + " " + totalY + " ";
        }

        // 5. Bottom Edge
        var lBotCornerX = hasLeftBottomCorner ? R : (ox + botL);
        p += "L " + lBotCornerX + " " + totalY + " ";

        // 6. Bottom-Left Corner
        if (hasLeftBottomCorner && R > 0.1) {
            p += "A " + R + " " + R + " 0 0 0 0 " + (totalY + R) + " ";
            p += "L 0 " + totalY + " ";
        } else if (botL > 0.1) {
            p += "A " + botL + " " + botL + " 0 0 1 " + ox + " " + (totalY - botL) + " ";
        } else {
            p += "L " + ox + " " + totalY + " ";
        }

        // 7. Left Side Wall & Transition
        if (hasLeftTopCorner && R > 0.1) {
            // Left wall straight up to R, then inverse fillet curving outward to the top edge
            p += "L 0 " + R + " ";
            p += "A " + R + " " + R + " 0 0 0 " + (-R) + " 0 ";
        } else if (hasLeftSideCorner && sideR > 0.1) {
            // Dropdown left wall up to inverse fillet, curve along bar bottom to header left edge
            p += "L " + ox + " " + (hh + sideR) + " ";
            p += "A " + sideR + " " + sideR + " 0 0 0 " + (ox - sideR) + " " + hh + " ";
            p += "L 0 " + hh + " ";
            p += "L 0 " + topL + " ";
        } else if (hasLeftBottomCorner) {
            // Screen left bezel wall straight up to topL
            p += "L 0 " + topL + " ";
        } else {
            // Flush left wall (LightSwitchModule or collapsed pill):
            // Straight vertical wall from (ox, totalY - botL) directly up to (0, topL).
            // No stop at hh, no spike, no backtracking!
            p += "L 0 " + topL + " ";
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
        preferredRendererType: Shape.GeometryRenderer

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
