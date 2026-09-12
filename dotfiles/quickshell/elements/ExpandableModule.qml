// ExpandableModule.qml — Reusable base for bar modules that expand downward.
// Captures the common expand pattern: clip, bottom radii, size behaviors,
// optional auto-collapse on hover exit, and a standardized PillBarButton
// header pill with 10px downward shift when expanded.
//
// Usage:  change your module's root from  ModuleButton { … }
//         to  ExpandableModule { … }  and delete the boilerplate
//         it now provides for free.

import QtQuick
import QtQuick.Layouts

ModuleButton {
    id: root

    // ── Corner radii ─────────────────────────────────────────────
    // Override any of these in the module if the defaults don't fit.
    property int expandedBottomLeftRadius:   Theme.moduleEdgeRadius + 10
    property int expandedBottomRightRadius:  Theme.moduleEdgeRadius + 10
    property int collapsedBottomLeftRadius:  0
    property int collapsedBottomRightRadius: 0

    bottomLeftRadius:  expanded ? expandedBottomLeftRadius  : collapsedBottomLeftRadius
    bottomRightRadius: expanded ? expandedBottomRightRadius : collapsedBottomRightRadius

    // ── Standard expand behaviours ───────────────────────────────
    clip: true
    noHoverColorChange: expanded
    noPressColorChange: expanded

    // ── Hover collapse ───────────────────────────────────────────
    // Set collapseOnHoverExit to false for modules that manage their
    // own collapse logic (e.g. TrayModule with open menus).
    property bool collapseOnHoverExit: true

    // Expose the handler so modules can reference it (e.g. NowPlaying
    // binds expanded to isPlaying && expandHover.hovered).
    property alias expandHover: _expandHover

    HoverHandler {
        id: _expandHover
        onHoveredChanged: {
            if (!_expandHover.hovered && root.expanded && root.collapseOnHoverExit)
                root.expanded = false
        }
    }

    // ── Size animations ──────────────────────────────────────────
    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    // ── Standard header pill ─────────────────────────────────────
    // Set useDefaultPill to false if the module provides its own
    // header (e.g. NowPlayingModule with its unique title bar).
    property bool useDefaultPill: true

    // Pill customisation properties — override in each module
    property string pillText: ""
    property real   pillPercent: expanded ? 100 : 0
    property string pillVariant: "neutral"
    // Text shown in the pill when expanded (e.g. "Weather", "Connections")
    property string expandedPillLabel: ""

    // Expose the pill so modules can anchor to it, reference its color, etc.
    property alias headerPill: _headerPill

    PillBarButton {
        id: _headerPill
        visible: root.useDefaultPill

        // ── Pill content ─────────────────────────────────────────
        pillText:    root.pillText
        percent:     root.pillPercent
        pillVariant: root.pillVariant
        variant:     "neutral"
        colorOverride: true

        // ── Hover / press forwarding ─────────────────────────────
        // When collapsed the whole module reacts; when expanded only the pill does.
        noHoverColorChange: !root.expanded
        noPressColorChange: !root.expanded

        // ── Size — fixed height, width follows module ─────────────
        height: Theme.moduleHeight
        implicitHeight: Theme.moduleHeight
        implicitWidth: root.implicitWidth

        // ── Bottom radii toggle ──────────────────────────────────
        bottomLeftRadius:  root.expanded ? Theme.moduleEdgeRadius : 0
        bottomRightRadius: root.expanded ? Theme.moduleEdgeRadius : 0

        // ── Anchor to module ─────────────────────────────────────
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }

        // ── Click / press handling ───────────────────────────────
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onPressedChanged: {
                if (!root.expanded) {
                    root.pressed = !root.pressed
                } else {
                    _headerPill.pressed = !_headerPill.pressed
                }
            }
            onClicked: (mouse) => {
                root.expanded = !root.expanded
            }
        }

        // ── Expanded title overlay ───────────────────────────────
        // Shows the expandedPillLabel when expanded, hidden when collapsed.
        Text {
            id: _expandedLabel
            anchors.centerIn: parent
            text: root.expandedPillLabel
            color: Theme.textPrimary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.bold: true
            visible: opacity > 0 && root.expandedPillLabel !== ""
            opacity: root.expanded ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
            }
        }
    }
}
