// Reusable "dark purple" pill button — matches waybar's base module style
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string label: ""
    property bool hovered: rootHover.hovered

    // horizontal text alignment: "left" | "center" | "right"
    property string textAlign: "center"

    // margins
    property int leftMargin: 0
    property int rightMargin: 0
    property int topMargin: 0
    property int bottomMargin: 0

    anchors {
        topMargin: Theme.moduleMarginH
    }
    // ── Variant ──────────────────────────────────────────────────────
    // Set to one of: "dark" (default) | "light" | "danger" | "transparent"
    property string variant: "dark"

    // Whether to suppress the hover colour change
    property bool noHoverColorChange: false

    // ── Deprecated shims (kept for compatibility) --------------------
    // Prefer setting `variant` directly in new code.
    property bool lightTheme:       false
    property bool redTheme:         false
    property bool transparentRed:   false

    // ── variant and palette --------------------------------
    readonly property var pal: Theme.palette(variant)

    HoverHandler {
        id: rootHover
    }

    // pressed state (true while mouse button is held)
    property bool pressed: false

    signal clicked()

    implicitHeight: Theme.moduleHeight
    implicitWidth: labelText.implicitWidth + 30
    radius: Theme.moduleRadius
    opacity: Theme.moduleOpacity

    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop {
            position: 0.0
            color: root.pressed ? root.pal.pressedTop : ((root.hovered && !root.noHoverColorChange) ? root.pal.hoverTop : root.pal.top)
        }
        GradientStop {
            position: 1.0
            color: root.pressed ? root.pal.pressedBottom : ((root.hovered && !root.noHoverColorChange) ? root.pal.hoverBottom : root.pal.bottom)
        }
    }

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
        color: root.pal.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.bold: true
        horizontalAlignment: textAlign === "left" ? Text.AlignLeft : (textAlign === "right" ? Text.AlignRight : Text.AlignHCenter)
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onPressed: root.pressed = true
        onReleased: root.pressed = false
        onClicked: root.clicked()
    }

    Behavior on gradient {
        ColorAnimation { duration: 150 }
    }
}
