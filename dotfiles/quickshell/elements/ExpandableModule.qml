// ExpandableModule.qml — Reusable base for bar modules that expand downward.
// Captures the common expand pattern: clip, bottom radii, size behaviors,
// and optional auto-collapse on hover exit.
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
}
