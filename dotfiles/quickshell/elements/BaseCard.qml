import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
    id: root

    // ── Sizing & styling tokens ──────────────────────────────────────
    color: Theme.bgBlurColor
    radius: Theme.cardRadius
    border.width: Theme.cardBorderWidth
    border.color: Theme.cardBorder
    clip: true

    Behavior on color { ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

    // ── Shadow configuration ─────────────────────────────────────────
    property bool shadowEnabled: true
    property color shadowColor: Qt.rgba(0, 0, 0, 0.65)
    property real shadowBlur: 0.8
    property real shadowVerticalOffset: 2
    property real shadowHorizontalOffset: 0

    layer.enabled: shadowEnabled
    layer.smooth: true
    layer.effect: MultiEffect {
        shadowEnabled: root.shadowEnabled
        shadowColor: root.shadowColor
        shadowBlur: root.shadowBlur
        shadowVerticalOffset: root.shadowVerticalOffset
        shadowHorizontalOffset: root.shadowHorizontalOffset
    }

    // ── Header bar configuration ─────────────────────────────────────
    property bool hasHeader: headerTitle !== "" || headerIcon !== ""
    property real headerHeight: Theme.cardHeaderHeight
    property color headerColor: Theme.topBarBlurColor
    property string headerTitle: ""
    property string headerIcon: ""

    // ── Header aliases & slots ───────────────────────────────────────
    property alias headerBar: headerBar
    property alias headerRow: headerStandardRow
    property alias headerControls: headerControlRow.data
    property alias headerContent: headerCustomItem.data
    property alias titleText: headerTitleText
    property alias iconText: headerIconText
    property alias headerControlRow: headerControlRow
    readonly property Item headerBottom: headerBar

    // Top Header Bar
    Rectangle {
        id: headerBar
        z: 10
        visible: root.hasHeader
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: visible ? root.headerHeight : 0
        color: root.headerColor
        topLeftRadius: root.radius
        topRightRadius: root.radius
        bottomLeftRadius: 0
        bottomRightRadius: 0
        clip: true

        // Standard Title + Right Controls Row
        RowLayout {
            id: headerStandardRow
            visible: root.headerTitle !== "" || root.headerIcon !== ""
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            spacing: 8

            Text {
                id: headerIconText
                visible: root.headerIcon !== ""
                text: root.headerIcon
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                id: headerTitleText
                visible: root.headerTitle !== ""
                text: root.headerTitle
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                id: headerControlRow
                spacing: 8
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
        }

        // Custom Header Slot (e.g. for custom navigation or layout)
        Item {
            id: headerCustomItem
            anchors.fill: parent
            visible: !headerStandardRow.visible
        }
    }

    // Built-in Inverse Corners attached to headerBar bottom
    InverseRadius {
        id: leftInverseCorner
        z: 10
        visible: root.hasHeader
        anchors.top: headerBar.bottom
        anchors.left: headerBar.left
        color: headerBar.color
    }

    InverseRadius {
        id: rightInverseCorner
        z: 10
        visible: root.hasHeader
        cornerPosition: "topRight"
        anchors.top: headerBar.bottom
        anchors.right: headerBar.right
        color: headerBar.color
    }
}
