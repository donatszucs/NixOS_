// Reusable "dark purple" pill button — matches waybar's base module style
import QtQuick

Rectangle {
    id: root

    property string label: ""
    property bool hovered: rootHover.hovered
    property bool expanded: false

    // horizontal text alignment: "left" | "center" | "right"
    property string textAlign: "center"

    property color textColor: root.pal.text
    property int textFont: Theme.fontSize

    // margins
    property int leftMargin: 0
    property int rightMargin: 0
    property int topMargin: 0
    property int bottomMargin: 0

    // ── Variant ──────────────────────────────────────────────────────
    // Set to one of: "dark" (default) | "light" | "neutral" | "red" | "blue" | "green" | "yellow" | "transparent"
    property string variant: "dark"

    // Whether to suppress the hover/press colour change
    property bool noHoverColorChange: false
    property bool noPressColorChange: false

    // Cursor shape to use when hovering this button. Can be overridden by
    // instances (e.g. `cursorShape: Qt.PointingHandCursor`). Default is arrow.
    property int cursorShape: Qt.ArrowCursor

    // ── Variant palette & derived interactive state colors ───────────
    property real colorOpacity: Theme.moduleOpacity
    property var pal: Theme.palette(variant)

    function _deriveStateColor(c, state) {
        if (c.a <= 0.001) return Qt.rgba(0, 0, 0, 0)
        if (c.a < 0.95) {
            var a = state === "hover" ? Math.min(1.0, c.a * 1.55) : c.a * 0.64
            return Qt.rgba(c.r, c.g, c.b, a)
        }
        var lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
        if (state === "hover")   return Qt.lighter(c, lum < 0.25 ? 1.4 : 1.2)
        if (state === "pressed") return Qt.darker(c, (lum < 0.25 || lum > 0.35) ? 1.4 : 1.2)
        return c
    }

    function _deriveBorderColor(c, state) {
        if (c.a <= 0.001) return Qt.rgba(0, 0, 0, 0)
        if (c.a < 0.5) {
            var a = state === "hover" ? Math.min(1.0, c.a * 1.8) : c.a * 0.55
            return Qt.rgba(c.r, c.g, c.b, a)
        }
        if (state === "hover")   return Qt.lighter(c, 1.4)
        if (state === "pressed") return Qt.darker(c, 1.4)
        return c
    }

    property color baseColor:    Qt.rgba(pal.base.r, pal.base.g, pal.base.b, pal.base.a * colorOpacity)
    property color hoverColor:   { var c = _deriveStateColor(pal.base, "hover");   return Qt.rgba(c.r, c.g, c.b, c.a * colorOpacity) }
    property color pressedColor: { var c = _deriveStateColor(pal.base, "pressed"); return Qt.rgba(c.r, c.g, c.b, c.a * colorOpacity) }

    property color colorAdaptive: (root.pressed && !root.noPressColorChange) ? root.pressedColor : ((root.hovered && !root.noHoverColorChange) ? root.hoverColor : root.baseColor)
    property color borderColorAdaptive: (root.pressed && !root.noPressColorChange) ? _deriveBorderColor(pal.border, "pressed") : ((root.hovered && !root.noHoverColorChange) ? _deriveBorderColor(pal.border, "hover") : pal.border)

    HoverHandler {
        id: rootHover
    }

    // pressed state (true while mouse button is held)
    property bool pressed: false

    signal clicked()

    implicitHeight: Theme.moduleHeight
    implicitWidth: labelText.implicitWidth + 30
    radius: 0

    color: colorAdaptive
    border.width: 0
    border.color: borderColorAdaptive
    clip: true

    // Simpler: let Text fill the parent and use horizontalAlignment/verticalAlignment
    Text {
        id: labelText
        anchors {
            fill: parent
            leftMargin: root.leftMargin
            rightMargin: root.rightMargin
            topMargin: root.topMargin
            bottomMargin: root.bottomMargin
        }
        text: root.label
        color: root.textColor
        font.family: Theme.font
        font.pixelSize: textFont
        font.bold: true
        horizontalAlignment: textAlign === "left" ? Text.AlignLeft : (textAlign === "right" ? Text.AlignRight : Text.AlignHCenter)
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: root.cursorShape
        onPressed: root.pressed = true
        onReleased: root.pressed = false
        onCanceled: root.pressed = false
        onClicked: root.clicked()
    }

    Behavior on color {
        ColorAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    Behavior on border.color {
        ColorAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    Behavior on bottomLeftRadius {
        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    Behavior on bottomRightRadius {
        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    Behavior on topLeftRadius {
        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    Behavior on topRightRadius {
        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

}
