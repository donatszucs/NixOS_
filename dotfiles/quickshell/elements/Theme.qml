pragma Singleton
import QtQuick

QtObject {
    // ── Base colors ──────────────────────────────────────────────────
    readonly property color textPrimary:  "#d5bfe2"
    readonly property color textDark:     "#2a202f"
    readonly property color accentBorder: '#2a202f'
    // status colors
    readonly property color statusGreen:   "#a0e0a0"
    readonly property color statusRed:     "#e09090"
    readonly property color statusBlue:      "#80b0ff"
    readonly property color statusDisabled:     Qt.rgba(0.6,0.4,0.7,0.7)

    readonly property color divider:        Qt.rgba(1,1,1,0.08)

    // ── Variant palettes ─────────────────────────────────────────────
    // Each palette exposes: top, bottom, hoverTop, hoverBottom, text
    // Use as:  Theme.palette["dark"].top  or  Theme.dark.top

    readonly property QtObject dark: QtObject {
        readonly property color base:        '#29252d'
        readonly property color hover:   '#1f1c22'
        readonly property color pressed: '#0e0a10'
        readonly property color text:       "#d5bfe2"
        readonly property color border:     "#8e6ca0"
    }

    readonly property QtObject transparentDark: QtObject {
        readonly property color base:     "transparent"
        readonly property color hover:   '#1f1c22'
        readonly property color pressed: '#0e0a10'
        readonly property color text:       "#d5bfe2"
        readonly property color border:     "#8e6ca0"
    }

    readonly property QtObject light: QtObject {
        readonly property color base:       "#d5bce3"
        readonly property color hover:      '#eee2f5'
        readonly property color pressed:    '#a68bb6'
        readonly property color text:       "#2a202f"
        readonly property color border:     "#c8b3d4"
    }

    readonly property QtObject transparentLight: QtObject {
        readonly property color base:       "transparent"
        readonly property color hover:      '#eee2f5'
        readonly property color pressed:    '#a68bb6'
        readonly property color text:       "#2a202f"
        readonly property color border:     "#c8b3d4"
    }

    readonly property QtObject danger: QtObject {
        readonly property color base:       '#e17580'
        readonly property color hover:      '#a36067'
        readonly property color pressed:    "#8f3939"
        readonly property color text:       "#2a202f"
        readonly property color border:     "#652e2e"
    }

    readonly property QtObject transparentRed: QtObject {
        readonly property color base:        "transparent"
        readonly property color hover:      "#a36067"
        readonly property color pressed:    "#8f3939"
        readonly property color text:       "#2a202f"
        readonly property color border:     "#652e2e"
    }

    // Helper: resolve a variant name string → palette object
    // Usage: Theme.palette("dark").top
    function palette(name) {
        if (name === "light")       return Theme.light
        if (name === "danger")      return Theme.danger
        if (name === "transparentRed") return Theme.transparentRed
        if (name === "transparentDark") return Theme.transparentDark
        return Theme.dark
    }

    // ── Bar background ───────────────────────────────────────────────
    readonly property color barBgTop:    "transparent"
    readonly property color barBgBottom: "transparent"

    // ── Typography ───────────────────────────────────────────────────
    readonly property string font: "JetBrainsMonoNL Nerd Font"
    readonly property int    fontSize:  13
    readonly property int    barHeight: 33

    // ── Module sizing ────────────────────────────────────────────────
    readonly property real moduleHeight: 33
    readonly property real moduleOpacity: 0.9
    readonly property int moduleRadius:   0
    readonly property int moduleEdgeRadius:   18
    readonly property int modulePaddingH: 15
    readonly property int modulePaddingV: 5
    readonly property int moduleMarginH:  0
    readonly property int moduleMarginV:  0
    readonly property int moduleEdgeMarginV:  0

    // ── Animations ─────────────────────────────────────────────────
    readonly property int verticalDuration: 250
    readonly property int horizontalDuration: 250
}
