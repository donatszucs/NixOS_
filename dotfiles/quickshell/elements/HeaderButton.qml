// Reusable icon-only button for BaseCard headers and toolbars without background or border
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    // ── Border & Background Options ───────────────────────────────────
    property bool hasBorder: false
    property int borderWidth: hasBorder ? 1 : 0
    property real buttonRadius: hasBorder ? Theme.cardButtonRadius : 0

    property color normalBorderColor: Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.35)
    property color hoverBorderColor: Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.75)
    property color activeBorderColor: (root.hovered && root.enabled) ? hoverBorderColor : normalBorderColor

    property color normalBgColor: "transparent"
    property color hoverBgColor: hasBorder ? Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.08) : "transparent"
    property color activeBgColor: (root.hovered && root.enabled) ? hoverBgColor : normalBgColor

    color: activeBgColor
    radius: buttonRadius
    border.width: borderWidth
    border.color: activeBorderColor

    Behavior on color { ColorAnimation { duration: Theme.horizontalDuration } }
    Behavior on border.color { ColorAnimation { duration: Theme.horizontalDuration } }
    Behavior on scale { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic } }

    scale: !root.enabled ? 1.0 : (root.hasBorder ? (root.pressed ? 0.95 : (root.hovered ? 1.04 : 1.0)) : 1.0)

    // ── Content ───────────────────────────────────────────────────────
    property string icon: ""
    property alias label: root.icon
    property alias text: root.icon

    property color iconColor: Theme.textPrimary
    property alias textColor: root.iconColor

    property int iconSize: Theme.fontSize
    property alias textFont: root.iconSize

    property string fontFamily: Theme.font
    property bool bold: true

    // ── State & Interaction ───────────────────────────────────────────
    property bool enabled: true
    property int cursorShape: Qt.PointingHandCursor
    property bool hovered: mouseArea.containsMouse || rootHover.hovered
    property bool pressed: false

    property real normalOpacity: 0.85
    property real hoverOpacity: 1.0
    property real pressedOpacity: 0.65
    property real disabledOpacity: 0.35

    signal clicked()

    // ── Sizing & Alignment ────────────────────────────────────────────
    property real horizontalPadding: hasBorder ? 8 : 4
    implicitWidth: Math.max(26, Math.round(iconText.implicitWidth + (horizontalPadding * 2)))
    implicitHeight: 26
    Layout.alignment: Qt.AlignVCenter

    // ── Aliases ───────────────────────────────────────────────────────
    property alias iconText: iconText
    property alias labelText: iconText
    property alias mouseArea: mouseArea

    HoverHandler {
        id: rootHover
        enabled: root.enabled
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? root.cursorShape : Qt.ArrowCursor
        enabled: root.enabled
        onPressed: root.pressed = true
        onReleased: root.pressed = false
        onCanceled: root.pressed = false
        onClicked: root.clicked()
    }

    FontMetrics {
        id: fontMetrics
        font: iconText.font
    }

    // Optical vertical centering offset to compensate for font descent metrics in icon glyphs
    property real verticalOffset: fontMetrics.descent ? Math.max(1, Math.round(fontMetrics.descent * 0.25)) : 1

    Text {
        id: iconText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.verticalOffset
        text: root.icon
        color: root.iconColor
        font.family: root.fontFamily
        font.pixelSize: root.iconSize
        font.bold: root.bold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        opacity: !root.enabled ? root.disabledOpacity : (root.pressed ? root.pressedOpacity : (root.hovered ? root.hoverOpacity : root.normalOpacity))
        scale: !root.enabled ? 1.0 : (!root.hasBorder ? (root.pressed ? 0.90 : (root.hovered ? 1.15 : 1.0)) : 1.0)

        Behavior on opacity {
            NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
        }
    }
}
