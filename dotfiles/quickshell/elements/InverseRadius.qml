import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property bool expandingV: true
    property bool expandingH: true
    property real size: Theme.moduleEdgeRadius
    property real sizeH: size
    property real sizeV: size
    property int animationDuration: Theme.verticalDuration
    // Set false to disable the built-in Behavior so width/height can be bound externally
    property bool animated: true
    implicitWidth: expandingH ? sizeH : 0
    implicitHeight: expandingV ? sizeV : 0

    property color color: Theme.palette("dark").base
    // Where is the solid corner located within this block?
    // "topLeft": solid at (0,0). Empty circle at (width, height)
    // "topRight": solid at (width,0). Empty circle at (0, height)
    // "bottomLeft": solid at (0,height). Empty circle at (width, 0)
    // "bottomRight": solid at (width,height). Empty circle at (0, 0)
    property string cornerPosition: "topLeft"

    // Use a continuous bezier curve instead of a circular/elliptical quarter-arc
    property bool smoothCurve: false
    // Values closer to 0 make the corner "sharper" but perfectly smooth. 0.15 is roughly Apple's continuous corner. 0.447715 matches a circular arc.
    property real smoothTolerance: 0.15

    // Round the outer corner (the sharp vertex)
    property real outerRadius: 0

    // Retained as a no-op for compatibility with Canvas callers
    function requestPaint() {}

    // GPU-accelerated inverse corner fillet (no CPU Canvas repaints)
    Shape {
        id: _shape
        anchors.fill: parent
        visible: width > 0.1 && height > 0.1
        antialiasing: true
        smooth: true
        asynchronous: false
        preferredRendererType: Shape.CurveRenderer

        readonly property bool isRight: root.cornerPosition === "topRight" || root.cornerPosition === "bottomRight"
        readonly property bool isBottom: root.cornerPosition === "bottomLeft" || root.cornerPosition === "bottomRight"
        readonly property real c: Math.max(0, Math.min(1, root.smoothCurve ? root.smoothTolerance : 0.44771525))
        readonly property real ik: 0.44771525

        // Solid outer vertex and arm endpoints
        readonly property real vx: isRight ? width : 0
        readonly property real vy: isBottom ? height : 0
        readonly property real hx: isRight ? 0 : width
        readonly property real ty: isBottom ? 0 : height
        readonly property real dx: isRight ? -1 : 1
        readonly property real dy: isBottom ? -1 : 1

        readonly property real orx: root.outerRadius > 0 ? Math.min(width * 0.5, root.outerRadius) : 0
        readonly property real ory: root.outerRadius > 0 ? Math.min(height * 0.5, root.outerRadius) : 0

        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            strokeWidth: 0
            startX: _shape.vx + _shape.dx * _shape.orx
            startY: _shape.vy

            // Horizontal edge to arm tip
            PathLine {
                x: _shape.hx
                y: _shape.vy
            }

            // Concave inverse-radius curve from horizontal tip to vertical tip
            PathCubic {
                control1X: _shape.vx + (_shape.hx - _shape.vx) * _shape.c
                control1Y: _shape.vy
                control2X: _shape.vx
                control2Y: _shape.vy + (_shape.ty - _shape.vy) * _shape.c
                x: _shape.vx
                y: _shape.ty
            }

            // Vertical edge back toward outer vertex
            PathLine {
                x: _shape.vx
                y: _shape.vy + _shape.dy * _shape.ory
            }

            // Optional rounded outer vertex (collapses to vertex when outerRadius == 0)
            PathCubic {
                control1X: _shape.vx
                control1Y: _shape.vy + _shape.dy * _shape.ory * _shape.ik
                control2X: _shape.vx + _shape.dx * _shape.orx * _shape.ik
                control2Y: _shape.vy
                x: _shape.vx + _shape.dx * _shape.orx
                y: _shape.vy
            }
        }
    }

    Behavior on implicitWidth {
        enabled: root.animated
        NumberAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on implicitHeight {
        enabled: root.animated
        NumberAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }
    }
}
