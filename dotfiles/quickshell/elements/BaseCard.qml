import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: root

    // ── Sizing & styling tokens ──────────────────────────────────────
    // Set variant to: "light" (default) | "dark" | "neutral" | "red" | "blue" | "green" | "yellow" | "transparent"
    property string variant: "light"
    readonly property var pal: Theme.palette(variant)

    property color accent: pal.base
    property int   frameWidth: 2
    readonly property color defaultColor: glassColor(0.12, 0.32)
    property color color: defaultColor
    property real  radius: Theme.cardRadius
    property alias border: _borderCompat.border
    clip: true

    Rectangle {
        id: _borderCompat
        visible: false
        border.width: Theme.cardBorderWidth
        border.color: Theme.cardBorder
    }

    Behavior on color { ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

    function glassColor(tintAlpha, inkAlpha) {
        return Theme.glassColor(accent, tintAlpha, inkAlpha);
    }

    // ── Shadow configuration ─────────────────────────────────────────
    property bool shadowEnabled: false
    property color shadowColor: Qt.rgba(0, 0, 0, 0.65)
    property real shadowBlur: 0.8
    property real shadowVerticalOffset: 2
    property real shadowHorizontalOffset: 0

    layer.enabled: shadowEnabled
    layer.smooth: true
    layer.effect: MultiEffect {
        shadowEnabled: root.shadowEnabled
        shadowColor: root.shadowColor
        shadowBlur: root.shadowBlur
        shadowVerticalOffset: root.shadowVerticalOffset
        shadowHorizontalOffset: root.shadowHorizontalOffset
    }

    // ── Header bar configuration ─────────────────────────────────────
    property bool hasHeader: headerTitle !== "" || headerIcon !== ""
    property real headerHeight: Theme.cardHeaderHeight
    property real headerInverseRadius: radius
    property color headerColor: accent.a <= 0.001
        ? Qt.rgba(0, 0, 0, 0)
        : Qt.rgba(accent.r, accent.g, accent.b, variant === "dark" ? 0.55 : 0.30)
    property real frameBottomOpacity: 0.25
    property string headerTitle: ""
    property string headerIcon: ""
    property real headerRightMargin: 7
    property real headerLeftMargin: 15

    Behavior on headerColor { ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

    readonly property bool _hasChrome: root.color.a > 0.001

    // ── Header aliases & slots ───────────────────────────────────────
    property alias headerBar: headerBarItem
    property alias headerRow: headerStandardRow
    property alias headerControls: headerControlRow.data
    property alias headerContent: headerCustomItem.data
    property alias titleText: headerTitleText
    property alias iconText: headerIconText
    property alias headerControlRow: headerControlRow
    readonly property Item headerBottom: headerBarItem

    // ── Smoked-Glass Base Shape (behind card children) ───────────────
    Shape {
        id: bgShape
        anchors.fill: parent
        z: -1
        visible: width > 1 && height > 1 && root._hasChrome
        antialiasing: true
        smooth: true
        preferredRendererType: Shape.CurveRenderer

        readonly property real w: width
        readonly property real h: height
        readonly property real r: Math.max(0, Math.min(root.radius, h / 2, w / 2))

        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            strokeWidth: 0
            startX: bgShape.r; startY: 0
            PathLine { x: bgShape.w - bgShape.r; y: 0 }
            PathArc  { x: bgShape.w; y: bgShape.r; radiusX: bgShape.r; radiusY: bgShape.r }
            PathLine { x: bgShape.w; y: bgShape.h - bgShape.r }
            PathArc  { x: bgShape.w - bgShape.r; y: bgShape.h; radiusX: bgShape.r; radiusY: bgShape.r }
            PathLine { x: bgShape.r; y: bgShape.h }
            PathArc  { x: 0; y: bgShape.h - bgShape.r; radiusX: bgShape.r; radiusY: bgShape.r }
            PathLine { x: 0; y: bgShape.r }
            PathArc  { x: bgShape.r; y: 0; radiusX: bgShape.r; radiusY: bgShape.r }
        }
    }

    // ── Unified Frame Shape: Header + Concave Fillets + Gradually Fading Border ──
    Shape {
        id: frameShape
        anchors.fill: parent
        z: 25
        visible: width > 1 && height > 1 && root._hasChrome && (root.hasHeader || root.frameWidth > 0)
        antialiasing: true
        smooth: true
        preferredRendererType: Shape.CurveRenderer

        readonly property real w: width
        readonly property real h: height
        readonly property real bw: root.frameWidth
        readonly property real r: Math.max(0, Math.min(root.radius, h / 2, w / 2))

        readonly property real ix1: bw
        readonly property real iy1: root.hasHeader ? Math.min(root.headerHeight, Math.max(bw, h - bw)) : bw
        readonly property real ix2: Math.max(ix1, w - bw)
        readonly property real iy2: Math.max(iy1, h - bw)
        readonly property real iw: ix2 - ix1
        readonly property real ih: iy2 - iy1

        readonly property real irTop: root.hasHeader
            ? Math.max(0, Math.min(root.headerInverseRadius - bw, ih / 2, iw / 2))
            : Math.max(0, Math.min(r - bw, ih / 2, iw / 2))
        readonly property real irBot: Math.max(0, Math.min(r - bw, ih / 2, iw / 2))
        readonly property real fadeStartY: root.hasHeader ? iy1 : 0

        ShapePath {
            fillRule: ShapePath.OddEvenFill
            strokeColor: "transparent"
            strokeWidth: 0
            fillGradient: LinearGradient {
                x1: 0
                y1: frameShape.fadeStartY
                x2: 0
                y2: Math.max(frameShape.fadeStartY + 1, frameShape.h)
                GradientStop { position: 0.0; color: root.headerColor }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(root.headerColor.r, root.headerColor.g, root.headerColor.b, root.headerColor.a * root.frameBottomOpacity)
                }
            }

            startX: frameShape.r; startY: 0
            PathLine { x: frameShape.w - frameShape.r; y: 0 }
            PathArc  { x: frameShape.w; y: frameShape.r; radiusX: frameShape.r; radiusY: frameShape.r }
            PathLine { x: frameShape.w; y: frameShape.h - frameShape.r }
            PathArc  { x: frameShape.w - frameShape.r; y: frameShape.h; radiusX: frameShape.r; radiusY: frameShape.r }
            PathLine { x: frameShape.r; y: frameShape.h }
            PathArc  { x: 0; y: frameShape.h - frameShape.r; radiusX: frameShape.r; radiusY: frameShape.r }
            PathLine { x: 0; y: frameShape.r }
            PathArc  { x: frameShape.r; y: 0; radiusX: frameShape.r; radiusY: frameShape.r }

            PathMove { x: frameShape.ix1 + frameShape.irTop; y: frameShape.iy1 }
            PathLine { x: frameShape.ix2 - frameShape.irTop; y: frameShape.iy1 }
            PathArc  { x: frameShape.ix2; y: frameShape.iy1 + frameShape.irTop; radiusX: frameShape.irTop; radiusY: frameShape.irTop }
            PathLine { x: frameShape.ix2; y: frameShape.iy2 - frameShape.irBot }
            PathArc  { x: frameShape.ix2 - frameShape.irBot; y: frameShape.iy2; radiusX: frameShape.irBot; radiusY: frameShape.irBot }
            PathLine { x: frameShape.ix1 + frameShape.irBot; y: frameShape.iy2 }
            PathArc  { x: frameShape.ix1; y: frameShape.iy2 - frameShape.irBot; radiusX: frameShape.irBot; radiusY: frameShape.irBot }
            PathLine { x: frameShape.ix1; y: frameShape.iy1 + frameShape.irTop }
            PathArc  { x: frameShape.ix1 + frameShape.irTop; y: frameShape.iy1; radiusX: frameShape.irTop; radiusY: frameShape.irTop }
        }
    }

    // ── Header Content Container (transparent; background drawn by frameShape) ──
    Item {
        id: headerBarItem
        z: 26
        visible: root.hasHeader
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: visible ? root.headerHeight : 0
        clip: true

        // Standard Title + Right Controls Row
        RowLayout {
            id: headerStandardRow
            visible: root.headerTitle !== "" || root.headerIcon !== ""
            anchors.fill: parent
            anchors.leftMargin: root.headerLeftMargin
            anchors.rightMargin: root.headerRightMargin
            spacing: 8

            Text {
                id: headerIconText
                visible: root.headerIcon !== ""
                text: root.headerIcon
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                id: headerTitleText
                visible: root.headerTitle !== ""
                text: root.headerTitle
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                id: headerControlRow
                spacing: 8
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
        }

        // Custom Header Slot (e.g. for custom navigation or layout)
        Item {
            id: headerCustomItem
            anchors.fill: parent
            visible: !headerStandardRow.visible
        }
    }
}
