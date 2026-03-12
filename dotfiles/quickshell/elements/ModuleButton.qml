// Reusable "dark purple" pill button — matches waybar's base module style
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string label: ""
    property bool hovered: rootHover.hovered

    // horizontal text alignment: "left" | "center" | "right"
    property string textAlign: "center"

    property color textColor: root.pal.text
    property int textFont: Theme.fontSize

    // margins
    property int leftMargin: 0
    property int rightMargin: 0
    property int topMargin: 0
    property int bottomMargin: 0

    property int leftMarginButton: 0
    property int rightMarginButton: 0
    property int topMarginButton: Theme.moduleMarginH
    property int bottomMarginButton: 0

    anchors {
        topMargin: topMarginButton
        bottomMargin: bottomMarginButton
        leftMargin: leftMarginButton
        rightMargin: rightMarginButton
    }
    // ── Variant ──────────────────────────────────────────────────────
    // Set to one of: "dark" (default) | "light" | "danger" | "transparent"
    property string variant: "dark"

    // Whether to suppress the hover colour change
    property bool noHoverColorChange: false

    property bool colorOverride: false
    property color overrideColor: "transparent"

    // Cursor shape to use when hovering this button. Can be overridden by
    // instances (e.g. `Qt.PointingHandCursor: Qt.PointingHandCursor`). Default is arrow.
    property int cursorShape: Qt.ArrowCursor

    // ── variant and palette --------------------------------
    property var pal: Theme.palette(variant)

    HoverHandler {
        id: rootHover
    }

    // pressed state (true while mouse button is held)
    property bool pressed: false

    signal clicked()

    implicitHeight: Theme.moduleHeight
    implicitWidth: Math.ceil(labelText.implicitWidth + 30)
    radius: Theme.moduleRadius
    opacity: Theme.moduleOpacity

    color: root.pressed ? root.pal.pressed : ((root.hovered && !root.noHoverColorChange) ? root.pal.hover : colorOverride ? root.overrideColor : root.pal.base)

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
        onClicked: root.clicked()
    }

    Behavior on gradient {
        ColorAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    Behavior on color {
        ColorAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    Behavior on bottomLeftRadius {
        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    Behavior on bottomRightRadius {
        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }
}
