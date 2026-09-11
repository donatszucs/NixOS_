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
    implicitWidth: expanded ? 185 : 80

    property int sideMargin: expanded ? 10 : 0
    Behavior on sideMargin { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic } }

    ColumnLayout {
        id: contentColumn
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            topMargin: 0
            // 2. Bind the layout margins to the animated property
            rightMargin: root.sideMargin
            leftMargin: root.sideMargin
        }

        spacing: 10

        PillBarButton {
            id: labelText
            colorOverride: !root.expanded
            noHoverColorChange: !root.expanded
            implicitHeight: Theme.moduleHeight

            variant: "neutral"
            
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignCenter

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
        // ── Colour wheel + Reset side by side ─────────────────────────────
        RowLayout {
            id: colorRow
            visible: root.expanded
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.topMargin: root.expanded ? 5 : 0
            Layout.bottomMargin: root.expanded ? 10 : 0
            spacing: 0

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

                        ctx.beginPath()
                        ctx.arc(cx, cy, r, 0, Math.PI * 2)
                        ctx.strokeStyle = "#2a202f"
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

            // ── Reset to white button (square) ──────────────────────────
            ModuleButton {
                id: resetButton
                clip: false
                Layout.preferredWidth: 30
                Layout.preferredHeight: 130
                Layout.alignment: Qt.AlignVCenter

                border.width: 0

                label: "R\ne\ns\ne\nt"
                variant: "neutral"

                topLeftRadius: 0
                topRightRadius: Theme.moduleEdgeRadius
                bottomLeftRadius: 0
                bottomRightRadius: Theme.moduleEdgeRadius

                InverseRadius {
                    id: topRightRadius
                    cornerPosition: "topRight"
                    color: resetButton.color
                    size: 130 / 2

                    anchors.right: parent.left
                    anchors.top: parent.top
                }

                InverseRadius {
                    cornerPosition: "bottomRight"
                    color: resetButton.color
                    size: 130 / 2

                    anchors.right: parent.left
                    anchors.bottom: parent.bottom
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        colorDebounceTimer.stop()
                        SharedState.setLightWhite()
                    }
                }
            }

            Behavior on Layout.topMargin { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }
            Behavior on Layout.bottomMargin { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }
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
