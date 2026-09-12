// Tapo Light Switch — toggles on/off, scroll for brightness, expand for colour wheel
import QtQuick
import QtQuick.Layouts

import "../elements"

ExpandableModule {
    id: root
    // We manage our own content; keep the inherited label empty
    label: ""

    // ── Custom radii for this module's unique styling ────────────
    expandedBottomLeftRadius:   130 / 2 + 10
    expandedBottomRightRadius:  Theme.moduleEdgeRadius + 5
    collapsedBottomLeftRadius:  Theme.moduleEdgeRadius
    collapsedBottomRightRadius: 0

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

            variant: "neutral"
            
            Layout.alignment: Qt.AlignRight
            Layout.preferredWidth: root.expanded ? 180 : labelText.implicitWidth
            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }

            percent: SharedState.lightActive ? SharedState.lightBrightness : 0
            pillText: SharedState.lightActive
                ? SharedState.lightBrightness + "% 󱩒"
                : "Off 󱩎"
            pillVariant: SharedState.lightVariant
            
            bottomLeftRadius:  root.expanded ? Theme.moduleEdgeRadius + 5 : Theme.moduleEdgeRadius
            bottomRightRadius: root.expanded ? Theme.moduleEdgeRadius + 5 : 0

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onWheel: wheel => {
                    if (wheel.angleDelta.y > 0) {
                        SharedState.lightBrightness = Math.min(100, SharedState.lightBrightness + 5)
                    } else {
                        SharedState.lightBrightness = Math.max(1,   SharedState.lightBrightness - 5)
                    }
                    debounceTimer.restart()
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
        RowLayout {
            id: colorRow
            opacity: root.expanded ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
            }

            Layout.preferredWidth: 160
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 5
            Layout.bottomMargin: 10
            Layout.rightMargin: 20
            spacing: 0

            InverseRadius {
                id: colorRowInverseRadius
                cornerPosition: "topLeft"
                Layout.alignment: Qt.AlignTop
                Layout.rightMargin: -(130 / 2)

                color: Theme.palette("neutral").base
                size: 130 / 2
                outerRadius: Theme.moduleEdgeRadius
            }
            // ── Colour wheel ────────────────────────────────────────────
            Item {
                id: colorWheelArea
                Layout.preferredWidth: 130
                Layout.preferredHeight: 130

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

                    Connections {
                        target: wheelSurround
                        function onColorChanged() { colorWheel.requestPaint() }
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

                        // Outer border
                        var btnC = Theme.palette("neutral").base
                        var strokeRgba = "rgba(" + Math.round(btnC.r * 255) + "," + Math.round(btnC.g * 255) + "," + Math.round(btnC.b * 255) + "," + btnC.a + ")"

                        ctx.beginPath()
                        ctx.arc(cx, cy, cx - 1, 0, Math.PI * 2)
                        ctx.strokeStyle = strokeRgba
                        ctx.lineWidth   = 2
                        ctx.stroke()

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

            Rectangle {
                width: 40
                Layout.fillHeight: true
                color: Theme.palette("neutral").base
                topLeftRadius: 0
                topRightRadius: Theme.moduleEdgeRadius
                bottomLeftRadius: 0
                bottomRightRadius: Theme.moduleEdgeRadius

                InverseRadius {
                    cornerPosition: "topRight"
                    color: Theme.palette("neutral").base
                    size: 130 / 2

                    anchors.right: parent.left
                    anchors.top: parent.top
                }

                InverseRadius {
                    cornerPosition: "bottomRight"
                    color: Theme.palette("neutral").base
                    size: 130 / 2

                    anchors.right: parent.left
                    anchors.bottom: parent.bottom
                }

                // ── Right-side surround panel (non-interactive) ─────────────
                ModuleButton {
                    id: wheelSurround
                    clip: false
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    
                    implicitWidth: 30

                    border.width: 0
                    label: ""
                    color: Theme.bgBlurColor

                    topLeftRadius: 0
                    topRightRadius: Theme.moduleEdgeRadius
                    bottomLeftRadius: 0
                    bottomRightRadius: Theme.moduleEdgeRadius

                    InverseRadius {
                        cornerPosition: "topRight"
                        color: Theme.bgBlurColor
                        size: Theme.moduleEdgeRadius

                        anchors.right: parent.left
                        anchors.top: parent.top
                    }

                    InverseRadius {
                        cornerPosition: "bottomRight"
                        color: Theme.bgBlurColor
                        size: Theme.moduleEdgeRadius

                        anchors.right: parent.left
                        anchors.bottom: parent.bottom
                    }

                    // ── Reset button overlaid on the surround ──────────
                    ModuleButton {
                        id: resetButton
                        anchors.fill: parent
                        topMarginButton: 4
                        bottomMarginButton: 4
                        leftMarginButton: 3
                        rightMarginButton: 4

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
        }
    }
    // ── Brightness scroll wheel ─────────────────────────────────────
    Timer {
        id: debounceTimer
        interval: 1000
        repeat: false
        onTriggered: SharedState.setLightBrightness(SharedState.lightBrightness)
    }

    Timer {
        id: colorDebounceTimer
        interval: 100
        repeat: false
        onTriggered: SharedState.setLightColor(SharedState.lightHue, SharedState.lightSaturation)
    }

    Component.onCompleted: SharedState.refreshLightStatus()
}
