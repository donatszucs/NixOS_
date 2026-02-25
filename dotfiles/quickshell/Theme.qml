pragma Singleton
import QtQuick

QtObject {
    // ── Base colors ──────────────────────────────────────────────────
    readonly property color textPrimary:  "#d5bfe2"
    readonly property color textDark:     "#2a202f"
    readonly property color accentBorder: "#8e6ca0"

    // ── Variant palettes ─────────────────────────────────────────────
    // Each palette exposes: top, bottom, hoverTop, hoverBottom, text
    // Use as:  Theme.palette["dark"].top  or  Theme.dark.top

    readonly property QtObject dark: QtObject {
        readonly property color top:        "#4a3954"
        readonly property color bottom:     '#25172b'
        readonly property color hoverTop:   "#2a1f2e"
        readonly property color hoverBottom:"#422c4d"
        readonly property color pressedTop: "#3a2740"
        readonly property color pressedBottom: "#2a1420"
        readonly property color text:       "#d5bfe2"
        readonly property color border:     "#8e6ca0"
    }

    readonly property QtObject transparentDark: QtObject {
        readonly property color top:        "transparent"
        readonly property color bottom:     "transparent"
        readonly property color hoverTop:   "#2a1f2e"
        readonly property color hoverBottom:"#422c4d"
        readonly property color pressedTop: "#3a2740"
        readonly property color pressedBottom: "#2a1420"
        readonly property color text:       "#d5bfe2"
        readonly property color border:     "#8e6ca0"
    }

    readonly property QtObject light: QtObject {
        readonly property color top:        "#f0e6f5"
        readonly property color bottom:     "#a392ad"
        readonly property color hoverTop:   "#d5bce3"
        readonly property color hoverBottom:"#c3b9c9"
        readonly property color pressedTop: "#e6d6ec"
        readonly property color pressedBottom: "#b99eb8"
        readonly property color text:       "#2a202f"
        readonly property color border:     "#c8b3d4"
    }

    readonly property QtObject danger: QtObject {
        readonly property color top:        "#e17676"
        readonly property color bottom:     '#c16363'
        readonly property color hoverTop:   "#f5a0a0"
        readonly property color hoverBottom:"#c04040"
        readonly property color pressedTop: "#d85f5f"
        readonly property color pressedBottom: "#8f3939"
        readonly property color text:       "#2a202f"
        readonly property color border:     "#652e2e"
    }

    readonly property QtObject transparentRed: QtObject {
        readonly property color top:        "transparent"
        readonly property color bottom:     "transparent"
        readonly property color hoverTop:   '#e88c8c'
        readonly property color hoverBottom:'#cb4747'
        readonly property color pressedTop: "#d85f5f"
        readonly property color pressedBottom: "#8f3939"
        readonly property color text:       '#18131b'
        readonly property color border:     "transparent"
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
    readonly property int    barHeight: 32

    // ── Module sizing ────────────────────────────────────────────────
    readonly property real moduleHeight: 30
    readonly property real moduleOpacity: 0.95
    readonly property int moduleRadius:   8
    readonly property int modulePaddingH: 15
    readonly property int modulePaddingV: 5
    readonly property int moduleMarginH:  2
    readonly property int moduleMarginV:  3
}
