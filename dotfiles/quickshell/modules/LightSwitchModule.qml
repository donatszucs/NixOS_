// Tapo Light Switch — toggles on/off, scroll for brightness, expand for colour wheel
import QtQuick
import QtQuick.Layouts

import "../elements"

ModuleButton {
    id: root
    noHoverColorChange: expanded
    noPressColorChange: true
    // We manage our own content; keep the inherited label empty
    label: ""
    

    // ── Expand / collapse colour picker ────────────────────────────
    property bool expanded: false

    HoverHandler {
        id: parentHover
        onHoveredChanged: {
            if (!parentHover.hovered && expanded) expanded = false
        }
    }

    bottomLeftRadius:  expanded ? Theme.moduleEdgeRadius + 5 : Theme.moduleEdgeRadius
    bottomRightRadius: expanded ? Theme.moduleEdgeRadius + 5 : Theme.moduleRadius

    implicitHeight: expanded
        ? Theme.moduleHeight + colorWheelArea.height + 12
        : Theme.moduleHeight
    implicitWidth: expanded
        ? Math.max(labelText.implicitWidth, colorWheelArea.implicitWidth + 20)
        : labelText.implicitWidth
    Behavior on implicitHeight { NumberAnimation { duration: Theme.verticalDuration } }
    Behavior on implicitWidth  { NumberAnimation { duration: Theme.horizontalDuration } }

    // Main label — clicking toggles light on/off
    ModuleButton {
        id: labelText
        colorOverride: !root.expanded
        noHoverColorChange: !root.expanded
        noPressColorChange: !root.expanded

        anchors {
            left:  parent.left
            leftMargin: expanded ? Theme.modulePaddingH : 0
            right: parent.right
            top:   parent.top
        }
        height: Theme.moduleHeight

        label: SharedState.lightActive
            ? SharedState.lightBrightness + "% 󱩒"
            : "Off 󱩎"
        variant: SharedState.lightVariant
        
        bottomLeftRadius:  expanded ? Theme.moduleEdgeRadius + 5 : Theme.moduleEdgeRadius
        bottomRightRadius: expanded ? Theme.moduleEdgeRadius + 5 : Theme.moduleRadius

        Behavior on anchors.leftMargin { NumberAnimation { duration: Theme.horizontalDuration } }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        root.expanded = !root.expanded
                                    } else {
                                        SharedState.toggleLight()
                                    }
                                }
        }
    }

    // ── Colour wheel dropdown ───────────────────────────────────────
    Item {
        id: colorWheelArea
        implicitWidth: colorWheel.width + 20
        height: colorWheel.height + 12
        anchors {
            left:     parent.left
            right:    parent.right
            top:      labelText.bottom
            topMargin: 0
        }

        Canvas {
            id: colorWheel
            width: 160
            height: 160
            anchors.centerIn: parent

            // Redraw when stored hue/saturation changes (moves the indicator)
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

                // Draw the hue/saturation wheel:
                //   angle → hue   |   distance from centre → saturation (0 = white)
                var step = 2  // degrees per wedge
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

                // Subtle dark border ring
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, Math.PI * 2)
                ctx.strokeStyle = "#2a202f"
                ctx.lineWidth   = 2
                ctx.stroke()

                // Selection indicator
                var selAngle = SharedState.lightHue * Math.PI / 180
                var selDist  = (SharedState.lightSaturation / 100) * r
                var selX = cx + Math.cos(selAngle) * selDist
                var selY = cy + Math.sin(selAngle) * selDist

                ctx.beginPath()
                ctx.arc(selX, selY, 7, 0, Math.PI * 2)
                ctx.strokeStyle = "#2a202f"
                ctx.lineWidth   = 2
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(selX, selY, 5, 0, Math.PI * 2)
                ctx.fillStyle = "rgba(255,255,255,0.9)"
                ctx.fill()
            }

            // Click or drag to pick colour
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
                        SharedState.setLightColor(Math.round(hue), Math.round(sat))
                    }
                }

                onClicked:         mouse => pickAt(mouse.x, mouse.y)
                onPositionChanged: mouse => { if (pressed) pickAt(mouse.x, mouse.y) }
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

    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onPressedChanged: root.pressed = !root.pressed

        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) {
                SharedState.lightBrightness = Math.min(100, SharedState.lightBrightness + 5)
            } else {
                SharedState.lightBrightness = Math.max(1,   SharedState.lightBrightness - 5)
            }
            debounceTimer.restart()
            wheel.accepted = true
        }
    }

    Component.onCompleted: SharedState.refreshLightStatus()
}
