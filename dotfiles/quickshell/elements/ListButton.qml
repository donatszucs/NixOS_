// Reusable smoked-glass list button with unified GPU Shape (icon bay + concave fillets + uniform border)
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

Item {
    id: root

    // ── Content ───────────────────────────────────────────────────────
    property string icon: ""
    property int    iconSize: 18
    property bool   iconSpinning: false
    property bool   iconOnly: false
    property int    iconBayWidth: -1

    property string text: ""
    property string subtext: ""
    property real   subtextOpacity: 0.6
    property string trailingIcon: ""

    property alias  iconContent: iconSlot.data
    property alias  content:     bodySlot.data
    property alias  trailing:    trailingSlot.data

    // ── Appearance & State ────────────────────────────────────────────
    property color  accent: Theme.palettePaper
    property color  accentText: Theme.paletteInk
    property bool   active: false
    property bool   highlighted: false
    property bool   hoverEnabled: true
    property bool   clickable: true
    property int    cursorShape: Qt.PointingHandCursor

    property int    borderWidth: 2
    property int    radius: Theme.cardItemRadius
    property int    topLeftRadius: radius
    property int    bottomLeftRadius: radius
    property int    topRightRadius: radius
    property int    bottomRightRadius: radius
    property int    rightPadding: 10

    readonly property bool  hovered: rootHover.hovered
    readonly property bool  pressed: root.clickable && rootMouse.pressed && rootMouse.containsMouse
    readonly property bool  lit: highlighted || (hoverEnabled && hovered)
    readonly property int   bayWidth: root.iconBayWidth > 0 ? root.iconBayWidth : Math.min(Math.round(height), 46)
    readonly property color iconColor: (lit || pressed) ? accentText : Qt.lighter(accent, 1.28)
    readonly property color primaryTextColor: lit ? Qt.lighter(Theme.textPrimary, 1.08) : Theme.textPrimary
    readonly property real  trailingWidth: trailingSlot.visible ? trailingSlot.implicitWidth : 0

    signal clicked()
    signal entered()

    implicitHeight: Theme.listHeight
    implicitWidth: 180

    transformOrigin: Item.Center
    scale: pressed ? (width > 240 ? 0.985 : 0.96) : 1.0
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    function rgba(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

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

    property color _bgColor: {
        if (root.iconOnly) {
            if (root.pressed) return root.rgba(Qt.darker(root.accent, 1.15), 0.96);
            if (root.lit)     return root.rgba(root.accent, 0.96);
            return root.glassColor(root.active ? 0.24 : 0.16, 0.30);
        }
        if (root.pressed) return root.glassColor(root.active ? 0.22 : 0.14, 0.34);
        if (root.lit)     return root.glassColor(root.active ? 0.34 : 0.26, 0.28);
        return root.glassColor(root.active ? 0.22 : 0.14, 0.30);
    }
    Behavior on _bgColor { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }

    property color _frameColor: {
        if (root.iconOnly && (root.lit || root.pressed)) return root.rgba(root.accent, 0.0);
        if (root.pressed) return root.rgba(Qt.darker(root.accent, 1.15), 0.96);
        if (root.lit)     return root.rgba(root.accent, 0.96);
        return root.rgba(root.accent, root.active ? 0.44 : 0.28);
    }
    Behavior on _frameColor { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // ── Unified GPU Shape: Smoked-Glass Base + Seamless Frame (Icon Bay + Fillets + Border) ──
    Shape {
        id: btnShape
        anchors.fill: parent
        visible: width > 1 && height > 1
        antialiasing: true
        smooth: true
        preferredRendererType: Shape.CurveRenderer

        readonly property real w: width
        readonly property real h: height
        readonly property real bw: root.borderWidth
        readonly property real k: 0.44771525

        readonly property real rTL: Math.max(0, Math.min(root.topLeftRadius, h / 2, w / 2))
        readonly property real rTR: Math.max(0, Math.min(root.topRightRadius, h / 2, w / 2))
        readonly property real rBR: Math.max(0, Math.min(root.bottomRightRadius, h / 2, w / 2))
        readonly property real rBL: Math.max(0, Math.min(root.bottomLeftRadius, h / 2, w / 2))

        readonly property real ix1: root.iconOnly ? bw : Math.min(root.bayWidth, Math.max(bw, w - bw))
        readonly property real iy1: bw
        readonly property real ix2: Math.max(ix1, w - bw)
        readonly property real iy2: Math.max(iy1, h - bw)
        readonly property real iw: ix2 - ix1
        readonly property real ih: iy2 - iy1

        readonly property real filletR: Math.max(0, Math.min(Theme.cardItemIconInverseRadius - bw, ih / 2, iw / 2))
        readonly property real irTL: root.iconOnly ? Math.max(0, Math.min(rTL - bw, ih / 2, iw / 2)) : filletR
        readonly property real irBL: root.iconOnly ? Math.max(0, Math.min(rBL - bw, ih / 2, iw / 2)) : filletR
        readonly property real irTR: Math.max(0, Math.min(rTR - bw, ih / 2, iw / 2))
        readonly property real irBR: Math.max(0, Math.min(rBR - bw, ih / 2, iw / 2))

        // Path 1: Smoked-glass base
        ShapePath {
            fillColor: root._bgColor
            strokeColor: "transparent"
            strokeWidth: 0
            startX: btnShape.rTL; startY: 0
            PathLine  { x: btnShape.w - btnShape.rTR; y: 0 }
            PathCubic { control1X: btnShape.w - btnShape.rTR * btnShape.k; control1Y: 0; control2X: btnShape.w; control2Y: btnShape.rTR * btnShape.k; x: btnShape.w; y: btnShape.rTR }
            PathLine  { x: btnShape.w; y: btnShape.h - btnShape.rBR }
            PathCubic { control1X: btnShape.w; control1Y: btnShape.h - btnShape.rBR * btnShape.k; control2X: btnShape.w - btnShape.rBR * btnShape.k; control2Y: btnShape.h; x: btnShape.w - btnShape.rBR; y: btnShape.h }
            PathLine  { x: btnShape.rBL; y: btnShape.h }
            PathCubic { control1X: btnShape.rBL * btnShape.k; control1Y: btnShape.h; control2X: 0; control2Y: btnShape.h - btnShape.rBL * btnShape.k; x: 0; y: btnShape.h - btnShape.rBL }
            PathLine  { x: 0; y: btnShape.rTL }
            PathCubic { control1X: 0; control1Y: btnShape.rTL * btnShape.k; control2X: btnShape.rTL * btnShape.k; control2Y: 0; x: btnShape.rTL; y: 0 }
        }

        // Path 2: Unified icon bay + concave fillets + uniform outer border (zero overlap / zero seam)
        ShapePath {
            fillColor: root._frameColor
            fillRule: ShapePath.OddEvenFill
            strokeColor: "transparent"
            strokeWidth: 0
            startX: btnShape.rTL; startY: 0
            PathLine  { x: btnShape.w - btnShape.rTR; y: 0 }
            PathCubic { control1X: btnShape.w - btnShape.rTR * btnShape.k; control1Y: 0; control2X: btnShape.w; control2Y: btnShape.rTR * btnShape.k; x: btnShape.w; y: btnShape.rTR }
            PathLine  { x: btnShape.w; y: btnShape.h - btnShape.rBR }
            PathCubic { control1X: btnShape.w; control1Y: btnShape.h - btnShape.rBR * btnShape.k; control2X: btnShape.w - btnShape.rBR * btnShape.k; control2Y: btnShape.h; x: btnShape.w - btnShape.rBR; y: btnShape.h }
            PathLine  { x: btnShape.rBL; y: btnShape.h }
            PathCubic { control1X: btnShape.rBL * btnShape.k; control1Y: btnShape.h; control2X: 0; control2Y: btnShape.h - btnShape.rBL * btnShape.k; x: 0; y: btnShape.h - btnShape.rBL }
            PathLine  { x: 0; y: btnShape.rTL }
            PathCubic { control1X: 0; control1Y: btnShape.rTL * btnShape.k; control2X: btnShape.rTL * btnShape.k; control2Y: 0; x: btnShape.rTL; y: 0 }

            PathMove  { x: btnShape.ix1 + btnShape.irTL; y: btnShape.iy1 }
            PathLine  { x: btnShape.ix2 - btnShape.irTR; y: btnShape.iy1 }
            PathCubic { control1X: btnShape.ix2 - btnShape.irTR * btnShape.k; control1Y: btnShape.iy1; control2X: btnShape.ix2; control2Y: btnShape.iy1 + btnShape.irTR * btnShape.k; x: btnShape.ix2; y: btnShape.iy1 + btnShape.irTR }
            PathLine  { x: btnShape.ix2; y: btnShape.iy2 - btnShape.irBR }
            PathCubic { control1X: btnShape.ix2; control1Y: btnShape.iy2 - btnShape.irBR * btnShape.k; control2X: btnShape.ix2 - btnShape.irBR * btnShape.k; control2Y: btnShape.iy2; x: btnShape.ix2 - btnShape.irBR; y: btnShape.iy2 }
            PathLine  { x: btnShape.ix1 + btnShape.irBL; y: btnShape.iy2 }
            PathCubic { control1X: btnShape.ix1 + btnShape.irBL * btnShape.k; control1Y: btnShape.iy2; control2X: btnShape.ix1; control2Y: btnShape.iy2 - btnShape.irBL * btnShape.k; x: btnShape.ix1; y: btnShape.iy2 - btnShape.irBL }
            PathLine  { x: btnShape.ix1; y: btnShape.iy1 + btnShape.irTL }
            PathCubic { control1X: btnShape.ix1; control1Y: btnShape.iy1 + btnShape.irTL * btnShape.k; control2X: btnShape.ix1 + btnShape.irTL * btnShape.k; control2Y: btnShape.iy1; x: btnShape.ix1 + btnShape.irTL; y: btnShape.iy1 }
        }
    }

    // ── Interaction (below z:2 interactive children) ──────────────────
    HoverHandler {
        id: rootHover
        onHoveredChanged: if (hovered) root.entered()
    }

    MouseArea {
        id: rootMouse
        anchors.fill: parent
        z: 1
        enabled: root.clickable
        cursorShape: root.clickable ? root.cursorShape : Qt.ArrowCursor
        onClicked: root.clicked()
    }

    // ── Icon Container (Left Bay or Centered when iconOnly) ───────────
    Item {
        id: iconArea
        z: 2
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }
        width: root.iconOnly ? parent.width : root.bayWidth

        Item {
            id: iconSlot
            anchors.fill: parent
            visible: children.length > 0
        }

        Text {
            id: defaultIconText
            visible: !iconSlot.visible && root.icon !== ""
            anchors.centerIn: parent
            text: root.icon
            color: root.iconColor
            font.family: Theme.font
            font.pixelSize: root.iconSize
            font.bold: true
            scale: root.pressed ? 0.92 : (root.lit ? 1.12 : 1.0)

            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: root.iconSpinning
                onStopped: defaultIconText.rotation = 0
            }
        }
    }

    // ── Body & Trailing Controls ──────────────────────────────────────
    RowLayout {
        id: bodyRow
        visible: !root.iconOnly
        z: 2
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: iconArea.right
            right: parent.right
            topMargin: root.borderWidth
            bottomMargin: root.borderWidth
            leftMargin: 12
            rightMargin: root.rightPadding
        }
        spacing: 0

        RowLayout {
            id: bodySlot
            visible: children.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
        }

        ColumnLayout {
            visible: !bodySlot.visible
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                visible: root.text !== ""
                Layout.fillWidth: true
                text: root.text
                color: root.primaryTextColor
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            Text {
                visible: root.subtext !== ""
                Layout.fillWidth: true
                text: root.subtext
                color: root.primaryTextColor
                opacity: root.lit ? Math.min(1.0, root.subtextOpacity + 0.15) : root.subtextOpacity
                font.family: Theme.font
                font.pixelSize: Math.round(Theme.fontSize * 0.75)
                elide: Text.ElideRight
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }

        RowLayout {
            id: trailingSlot
            visible: children.length > 0
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: implicitWidth > 0 ? 8 : 0
            spacing: 6
        }

        Text {
            visible: root.trailingIcon !== ""
            text: root.trailingIcon
            color: Qt.lighter(root.accent, 1.25)
            font.family: Theme.font
            font.pixelSize: 15
            font.bold: true
            opacity: root.lit ? 0.85 : 0.0
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 6

            transform: Translate {
                x: root.lit ? 0 : -5
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
    }
}
