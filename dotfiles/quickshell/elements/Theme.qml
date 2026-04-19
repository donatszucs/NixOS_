pragma Singleton
import QtQuick

QtObject {
    // ── Divider-anchored palette seed ───────────────────────────────
    readonly property color palettePaper:        '#e4cdf4'
    readonly property color paletteInk:          '#252525'
    readonly property color paletteBorderSoft:   Qt.darker(palettePaper, 1.25)
    readonly property color paletteBorderStrong: Qt.darker(palettePaper, 1.6)

    // ── Base colors ──────────────────────────────────────────────────
    readonly property color textPrimary:  palettePaper
    readonly property color textDark:     paletteInk
    readonly property color accentBorder: paletteInk
    // status colors
    readonly property color statusGreen:   "#a0e0a0"
    readonly property color statusRed:     "#e09090"
    readonly property color statusBlue:      "#80b0ff"
    readonly property color statusDisabled:     Qt.rgba(palettePaper.r * 0.7, palettePaper.g * 0.7, palettePaper.b * 0.7, 0.7)

    readonly property color divider:        Qt.rgba(1,1,1,0.08)

    // ── Variant palettes ─────────────────────────────────────────────
    // Each palette exposes: top, bottom, hoverTop, hoverBottom, text
    // Use as:  Theme.palette["dark"].top  or  Theme.dark.top

    readonly property QtObject dark: QtObject {
        readonly property color _solidBase:        paletteInk
        readonly property color _solidHover:       Qt.lighter(Theme.paletteInk, 1.4)
        readonly property color _solidPressed:    Qt.darker(Theme.paletteInk, 1.4)
        
        readonly property color base:        Qt.rgba(_solidBase.r, _solidBase.g, _solidBase.b, Theme.moduleOpacity)
        readonly property color hover:       Qt.rgba(_solidHover.r, _solidHover.g, _solidHover.b, Theme.moduleOpacity)
        readonly property color pressed:     Qt.rgba(_solidPressed.r, _solidPressed.g, _solidPressed.b, Theme.moduleOpacity)
        readonly property color text:        Theme.palettePaper
        readonly property color border:      Theme.paletteBorderStrong
        
        readonly property color pillTrack:       Qt.rgba(1, 1, 1, 0.08)
        readonly property color pillFill:        base
        readonly property color pillText:        text
        readonly property color pillTextOutline: _solidBase
    }

    readonly property QtObject neutral: QtObject {
        readonly property color _solidBase:        '#ffffff'
        readonly property color _solidHover:       '#ffffff'
        readonly property color _solidPressed:     '#ffffff'
        
        readonly property color base:        Qt.rgba(_solidBase.r, _solidBase.g, _solidBase.b, 0.08 * Theme.moduleOpacity)
        readonly property color hover:       Qt.rgba(_solidHover.r, _solidHover.g, _solidHover.b, 0.14 * Theme.moduleOpacity)
        readonly property color pressed:     Qt.rgba(_solidPressed.r, _solidPressed.g, _solidPressed.b, 0.04 * Theme.moduleOpacity)
        readonly property color text:        Theme.palettePaper
        readonly property color border:      Theme.paletteBorderStrong
        
        readonly property color pillTrack:       Qt.rgba(paletteInk.r, paletteInk.g, paletteInk.b, Theme.moduleOpacity)
        readonly property color pillFill:        Qt.rgba(1, 1, 1, 0.2 * Theme.moduleOpacity)
        readonly property color pillText:        text
        readonly property color pillTextOutline: paletteInk
    }

    readonly property QtObject light: QtObject {
        readonly property color _solidBase:       Theme.palettePaper
        readonly property color _solidHover:      Qt.lighter(Theme.palettePaper, 1.4)
        readonly property color _solidPressed:    Qt.darker(Theme.palettePaper, 1.4)
        
        readonly property color base:       Qt.rgba(_solidBase.r, _solidBase.g, _solidBase.b, Theme.moduleOpacity)
        readonly property color hover:      Qt.rgba(_solidHover.r, _solidHover.g, _solidHover.b, Theme.moduleOpacity)
        readonly property color pressed:    Qt.rgba(_solidPressed.r, _solidPressed.g, _solidPressed.b, Theme.moduleOpacity)
        readonly property color text:       Theme.paletteInk
        readonly property color border:     Theme.paletteBorderSoft
        
        readonly property color pillTrack:       Qt.rgba(paletteInk.r, paletteInk.g, paletteInk.b, 0.4)
        readonly property color pillFill:        Qt.rgba(paletteInk.r, paletteInk.g, paletteInk.b, 0.8)
        readonly property color pillText:        Theme.palettePaper
        readonly property color pillTextOutline: "transparent" // no outline needed over dark fill
    }

    readonly property QtObject red: QtObject {
        readonly property color _solidBase:       '#e17580'
        readonly property color _solidHover:      Qt.lighter(_solidBase, 1.4)
        readonly property color _solidPressed:    Qt.darker(_solidBase, 1.4)
        
        readonly property color base:       Qt.rgba(_solidBase.r, _solidBase.g, _solidBase.b, Theme.moduleOpacity)
        readonly property color hover:      Qt.rgba(_solidHover.r, _solidHover.g, _solidHover.b, Theme.moduleOpacity)
        readonly property color pressed:    Qt.rgba(_solidPressed.r, _solidPressed.g, _solidPressed.b, Theme.moduleOpacity)
        readonly property color text:       "#2a202f"
        readonly property color border:     "#652e2e"
        
        readonly property color pillTrack:       Qt.rgba(1, 1, 1, 0.08)
        readonly property color pillFill:        base
        readonly property color pillText:        text
        readonly property color pillTextOutline: "transparent"
    }

    // Helper: resolve a variant name string → palette object
    // Usage: Theme.palette("dark").top
        function palette(name) {
        if (name === "light")       return Theme.light
        if (name === "red")      return Theme.red
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

    // ── Pill Bar Variables ───────────────────────────────────────────

    // ── Animations ─────────────────────────────────────────────────
    readonly property int verticalDuration: 250
    readonly property int horizontalDuration: verticalDuration
}
