// Reusable smoked-glass list button with unified GPU Shape (icon bay + concave fillets + uniform border)
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: root

    // ── Content ───────────────────────────────────────────────────────
    property string icon: ""
    property int    iconSize: 18
    property real   iconOffsetX: 0
    property real   iconHoverScale: 1.12
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
    // Set variant to: "light" (default) | "dark" | "neutral" | "red" | "blue" | "green" | "yellow" | "transparent"
    property string variant: "light"
    readonly property var pal: Theme.palette(variant)

    property color  accent: pal.base
    property color  accentText: variant === "neutral" ? Theme.paletteInk : pal.text
    property color  restIconColor: (variant === "neutral" || variant === "dark" || variant === "transparent")
        ? Theme.textPrimary
        : Qt.lighter(accent, 1.28)
    property bool   active: false
    property bool   highlighted: false
    property bool   hoverEnabled: true
    property bool   fillOnHover: true
    property bool   clickable: true
    property bool   externalPressed: false
    property int    cursorShape: Qt.PointingHandCursor

    property int    borderWidth: 2
    property int    radius: Theme.cardItemRadius
    property int    topLeftRadius: radius
    property int    bottomLeftRadius: radius
    property int    topRightRadius: radius
    property int    bottomRightRadius: radius
    property int    filletRadius: Theme.cardItemIconInverseRadius - borderWidth
    property int    leftPadding: 12
    property int    rightPadding: 10

    property bool   shadowEnabled: false
    property color  shadowColor: Qt.rgba(0, 0, 0, 0.55)
    property real   shadowBlur: 0.8
    property real   shadowVerticalOffset: 2
    property real   shadowHorizontalOffset: 0

    readonly property bool  hovered: rootHover.hovered
    readonly property bool  pressed: externalPressed || (root.clickable && rootMouse.pressed && rootMouse.containsMouse)
    readonly property bool  lit: highlighted || (hoverEnabled && hovered)
    readonly property bool  baySolid: highlighted || (fillOnHover && hoverEnabled && hovered)
    readonly property int   bayWidth: root.iconBayWidth >= 0 ? root.iconBayWidth : Math.min(Math.round(height), 46)
    readonly property bool  hasIconBay: !root.iconOnly && bayWidth > 0
    readonly property color iconColor: (baySolid || (fillOnHover && pressed)) ? accentText : restIconColor
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
        if (c.a <= 0.001) return Qt.rgba(0, 0, 0, 0);
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function glassColor(tintAlpha, inkAlpha) {
        return Theme.glassColor(accent, tintAlpha, inkAlpha);
    }

    function compositeOver(fg, bg) {
        var a = fg.a + bg.a * (1.0 - fg.a);
        if (a <= 0.001) return Qt.rgba(0, 0, 0, 0);
        var wb = bg.a * (1.0 - fg.a);
        return Qt.rgba(
            (fg.r * fg.a + bg.r * wb) / a,
            (fg.g * fg.a + bg.g * wb) / a,
            (fg.b * fg.a + bg.b * wb) / a,
            a
        );
    }

    property color _bgColor: {
        if (root.iconOnly) {
            if (root.pressed)  return root.fillOnHover ? root.rgba(Qt.darker(root.accent, 1.15), 0.96) : root.glassColor(0.10, 0.36);
            if (root.baySolid) return root.rgba(root.accent, 0.96);
            if (root.lit)      return root.glassColor(0.24, 0.28);
            return root.glassColor(root.active ? 0.24 : 0.14, 0.32);
        }
        if (root.pressed) return root.glassColor(root.active ? 0.22 : 0.12, 0.36);
        if (root.lit)     return root.glassColor(root.active ? 0.34 : 0.22, 0.28);
        return root.glassColor(root.active ? 0.22 : 0.12, 0.32);
    }
    Behavior on _bgColor { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }

    property color _frameColor: {
        if (root.iconOnly && root.baySolid) return root.rgba(root.accent, 0.0);
        if (root.pressed)  return (root.baySolid || root.fillOnHover) ? root.rgba(Qt.darker(root.accent, 1.15), 0.96) : root.rgba(root.accent, 0.16);
        if (root.baySolid) return root.rgba(root.accent, 0.96);
        if (root.lit)      return root.rgba(root.accent, 0.38);
        return root.rgba(root.accent, root.active ? 0.44 : 0.26);
    }
    Behavior on _frameColor { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // Soft analytic drop shadow behind the unlayered Shape (keeps CurveRenderer razor-sharp)
    RectangularShadow {
        visible: root.shadowEnabled && width > 1 && height > 1
        anchors.fill: parent
        z: -1
        offset.x: root.shadowHorizontalOffset
        offset.y: root.shadowVerticalOffset
        radius: Math.min((root.topLeftRadius + root.topRightRadius + root.bottomLeftRadius + root.bottomRightRadius) / 4, height / 2)
        blur: Math.max(4, root.shadowBlur * 10)
        spread: 0
        color: root.shadowColor
    }

    // ── Unified GPU Shape: Smoked-Glass Cavity + Seamless Frame (2x supersampled for smooth AA during scaling) ──
    Shape {
        id: btnShape
        readonly property real pad: 2
        x: -pad
        y: -pad
        width: root.width + pad * 2
        height: root.height + pad * 2
        visible: root.width > 1 && root.height > 1
        antialiasing: true
        smooth: true
        preferredRendererType: Shape.CurveRenderer

        // 2x padded supersampled texture provides 2x2 SSAA on straight edges + curves
        // and clean trilinear filtering while root.scale animates on hover/press/spawn
        layer.enabled: visible
        layer.smooth: true
        layer.mipmap: true
        layer.textureSize: Qt.size(
            Math.max(1, Math.min(2048, Math.round(width * 2))),
            Math.max(1, Math.min(2048, Math.round(height * 2)))
        )

        readonly property real ox: pad
        readonly property real oy: pad
        readonly property real w: root.width
        readonly property real h: root.height
        readonly property real bw: root.borderWidth

        readonly property real rTL: Math.max(0, Math.min(root.topLeftRadius, h / 2, w / 2))
        readonly property real rTR: Math.max(0, Math.min(root.topRightRadius, h / 2, w / 2))
        readonly property real rBR: Math.max(0, Math.min(root.bottomRightRadius, h / 2, w / 2))
        readonly property real rBL: Math.max(0, Math.min(root.bottomLeftRadius, h / 2, w / 2))

        readonly property real rawIx1: root.hasIconBay ? Math.min(root.bayWidth, Math.max(bw, w - bw)) : bw
        readonly property real rawIy1: bw
        readonly property real rawIx2: Math.max(rawIx1, w - bw)
        readonly property real rawIy2: Math.max(rawIy1, h - bw)
        readonly property bool hasCavity: (rawIx2 - rawIx1) > 0.5 && (rawIy2 - rawIy1) > 0.5

        readonly property real ix1: hasCavity ? rawIx1 : w / 2
        readonly property real iy1: hasCavity ? rawIy1 : h / 2
        readonly property real ix2: hasCavity ? rawIx2 : w / 2
        readonly property real iy2: hasCavity ? rawIy2 : h / 2
        readonly property real iw: ix2 - ix1
        readonly property real ih: iy2 - iy1

        readonly property real filletR: Math.max(0, Math.min(root.filletRadius, ih / 2, iw / 2))
        readonly property real irTL: hasCavity ? (root.hasIconBay ? filletR : Math.max(0, Math.min(rTL - bw, ih / 2, iw / 2))) : 0
        readonly property real irBL: hasCavity ? (root.hasIconBay ? filletR : Math.max(0, Math.min(rBL - bw, ih / 2, iw / 2))) : 0
        readonly property real irTR: hasCavity ? Math.max(0, Math.min(rTR - bw, ih / 2, iw / 2)) : 0
        readonly property real irBR: hasCavity ? Math.max(0, Math.min(rBR - bw, ih / 2, iw / 2)) : 0

        readonly property color frameFill: root.compositeOver(root._frameColor, root._bgColor)
        readonly property real bgOv: (hasCavity && frameFill.a >= 0.90) ? Math.min(0.75, bw * 0.5) : 0
        readonly property real bx1: ix1 - bgOv
        readonly property real by1: iy1 - bgOv
        readonly property real bx2: ix2 + bgOv
        readonly property real by2: iy2 + bgOv
        readonly property real brTL: Math.max(0, irTL + bgOv)
        readonly property real brBL: Math.max(0, irBL + bgOv)
        readonly property real brTR: Math.max(0, irTR + bgOv)
        readonly property real brBR: Math.max(0, irBR + bgOv)

        // Path 1: Smoked-glass inner cavity only (never double-blends the outer contour)
        ShapePath {
            fillColor: btnShape.hasCavity ? root._bgColor : "transparent"
            strokeColor: "transparent"
            strokeWidth: 0
            startX: btnShape.ox + btnShape.bx1 + btnShape.brTL; startY: btnShape.oy + btnShape.by1
            PathLine { x: btnShape.ox + btnShape.bx2 - btnShape.brTR; y: btnShape.oy + btnShape.by1 }
            PathArc  { x: btnShape.ox + btnShape.bx2; y: btnShape.oy + btnShape.by1 + btnShape.brTR; radiusX: btnShape.brTR; radiusY: btnShape.brTR }
            PathLine { x: btnShape.ox + btnShape.bx2; y: btnShape.oy + btnShape.by2 - btnShape.brBR }
            PathArc  { x: btnShape.ox + btnShape.bx2 - btnShape.brBR; y: btnShape.oy + btnShape.by2; radiusX: btnShape.brBR; radiusY: btnShape.brBR }
            PathLine { x: btnShape.ox + btnShape.bx1 + btnShape.brBL; y: btnShape.oy + btnShape.by2 }
            PathArc  { x: btnShape.ox + btnShape.bx1; y: btnShape.oy + btnShape.by2 - btnShape.brBL; radiusX: btnShape.brBL; radiusY: btnShape.brBL }
            PathLine { x: btnShape.ox + btnShape.bx1; y: btnShape.oy + btnShape.by1 + btnShape.brTL }
            PathArc  { x: btnShape.ox + btnShape.bx1 + btnShape.brTL; y: btnShape.oy + btnShape.by1; radiusX: btnShape.brTL; radiusY: btnShape.brTL }
        }

        // Path 2: Unified icon bay + concave fillets + uniform outer border (single outer AA pass)
        ShapePath {
            fillColor: btnShape.frameFill
            fillRule: ShapePath.OddEvenFill
            strokeColor: "transparent"
            strokeWidth: 0
            startX: btnShape.ox + btnShape.rTL; startY: btnShape.oy
            PathLine { x: btnShape.ox + btnShape.w - btnShape.rTR; y: btnShape.oy }
            PathArc  { x: btnShape.ox + btnShape.w; y: btnShape.oy + btnShape.rTR; radiusX: btnShape.rTR; radiusY: btnShape.rTR }
            PathLine { x: btnShape.ox + btnShape.w; y: btnShape.oy + btnShape.h - btnShape.rBR }
            PathArc  { x: btnShape.ox + btnShape.w - btnShape.rBR; y: btnShape.oy + btnShape.h; radiusX: btnShape.rBR; radiusY: btnShape.rBR }
            PathLine { x: btnShape.ox + btnShape.rBL; y: btnShape.oy + btnShape.h }
            PathArc  { x: btnShape.ox; y: btnShape.oy + btnShape.h - btnShape.rBL; radiusX: btnShape.rBL; radiusY: btnShape.rBL }
            PathLine { x: btnShape.ox; y: btnShape.oy + btnShape.rTL }
            PathArc  { x: btnShape.ox + btnShape.rTL; y: btnShape.oy; radiusX: btnShape.rTL; radiusY: btnShape.rTL }

            PathMove { x: btnShape.ox + btnShape.ix1 + btnShape.irTL; y: btnShape.oy + btnShape.iy1 }
            PathLine { x: btnShape.ox + btnShape.ix2 - btnShape.irTR; y: btnShape.oy + btnShape.iy1 }
            PathArc  { x: btnShape.ox + btnShape.ix2; y: btnShape.oy + btnShape.iy1 + btnShape.irTR; radiusX: btnShape.irTR; radiusY: btnShape.irTR }
            PathLine { x: btnShape.ox + btnShape.ix2; y: btnShape.oy + btnShape.iy2 - btnShape.irBR }
            PathArc  { x: btnShape.ox + btnShape.ix2 - btnShape.irBR; y: btnShape.oy + btnShape.iy2; radiusX: btnShape.irBR; radiusY: btnShape.irBR }
            PathLine { x: btnShape.ox + btnShape.ix1 + btnShape.irBL; y: btnShape.oy + btnShape.iy2 }
            PathArc  { x: btnShape.ox + btnShape.ix1; y: btnShape.oy + btnShape.iy2 - btnShape.irBL; radiusX: btnShape.irBL; radiusY: btnShape.irBL }
            PathLine { x: btnShape.ox + btnShape.ix1; y: btnShape.oy + btnShape.iy1 + btnShape.irTL }
            PathArc  { x: btnShape.ox + btnShape.ix1 + btnShape.irTL; y: btnShape.oy + btnShape.iy1; radiusX: btnShape.irTL; radiusY: btnShape.irTL }
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
        visible: root.iconOnly || root.hasIconBay
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
            anchors.horizontalCenterOffset: root.iconOffsetX
            text: root.icon
            color: root.iconColor
            font.family: Theme.font
            font.pixelSize: root.iconSize
            font.bold: true
            scale: root.pressed ? 0.92 : (root.lit ? root.iconHoverScale : 1.0)

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
            leftMargin: root.leftPadding
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
