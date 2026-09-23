// Tapo Light Switch — toggles on/off, scroll for brightness, expand for colour wheel
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import "../elements"

ExpandableModule {
    id: root
    property int cardWidth: 210

    Component {
        id: cardShadowEffect
        MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.65)
            shadowBlur: 0.8
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
        }
    }

    pillPercent: expanded ? 0 : (SharedState.lightAvailable && SharedState.lightActive ? SharedState.lightBrightness : 0)
    pillText: {
        if (expanded) return ""
        if (!SharedState.lightAvailable) return "Offline"
        if (SharedState.lightActive) return SharedState.lightBrightness + "% 󱩒"
        return "Off 󱩎"
    }
    pillVariant: expanded ? "neutral" : SharedState.lightVariant
    expandedPillLabel: "Lights"

    expandedBottomLeftRadius:   Theme.moduleEdgeRadius + 10
    expandedBottomRightRadius:  Theme.moduleEdgeRadius + 10
    collapsedBottomLeftRadius:  Theme.moduleEdgeRadius
    collapsedBottomRightRadius: 0

    leftCornerStyle: "top"
    rightCornerStyle: "side"

    implicitHeight: expanded ? baseColumn.implicitHeight + Theme.moduleHeight + root.titleBarHeight + 5 : Theme.moduleHeight

    // Overlay dropdown setup
    expandedDropdownWidth: cardWidth + 30
    dropdownAlignment: "left"

    onPillRightClicked: {
        SharedState.toggleLight()
    }

    onPillWheel: (wheel) => {
        if (wheel.angleDelta.y > 0) {
            SharedState.adjustLightBrightness(5)
        } else if (wheel.angleDelta.y < 0) {
            SharedState.adjustLightBrightness(-5)
        }
        wheel.accepted = true
    }

    ColumnLayout {
        id: baseColumn
        parent: root.overlay
        spacing: 10
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: root.titleBarHeight
            leftMargin: 5
        }

        scale: expanded ? 1 : 0
        transformOrigin: Item.TopLeft
        Behavior on scale { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

        MouseArea {
            visible: root.contentVisible
            opacity: root.contentOpacity
            implicitWidth: root.cardWidth
            Layout.preferredHeight: popupCol.implicitHeight
            Layout.margins: 10
            acceptedButtons: Qt.NoButton

            ColumnLayout {
                id: popupCol
                width: parent.width
                spacing: 10

        // ── Brightness Card with Slider ──────────────────────────
        Rectangle {
            id: brightnessCard
            color: Theme.bgBlurColor
            radius: Theme.moduleEdgeRadius / 2 + 10
            Layout.fillWidth: true
            implicitHeight: brightTopBar.height + brightContent.implicitHeight + 20
            clip: true
            border.width: 2
            border.color: Theme.cardBorder

            layer.enabled: true
            layer.smooth: true
            layer.effect: cardShadowEffect

            Rectangle {
                id: brightTopBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 35
                color: Theme.topBarBlurColor

                topLeftRadius: parent.radius
                topRightRadius: parent.radius
                bottomLeftRadius: 0
                bottomRightRadius: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: "Brightness"
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 1
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true } // spacer

                    Text {
                        text: SharedState.lightActive ? (SharedState.lightBrightness + "%") : "Off"
                        color: SharedState.lightActive ? Theme.textPrimary : Theme.statusDisabled
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        opacity: 0.85
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ModuleButton {
                        variant: SharedState.lightActive ? "light" : "neutral"
                        label: SharedState.lightActive ? "󱩒" : "󱩎"
                        textFont: 14
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SharedState.toggleLight()
                        implicitHeight: 24
                        implicitWidth: 24
                        radius: Theme.moduleEdgeRadius / 2
                        border.width: 1
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            InverseRadius {
                anchors.top: brightTopBar.bottom
                anchors.left: brightTopBar.left
                color: brightTopBar.color
            }

            InverseRadius {
                cornerPosition: "topRight"
                anchors.top: brightTopBar.bottom
                anchors.right: brightTopBar.right
                color: brightTopBar.color
            }

            RowLayout {
                id: brightContent
                anchors {
                    top: brightTopBar.bottom
                    left: parent.left
                    right: parent.right
                    margins: 10
                }
                spacing: 10

                StyledSlider {
                    id: brightSlider
                    Layout.fillWidth: true
                    sliderHeight: 28
                    radius: Theme.moduleEdgeRadius / 2
                    from: 1
                    to: 100
                    value: SharedState.lightBrightness
                    onMoved: {
                        if (!SharedState.lightActive) {
                            SharedState.lightActive = true
                            SharedState.lightVariant = "dark"
                        }
                        SharedState.setLightBrightness(Math.round(value))
                    }
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        // Colour wheel
        Rectangle {
            id: colorCard
            Layout.fillWidth: true
            implicitHeight: 130

            color: Theme.bgBlurColor
            radius: Theme.moduleEdgeRadius / 2 + 10
            border.width: 2
            border.color: Theme.cardBorder
            clip: true

            layer.enabled: true
            layer.smooth: true
            layer.effect: cardShadowEffect

            // ── Colour wheel ────────────────────────────────────────────
            Item {
                id: colorWheelArea
                width: 130
                height: 130
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter

                Canvas {
                    id: colorWheel
                    width: 130
                    height: 130
                    anchors.centerIn: parent

                    Connections {
                        target: SharedState
                        function onLightHueChanged()        { colorWheel.requestPaint() }
                        function onLightSaturationChanged() { colorWheel.requestPaint() }
                    }

                    Component.onCompleted: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        var cx = width  / 2
                        var cy = height / 2
                        var r  = Math.min(cx, cy) - 2

                        var step = 2
                        for (var a = 0; a < 360; a += step) {
                            var startRad = a * Math.PI / 180
                            var endRad   = (a + step + 0.5) * Math.PI / 180

                            ctx.beginPath()
                            ctx.moveTo(cx, cy)
                            ctx.arc(cx, cy, r, startRad, endRad)
                            ctx.closePath()

                            var grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                            grad.addColorStop(0, "white")
                            grad.addColorStop(1, "hsl(" + a + ", 100%, 50%)")
                            ctx.fillStyle = grad
                            ctx.fill()
                        }

                        var selAngle = SharedState.lightHue * Math.PI / 180
                        var selDist  = (SharedState.lightSaturation / 100) * r
                        var selX = cx + Math.cos(selAngle) * selDist
                        var selY = cy + Math.sin(selAngle) * selDist

                        ctx.beginPath()
                        ctx.arc(selX, selY, 5, 0, Math.PI * 2)
                        ctx.strokeStyle = "#2a202f"
                        ctx.lineWidth   = 2
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.arc(selX, selY, 3.5, 0, Math.PI * 2)
                        ctx.fillStyle = "rgba(255,255,255,0.9)"
                        ctx.fill()
                    }

                    MouseArea {
                        anchors.fill: parent
                        propagateComposedEvents: false

                        function pickAt(mx, my) {
                            var cx   = colorWheel.width  / 2
                            var cy   = colorWheel.height / 2
                            var r    = Math.min(cx, cy) - 2
                            var dx   = mx - cx
                            var dy   = my - cy
                            var dist = Math.sqrt(dx * dx + dy * dy)
                            if (dist <= r) {
                                var hue = (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360
                                var sat = Math.min(dist / r, 1.0) * 100
                                SharedState.lightHue = Math.round(hue)
                                SharedState.lightSaturation = Math.round(sat)
                                colorDebounceTimer.restart()
                            }
                        }

                        onClicked:         mouse => pickAt(mouse.x, mouse.y)
                        onPositionChanged: mouse => { if (pressed) pickAt(mouse.x, mouse.y) }
                    }
                }
            }

            // ── Reset button overlaid on the right ──────────
            ModuleButton {
                id: resetButton
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                width: 36

                radius: 10
                variant: "light"
                border.width: 2
                cursorShape: Qt.PointingHandCursor
                label: "R\nE\nS\nE\nT"

                onClicked: {
                    colorDebounceTimer.stop()
                    SharedState.setLightWhite()
                }
            }
        }
            }
        }
    }
    Timer {
        id: colorDebounceTimer
        interval: 100
        repeat: false
        onTriggered: SharedState.setLightColor(SharedState.lightHue, SharedState.lightSaturation)
    }

    Component.onCompleted: SharedState.updateLightState()
}
