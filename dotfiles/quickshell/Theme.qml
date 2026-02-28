pragma Singleton
import QtQuick

QtObject {
    // ── Base colors ──────────────────────────────────────────────────
    readonly property color textPrimary:  "#d5bfe2"
    readonly property color textDark:     "#2a202f"
    readonly property color accentBorder: '#2a202f'

    // ── Variant palettes ─────────────────────────────────────────────
    // Each palette exposes: top, bottom, hoverTop, hoverBottom, text
    // Use as:  Theme.palette["dark"].top  or  Theme.dark.top

    readonly property QtObject dark: QtObject {
        readonly property color base:        '#32213c'
        readonly property color hover:   '#271330'
        readonly property color pressed: '#120716'
        readonly property color text:       "#d5bfe2"
        readonly property color border:     "#8e6ca0"
    }

    readonly property QtObject transparentDark: QtObject {
        readonly property color base:     "transparent"
        readonly property color hover:   '#271330'
        readonly property color pressed: '#120716'
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

    readonly property QtObject danger: QtObject {
        readonly property color base:       '#cd5555'
        readonly property color hover:      '#b33232'
        readonly property color pressed:    "#8f3939"
        readonly property color text:       "#2a202f"
        readonly property color border:     "#652e2e"
    }

    readonly property QtObject transparentRed: QtObject {
        readonly property color base:        "transparent"
        readonly property color hover:      "#b33232"
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
    readonly property real moduleOpacity: 0.95
    readonly property int moduleRadius:   0
    readonly property int moduleEdgeRadius:   10
    readonly property int modulePaddingH: 15
    readonly property int modulePaddingV: 5
    readonly property int moduleMarginH:  0
    readonly property int moduleMarginV:  0
    readonly property int moduleEdgeMarginV:  0

    // ── Animations ─────────────────────────────────────────────────
    readonly property int verticalDuration: 150
    readonly property int horizontalDuration: 70
}
