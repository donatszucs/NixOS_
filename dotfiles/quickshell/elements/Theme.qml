pragma Singleton
import QtQuick

QtObject {
    // ── Divider-anchored palette seed ───────────────────────────────
    readonly property color palettePaper:        '#e4cdf4'
    readonly property color paletteInk:          '#252525'
    readonly property color paletteBorderSoft:   "#b7a8c6"
    readonly property color paletteBorderStrong: "#8e6ca0"

    // ── Base colors ──────────────────────────────────────────────────
    readonly property color textPrimary:  palettePaper
    readonly property color textDark:     paletteInk
    readonly property color accentBorder: paletteInk
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
        readonly property color _solidBase:        paletteInk
        readonly property color _solidHover:       '#34303a'
        readonly property color _solidPressed:     '#342d3d'
        
        readonly property color base:        Qt.rgba(_solidBase.r, _solidBase.g, _solidBase.b, Theme.moduleOpacity)
        readonly property color hover:       Qt.rgba(_solidHover.r, _solidHover.g, _solidHover.b, Theme.moduleOpacity)
        readonly property color pressed:     Qt.rgba(_solidPressed.r, _solidPressed.g, _solidPressed.b, Theme.moduleOpacity)
        readonly property color text:        Theme.palettePaper
        readonly property color border:      Theme.paletteBorderStrong
    }

    readonly property QtObject neutral: QtObject {
        readonly property color _solidBase:        '#ffffff'
        readonly property color _solidHover:       '#ffffff'
        readonly property color _solidPressed:     '#ffffff'
        
        readonly property color base:        Qt.rgba(_solidBase.r, _solidBase.g, _solidBase.b, 0.08 * Theme.moduleOpacity)
        readonly property color hover:       Qt.rgba(_solidHover.r, _solidHover.g, _solidHover.b, 0.14 * Theme.moduleOpacity)
        readonly property color pressed:     Qt.rgba(_solidPressed.r, _solidPressed.g, _solidPressed.b, 0.2 * Theme.moduleOpacity)
        readonly property color text:        Theme.palettePaper
        readonly property color border:      Theme.paletteBorderStrong
    }

    readonly property QtObject light: QtObject {
        readonly property color _solidBase:       '#e4c2fd'
        readonly property color _solidHover:      '#f1dffd'
        readonly property color _solidPressed:    '#929192'
        
        readonly property color base:       Qt.rgba(_solidBase.r, _solidBase.g, _solidBase.b, Theme.moduleOpacity)
        readonly property color hover:      Qt.rgba(_solidHover.r, _solidHover.g, _solidHover.b, Theme.moduleOpacity)
        readonly property color pressed:    Qt.rgba(_solidPressed.r, _solidPressed.g, _solidPressed.b, Theme.moduleOpacity)
        readonly property color text:       Theme.paletteInk
        readonly property color border:     Theme.paletteBorderSoft
    }

    readonly property QtObject danger: QtObject {
        readonly property color _solidBase:       '#e17580'
        readonly property color _solidHover:      '#efadb3'
        readonly property color _solidPressed:    "#8f3939"
        
        readonly property color base:       Qt.rgba(_solidBase.r, _solidBase.g, _solidBase.b, Theme.moduleOpacity)
        readonly property color hover:      Qt.rgba(_solidHover.r, _solidHover.g, _solidHover.b, Theme.moduleOpacity)
        readonly property color pressed:    Qt.rgba(_solidPressed.r, _solidPressed.g, _solidPressed.b, Theme.moduleOpacity)
        readonly property color text:       "#2a202f"
        readonly property color border:     "#652e2e"
    }

    // Helper: resolve a variant name string → palette object
    // Usage: Theme.palette("dark").top
        function palette(name) {
        if (name === "light")       return Theme.light
        if (name === "danger")      return Theme.danger
        if (name === "neutral")     return Theme.neutral
        return Theme.dark
    }

    // ── Bar background ───────────────────────────────────────────────
    readonly property color barBgTop:    "transparent"
    readonly property color barBgBottom: "transparent"

    // ── Typography ───────────────────────────────────────────────────
    readonly property string font: "RobotoMono Nerd Font Propo"
    readonly property int    fontSize:  14
    readonly property int    barHeight: 33

    // ── Module sizing ────────────────────────────────────────────────
    readonly property real moduleHeight: 33
    readonly property real listHeight: 50
    readonly property real moduleOpacity: 0.7
    readonly property int moduleRadius:   0
    readonly property int moduleEdgeRadius:   18
    readonly property int modulePaddingH: 15
    readonly property int modulePaddingV: 5
    readonly property int moduleMarginH:  0
    readonly property int moduleMarginV:  0
    readonly property int moduleEdgeMarginV:  0

    // ── Animations ─────────────────────────────────────────────────
    readonly property int verticalDuration: 250
    readonly property int horizontalDuration: verticalDuration
}
