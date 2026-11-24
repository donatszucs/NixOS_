import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: root

    // ── Sizing & styling tokens ──────────────────────────────────────
    property color accent: Theme.palettePaper
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
        var a = tintAlpha + inkAlpha * (1.0 - tintAlpha);
        if (a <= 0.001) return Qt.rgba(0, 0, 0, 0);
        var w = inkAlpha * (1.0 - tintAlpha);
        return Qt.rgba(
            (accent.r * tintAlpha + Theme.paletteInk.r * w) / a,
            (accent.g * tintAlpha + Theme.paletteInk.g * w) / a,
            (accent.b * tintAlpha + Theme.paletteInk.b * w) / a,
            a
        );
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
    property color headerColor: Qt.rgba(accent.r, accent.g, accent.b, 0.30)
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
        readonly property real k: 0.44771525
        readonly property real r: Math.max(0, Math.min(root.radius, h / 2, w / 2))

        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            strokeWidth: 0
            startX: bgShape.r; startY: 0
            PathLine  { x: bgShape.w - bgShape.r; y: 0 }
            PathCubic { control1X: bgShape.w - bgShape.r * bgShape.k; control1Y: 0; control2X: bgShape.w; control2Y: bgShape.r * bgShape.k; x: bgShape.w; y: bgShape.r }
            PathLine  { x: bgShape.w; y: bgShape.h - bgShape.r }
            PathCubic { control1X: bgShape.w; control1Y: bgShape.h - bgShape.r * bgShape.k; control2X: bgShape.w - bgShape.r * bgShape.k; control2Y: bgShape.h; x: bgShape.w - bgShape.r; y: bgShape.h }
            PathLine  { x: bgShape.r; y: bgShape.h }
            PathCubic { control1X: bgShape.r * bgShape.k; control1Y: bgShape.h; control2X: 0; control2Y: bgShape.h - bgShape.r * bgShape.k; x: 0; y: bgShape.h - bgShape.r }
            PathLine  { x: 0; y: bgShape.r }
            PathCubic { control1X: 0; control1Y: bgShape.r * bgShape.k; control2X: bgShape.r * bgShape.k; control2Y: 0; x: bgShape.r; y: 0 }
        }
    }

    // ── Unified Frame Shape: Header + Concave Fillets + Uniform Border ──
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
        readonly property real k: 0.44771525
        readonly property real r: Math.max(0, Math.min(root.radius, h / 2, w / 2))

        readonly property real ix1: bw
        readonly property real iy1: root.hasHeader ? Math.min(root.headerHeight, Math.max(bw, h - bw)) : bw
        readonly property real ix2: Math.max(ix1, w - bw)
        readonly property real iy2: Math.max(iy1, h - bw)
        readonly property real iw: ix2 - ix1
        readonly property real ih: iy2 - iy1

        readonly property real irTop: root.hasHeader
            ? Math.max(0, Math.min(Theme.cardHeaderInverseRadius - bw, ih / 2, iw / 2))
            : Math.max(0, Math.min(r - bw, ih / 2, iw / 2))
        readonly property real irBot: Math.max(0, Math.min(r - bw, ih / 2, iw / 2))

        ShapePath {
            fillColor: root.headerColor
            fillRule: ShapePath.OddEvenFill
            strokeColor: "transparent"
            strokeWidth: 0
            startX: frameShape.r; startY: 0
            PathLine  { x: frameShape.w - frameShape.r; y: 0 }
            PathCubic { control1X: frameShape.w - frameShape.r * frameShape.k; control1Y: 0; control2X: frameShape.w; control2Y: frameShape.r * frameShape.k; x: frameShape.w; y: frameShape.r }
            PathLine  { x: frameShape.w; y: frameShape.h - frameShape.r }
            PathCubic { control1X: frameShape.w; control1Y: frameShape.h - frameShape.r * frameShape.k; control2X: frameShape.w - frameShape.r * frameShape.k; control2Y: frameShape.h; x: frameShape.w - frameShape.r; y: frameShape.h }
            PathLine  { x: frameShape.r; y: frameShape.h }
            PathCubic { control1X: frameShape.r * frameShape.k; control1Y: frameShape.h; control2X: 0; control2Y: frameShape.h - frameShape.r * frameShape.k; x: 0; y: frameShape.h - frameShape.r }
            PathLine  { x: 0; y: frameShape.r }
            PathCubic { control1X: 0; control1Y: frameShape.r * frameShape.k; control2X: frameShape.r * frameShape.k; control2Y: 0; x: frameShape.r; y: 0 }

            PathMove  { x: frameShape.ix1 + frameShape.irTop; y: frameShape.iy1 }
            PathLine  { x: frameShape.ix2 - frameShape.irTop; y: frameShape.iy1 }
            PathCubic { control1X: frameShape.ix2 - frameShape.irTop * frameShape.k; control1Y: frameShape.iy1; control2X: frameShape.ix2; control2Y: frameShape.iy1 + frameShape.irTop * frameShape.k; x: frameShape.ix2; y: frameShape.iy1 + frameShape.irTop }
            PathLine  { x: frameShape.ix2; y: frameShape.iy2 - frameShape.irBot }
            PathCubic { control1X: frameShape.ix2; control1Y: frameShape.iy2 - frameShape.irBot * frameShape.k; control2X: frameShape.ix2 - frameShape.irBot * frameShape.k; control2Y: frameShape.iy2; x: frameShape.ix2 - frameShape.irBot; y: frameShape.iy2 }
            PathLine  { x: frameShape.ix1 + frameShape.irBot; y: frameShape.iy2 }
            PathCubic { control1X: frameShape.ix1 + frameShape.irBot * frameShape.k; control1Y: frameShape.iy2; control2X: frameShape.ix1; control2Y: frameShape.iy2 - frameShape.irBot * frameShape.k; x: frameShape.ix1; y: frameShape.iy2 - frameShape.irBot }
            PathLine  { x: frameShape.ix1; y: frameShape.iy1 + frameShape.irTop }
            PathCubic { control1X: frameShape.ix1; control1Y: frameShape.iy1 + frameShape.irTop * frameShape.k; control2X: frameShape.ix1 + frameShape.irTop * frameShape.k; control2Y: frameShape.iy1; x: frameShape.ix1 + frameShape.irTop; y: frameShape.iy1 }
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
