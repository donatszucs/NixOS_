import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

ModuleButton {
    id: root
    clip: false

    // ── Pill Scale & Hover/Press Animation (matching HeaderButton) ───
    property bool hasScaleAnimation: true
    property real normalScale: 1.0
    property real hoverScale: 0.98
    property real pressedScale: 0.90

    property alias pill: pillBg
    readonly property real pillScale: pillBg.scale

    property real percent: 0
    property bool animatePercent: true
    property string pillText: ""
    property string pillVariant: root.variant
    property var pillPal: Theme.palette(pillVariant)
    property int pillRadius: expanded ? pillExpandedRadius : Theme.pillCollapsedRadius
    property int pillExpandedRadius: Theme.pillExpandedRadius
    property int pillHeight: Theme.pillHeight
    property int pillPaddingH: expanded ? Theme.pillExpandedPaddingH : Theme.pillCollapsedPaddingH
    property real pillColorOpacity: root.colorOpacity 
    property var pillBorderColor: null
    readonly property color effectiveBorderColor: pillBorderColor !== null
        ? pillBorderColor
        : Qt.rgba(root.pillPal.pillBorder.r, root.pillPal.pillBorder.g, root.pillPal.pillBorder.b, root.pillPal.pillBorder.a * root.pillColorOpacity * gradientOpacityBorder)
    property var pillFillColor: null
    readonly property color effectiveFillColor: pillFillColor !== null
        ? pillFillColor
        : root.pillPal.pillFill

    // ── Shadow configuration ─────────────────────────────────────────
    property bool shadowEnabled: true
    property color shadowColor: Qt.rgba(0, 0, 0, 0.85)
    property real shadowBlur: 0.8
    property real shadowVerticalOffset: 2
    property real shadowHorizontalOffset: 0

    property real gradientOpacityBorder: root.expanded ? 0.0 : 1.0
    property real gradientOpacityTop: 0.4
    property real gradientOpacityMid: 0.2
    property real gradientOpacityBottom: 0.8

    property color gradientTop : root.pillPal.pillFill
    property color gradientMid : root.pillPal.pillFill
    property color gradientBottom : root.pillPal.pillFill

    property real gradientTopHeightPx: 60

    property string bgImageSource: ""
    property real bgImageOpacity: 0.35
    property real bgImageBrightness: 0.35
    property real bgImageContrast: 0.0
    property real bgImageDarkOverlayOpacity: 0.0

    expanded: false
    property int expandedTopMargin: Theme.pillExpandedMargin
    property int expandedBottomMargin: Theme.pillExpandedMargin

    property real pillTopLeftRadius: pillRadius
    property real pillTopRightRadius: pillRadius
    property real pillBottomLeftRadius: pillRadius
    property real pillBottomRightRadius: pillRadius

    Behavior on pillHeight {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    Behavior on pillPaddingH {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    Behavior on pillTopLeftRadius {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    Behavior on pillTopRightRadius {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    Behavior on pillBottomLeftRadius {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    Behavior on pillBottomRightRadius {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }

    // Smooth percentage animation
    property real animatedPercent: percent
    Behavior on animatedPercent {
        enabled: root.animatePercent
        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    label: pillText
    textColor: "transparent"

    // Outer pill background
    Rectangle {
        id: pillBg
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, parent.width - root.pillPaddingH)
        y: root.expanded ? root.expandedTopMargin : Math.round((parent.height - root.pillHeight) / 2)
        height: root.expanded ? Math.max(0, parent.height - root.expandedTopMargin - root.expandedBottomMargin) : root.pillHeight
        clip: false
        color: "transparent"

        topLeftRadius: root.pillTopLeftRadius
        topRightRadius: root.pillTopRightRadius
        bottomLeftRadius: root.pillBottomLeftRadius
        bottomRightRadius: root.pillBottomRightRadius

        transformOrigin: Item.Center
        scale: (!root.enabled || root.expanded || !root.hasScaleAnimation)
            ? root.normalScale
            : (root.pressed ? root.pressedScale : (root.hovered ? root.hoverScale : root.normalScale))

        Behavior on scale {
            NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: background
            anchors.fill: parent
            z: -1
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius

            color: Qt.rgba(root.pillPal.pillTrack.r, root.pillPal.pillTrack.g, root.pillPal.pillTrack.b, root.pillPal.pillTrack.a * root.pillColorOpacity)
            gradient: root.expanded ? pillGradient : null

            layer.enabled: root.shadowEnabled
            layer.smooth: true
            layer.effect: MultiEffect {
                shadowEnabled: root.shadowEnabled
                shadowColor: root.shadowColor
                shadowBlur: root.shadowBlur
                shadowVerticalOffset: root.shadowVerticalOffset
                shadowHorizontalOffset: root.shadowHorizontalOffset
            }
        }

        Gradient {
            id: pillGradient
            orientation: Gradient.Vertical
            GradientStop {
                position: 0.0
                color: Qt.rgba(gradientTop.r, gradientTop.g, gradientTop.b, gradientTop.a * root.pillColorOpacity * gradientOpacityTop)
            }
            GradientStop {
                position: pillBg.height > 0 ? Math.min(1.0, root.gradientTopHeightPx / pillBg.height) : 0.0
                color: Qt.rgba(gradientMid.r, gradientMid.g, gradientMid.b, gradientMid.a * root.pillColorOpacity * gradientOpacityMid)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(gradientBottom.r, gradientBottom.g, gradientBottom.b, gradientBottom.a * root.pillColorOpacity * gradientOpacityBottom)
                Behavior on color {
                    ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
                }
            }
        }

        // Background album art image (collapsed only)
        Item {
            id: _bgImgContainer
            anchors.fill: parent
            anchors.margins: 2
            visible: root.bgImageSource !== "" && opacity > 0
            opacity: root.expanded ? 0.0 : 1.0

            Behavior on opacity {
                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
            }

            Image {
                id: _bgImg
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: root.bgImageSource
                sourceSize.width: 300
                asynchronous: true
                smooth: true
                visible: false
            }

            Item {
                id: _bgImgMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                layer.smooth: true

                Rectangle {
                    anchors.fill: parent
                    topLeftRadius: Math.max(0, pillBg.topLeftRadius - 2)
                    topRightRadius: Math.max(0, pillBg.topRightRadius - 2)
                    bottomLeftRadius: Math.max(0, pillBg.bottomLeftRadius - 2)
                    bottomRightRadius: Math.max(0, pillBg.bottomRightRadius - 2)
                    color: "black"
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: _bgImg
                maskEnabled: true
                maskSource: _bgImgMask
                opacity: root.bgImageOpacity
                brightness: root.bgImageBrightness
                contrast: root.bgImageContrast
            }

            Rectangle {
                anchors.fill: parent
                topLeftRadius: Math.max(0, pillBg.topLeftRadius - 2)
                topRightRadius: Math.max(0, pillBg.topRightRadius - 2)
                bottomLeftRadius: Math.max(0, pillBg.bottomLeftRadius - 2)
                bottomRightRadius: Math.max(0, pillBg.bottomRightRadius - 2)
                visible: root.bgImageDarkOverlayOpacity > 0
                color: Qt.rgba(Theme.paletteInk.r, Theme.paletteInk.g, Theme.paletteInk.b, root.bgImageDarkOverlayOpacity)
            }
        }

        // Inner percentage fill (clipped linearly)
        Item {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            visible: !root.expanded && root.animatedPercent > 0
            width: parent.width * (Math.min(Math.max(root.animatedPercent, 0), 100) / 100)
            clip: true

            Rectangle {
                width: pillBg.width
                height: pillBg.height
                topLeftRadius: pillBg.topLeftRadius
                topRightRadius: pillBg.topRightRadius
                bottomLeftRadius: pillBg.bottomLeftRadius
                bottomRightRadius: pillBg.bottomRightRadius

                color: root.effectiveFillColor
            }
        }

        // Overlay border so it displays evenly over both track and fill colors
        Rectangle {
            anchors.fill: parent
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
            color: "transparent"
            border.color: root.effectiveBorderColor
            border.width: 2

            Behavior on border.color {
                ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
            }
        }

        // Text inside the pill
        Text {
            anchors.fill: parent
            text: root.pillText
            color: root.pillPal.pillText
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: root.expanded ? 0.0 : 1.0

            Behavior on opacity {
                NumberAnimation { duration: root.expanded ? 0 : Theme.verticalDuration; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }
        }
    }
}
