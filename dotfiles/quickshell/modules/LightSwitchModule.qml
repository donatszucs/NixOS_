// Tapo Light Switch — toggles on/off, scroll for brightness, expand for colour wheel
import QtQuick
import QtQuick.Layouts

import "../elements"

ExpandableModule {
    id: root
    // We manage our own content; keep the inherited label empty
    label: ""
    useDefaultPill: false
    // ── Custom radii for this module's unique styling ────────────
    expandedBottomLeftRadius:   130 / 2 + 10
    expandedBottomRightRadius:  Theme.moduleEdgeRadius + 5
    collapsedBottomLeftRadius:  Theme.moduleEdgeRadius
    collapsedBottomRightRadius: 0
    clip: false

    property color buttonColor: labelText.color

    implicitHeight: expanded
        ? contentColumn.implicitHeight
        : Theme.moduleHeight
    implicitWidth: expanded ? 190 : labelText.implicitWidth


    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            right: parent.right
            rightMargin: 0
        }

        spacing: 0

        PillBarButton {
            id: labelText
            colorOverride: true
            noHoverColorChange: !root.expanded
            implicitHeight: Theme.moduleHeight
            clip: false

            colorOpacity: 0.5
            pillColorOpacity: Theme.moduleOpacity

            variant: "neutral"
            
            Layout.alignment: Qt.AlignRight
            Layout.preferredWidth: root.expanded ? 190 : labelText.implicitWidth
            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }

            percent: SharedState.lightAvailable && SharedState.lightActive ? SharedState.lightBrightness : 0
            pillText: !SharedState.lightAvailable
                ? "Offline"
                : SharedState.lightActive
                ? SharedState.lightBrightness + "% 󱩒"
                : "Off 󱩎"
            pillVariant: SharedState.lightVariant
            
            bottomLeftRadius:  0
            bottomRightRadius: root.expanded ? Theme.moduleEdgeRadius + 5 : 0

            InverseRadius {
                anchors.top: labelText.top
                anchors.right: labelText.left
                cornerPosition: "topRight"
                size: Theme.moduleEdgeRadius
                color: labelText.color
            }

            InverseRadius {
                anchors.top: labelText.bottom
                anchors.left: labelText.left
                cornerPosition: "topLeft"
                size: Theme.moduleEdgeRadius
                color: labelText.color
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onWheel: wheel => {
                    if (wheel.angleDelta.y > 0) {
                        SharedState.adjustLightBrightness(5)
                    } else if (wheel.angleDelta.y < 0) {
                        SharedState.adjustLightBrightness(-5)
                    }
                    wheel.accepted = true
                }

                onPressedChanged: {
                    if (!root.expanded) {
                        root.pressed = !root.pressed
                    } else {
                        labelText.pressed = !labelText.pressed
                    }
                }
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        root.expanded = !root.expanded
                    } else {
                        SharedState.toggleLight()
                    }
                }
            }
        }
        // ── Colour wheel with surround ─────────────────────────────────────
        Rectangle {
            id: colorCard
            opacity: root.expanded ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
            }

            Layout.preferredWidth: 170
            Layout.preferredHeight: 130
            Layout.alignment: Qt.AlignTop | Qt.AlignRight
            Layout.margins: 10

            color: Theme.bgBlurColor
            topLeftRadius: Theme.moduleEdgeRadius
            topRightRadius: Theme.moduleEdgeRadius
            bottomRightRadius: Theme.moduleEdgeRadius
            bottomLeftRadius: 130 / 2
            border.width: 2
            border.color: Theme.cardBorder

            // ── Colour wheel ────────────────────────────────────────────
            Item {
                id: colorWheelArea
                width: 130
                height: 130
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom

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
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 5
                width: 30

                radius: width / 2
                variant: "neutral"
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
    Timer {
        id: colorDebounceTimer
        interval: 100
        repeat: false
        onTriggered: SharedState.setLightColor(SharedState.lightHue, SharedState.lightSaturation)
    }

    Component.onCompleted: SharedState.updateLightState()
}
