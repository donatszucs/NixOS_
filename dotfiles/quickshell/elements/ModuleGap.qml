import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    // ── Module references (preferred API) ────────────────────────
    // Pass the module on each side and the gap auto-derives color
    // and expanded state for its inverse-radius corners.
    property var leftModule:  null   // module on the LEFT side of this gap
    property var rightModule: null   // module on the RIGHT side of this gap

    // ── Manual overrides (backward-compatible) ───────────────────
    // These are auto-derived from the module refs above.  Set them
    // explicitly only when you need to override the automatic value.
    property color leftColor:  leftModule  ? leftModule.color  : "transparent"
    property color rightColor: rightModule ? rightModule.color : "transparent"
    property bool  leftExpanded:  leftModule  ? leftModule.expanded  : false
    property bool  rightExpanded: rightModule ? rightModule.expanded : false

    // Aliases to expose the InverseRadius items for Quickshell's blurRegion mapping
    property alias rightRadius: rightRadius
    property alias leftRadius:  leftRadius

    // Vertical and Horizontal sizes of the radius corners.
    property int sizeHleft:  Theme.moduleEdgeRadius
    property int sizeVleft:  Theme.moduleEdgeRadius
    property int sizeHright: Theme.moduleEdgeRadius
    property int sizeVright: Theme.moduleEdgeRadius

    color: Qt.rgba(Theme.palette("dark").base.r, Theme.palette("dark").base.g, Theme.palette("dark").base.b, Theme.moduleOpacity)

    // base properties
    property bool smoothCurve: false
    property real smoothTolerance: 0.1
    // The physical gap size between modules
    implicitWidth: 0
    implicitHeight: Theme.moduleHeight

    // LEFT-side corner — concave curve for the LEFT module's expansion
    InverseRadius {
        id: leftRadius
        cornerPosition: "topLeft"
        color: root.leftColor
        expandingV: root.leftExpanded
        sizeH: root.sizeHleft
        sizeV: root.sizeVleft

        smoothCurve: root.smoothCurve
        smoothTolerance: root.smoothTolerance

        anchors {
            left: parent.left
            top: parent.bottom
        }
    }

    // RIGHT-side corner — concave curve for the RIGHT module's expansion
    InverseRadius {
        id: rightRadius
        cornerPosition: "topRight"
        color: root.rightColor
        expandingV: root.rightExpanded
        sizeH: root.sizeHright
        sizeV: root.sizeVright

        smoothCurve: root.smoothCurve
        smoothTolerance: root.smoothTolerance

        anchors {
            right: parent.right
            top: parent.bottom
        }
    }
}