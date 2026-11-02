// Reusable themed battery badge showing level-aware icon and percentage
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // ── Data properties ───────────────────────────────────────────────
    property real percent: -1
    property bool charging: false
    property bool isFraction: false // if true, converts 0.0-1.0 to 0-100

    readonly property int normalizedPercent: {
        if (percent < 0) return -1;
        if (isFraction || (percent > 0 && percent <= 1.0)) return Math.round(percent * 100);
        return Math.round(percent);
    }

    // ── Visual configuration ──────────────────────────────────────────
    property int badgeHeight: 20
    property real badgePaddingH: 7
    property int spacing: 4

    property bool useStatusColors: true
    property color statusColor: {
        if (charging) return Theme.statusGreen;
        if (normalizedPercent < 0) return Theme.statusDisabled;
        if (normalizedPercent <= 20) return Theme.statusRed;
        return useStatusColors ? Theme.statusGreen : Theme.palettePaper;
    }

    property color textColor: root.statusColor

    // Battery icon helper
    function getBatteryIcon(pct, isCharging) {
        if (isCharging) return "󰂄";
        if (pct >= 90) return "󰁹";
        if (pct >= 80) return "󰂂";
        if (pct >= 70) return "󰂁";
        if (pct >= 60) return "󰂀";
        if (pct >= 50) return "󰁿";
        if (pct >= 40) return "󰁾";
        if (pct >= 30) return "󰁽";
        if (pct >= 20) return "󰁼";
        if (pct >= 10) return "󰁻";
        if (pct >= 0)  return "󰁺";
        return "󰂎";
    }

    property string iconText: getBatteryIcon(normalizedPercent, charging)
    property string percentText: normalizedPercent >= 0 ? (normalizedPercent + "%") : "--"

    property int iconSize: Math.max(10, Math.round(badgeHeight * 0.55))
    property int textSize: Math.max(9, Math.round(badgeHeight * 0.6))

    // ── Interaction ───────────────────────────────────────────────────
    property bool clickable: true
    property int cursorShape: Qt.PointingHandCursor
    property bool hovered: mouseArea.containsMouse || rootHover.hovered
    property bool pressed: mouseArea.pressed

    signal clicked()

    // ── Sizing ────────────────────────────────────────────────────────
    implicitHeight: badgeHeight
    implicitWidth: Math.round(contentRow.implicitWidth + (badgePaddingH * 2))
    height: implicitHeight
    width: implicitWidth

    Rectangle {
        id: badgeBg
        anchors.fill: parent
        radius: Math.round(parent.badgeHeight / 2)

        color: Qt.rgba(root.statusColor.r, root.statusColor.g, root.statusColor.b, (root.clickable && root.hovered) ? 0.26 : 0.14)
        border.width: 1
        border.color: Qt.rgba(root.statusColor.r, root.statusColor.g, root.statusColor.b, (root.clickable && root.hovered) ? 0.60 : 0.38)

        scale: (root.clickable && root.pressed) ? 0.94 : ((root.clickable && root.hovered) ? 1.05 : 1.0)

        Behavior on color { ColorAnimation { duration: Theme.horizontalDuration } }
        Behavior on border.color { ColorAnimation { duration: Theme.horizontalDuration } }
        Behavior on scale { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic } }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: root.spacing

            Text {
                id: iconGlyph
                anchors.verticalCenter: parent.verticalCenter
                text: root.iconText
                color: root.textColor
                font.family: Theme.font
                font.pixelSize: root.iconSize
                font.bold: true
            }

            Text {
                id: pctLabel
                anchors.verticalCenter: parent.verticalCenter
                text: root.percentText
                color: root.textColor
                font.family: Theme.font
                font.pixelSize: root.textSize
                font.bold: true
            }
        }
    }

    HoverHandler {
        id: rootHover
        enabled: root.clickable
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.margins: -2
        hoverEnabled: root.clickable
        enabled: root.clickable
        cursorShape: root.clickable ? root.cursorShape : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
