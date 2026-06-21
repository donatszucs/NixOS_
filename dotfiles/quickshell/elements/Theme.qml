pragma Singleton
import QtQuick

QtObject {
    // ── Divider-anchored palette seed ───────────────────────────────
    readonly property color palettePaper:        '#e5c2f7'
    readonly property color paletteInk:          '#1f1f1f'
    readonly property color paletteBorderSoft:   Qt.darker(palettePaper, 1.2)
    readonly property color paletteBorderStrong: Qt.lighter(paletteInk, 1.2)

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
        
        readonly property color base:        paletteInk
        readonly property color hover:       Qt.lighter(Theme.paletteInk, 1.4)
        readonly property color pressed:     Qt.darker(Theme.paletteInk, 1.4)
        readonly property color text:        Theme.palettePaper

        readonly property color border:      Theme.paletteBorderStrong
        readonly property color borderHover:    Qt.lighter(border, 1.4)
        readonly property color borderPressed:  Qt.darker(border, 1.4)
        
        readonly property color pillTrack:       Qt.lighter(base, 1.6)
        readonly property color pillFill:        Qt.rgba(1, 1, 1, 0.2)
        readonly property color pillBorder:      Qt.rgba(1, 1, 1, 0.2)
        readonly property color pillText:        text
    }

    readonly property QtObject neutral: QtObject {
        readonly property color white:        '#ffffff'
        
        readonly property color base:        Qt.rgba(white.r, white.g, white.b, 0.22)
        readonly property color hover:       Qt.rgba(white.r, white.g, white.b, 0.34)
        readonly property color pressed:     Qt.rgba(white.r, white.g, white.b, 0.14)
        readonly property color text:        Theme.palettePaper
        
        readonly property color border:      Qt.rgba(1, 1, 1, 0.24)
        readonly property color borderHover:    Qt.lighter(border, 2.4)
        readonly property color borderPressed:  Qt.darker(border, 2.4)
        
        readonly property color pillTrack:       Qt.rgba(1, 1, 1, 0.1)
        readonly property color pillFill:        Qt.rgba(1, 1, 1, 0.2)
        readonly property color pillBorder:      Qt.rgba(1, 1, 1, 0.2)
        readonly property color pillText:        text
    }

    readonly property QtObject light: QtObject {
        
        readonly property color base:       Theme.palettePaper
        readonly property color hover:      Qt.lighter(Theme.palettePaper, 1.2)
        readonly property color pressed:    Qt.darker(Theme.palettePaper, 1.4)
        readonly property color text:       Theme.paletteInk

        readonly property color border:     Theme.paletteBorderSoft
        readonly property color borderHover:    Qt.lighter(border, 1.4)
        readonly property color borderPressed:  Qt.darker(border, 1.4)
        
        readonly property color pillTrack:       Qt.rgba(palettePaper.r, palettePaper.g, palettePaper.b, 0.6)
        readonly property color pillFill:        Qt.rgba(palettePaper.r, palettePaper.g, palettePaper.b, 0.9)
        readonly property color pillBorder:      Qt.rgba(palettePaper.r, palettePaper.g, palettePaper.b, 0.8)
        readonly property color pillText:        Theme.paletteInk
    }

    readonly property QtObject red: QtObject {
        
        readonly property color base:       '#e17580'
        readonly property color hover:      Qt.lighter(base, 1.2)
        readonly property color pressed:    Qt.darker(base, 1.2)
        readonly property color text:       "#2a202f"

        readonly property color border:     Qt.darker(statusRed, 1.2)
        readonly property color borderHover:    Qt.lighter(border, 1.4)
        readonly property color borderPressed:  Qt.darker(border, 1.4)
        
        readonly property color pillTrack:       Qt.lighter(base, 1.6)
        readonly property color pillFill:        Qt.rgba(1, 1, 1, 0.2)
        readonly property color pillBorder:      Qt.rgba(1, 1, 1, 0.2)
        readonly property color pillText:        text
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

    // ── Module sizing ────────────────────────────────────────────────
    readonly property real moduleHeight: 36
    readonly property real listHeight: 50
    readonly property real moduleOpacity: 0.85
    readonly property int moduleEdgeRadius: 18
    readonly property int modulePaddingH: 15
    readonly property int modulePaddingV: 5

    // ── Pill Bar Variables ───────────────────────────────────────────

    // ── Animations ─────────────────────────────────────────────────
    readonly property int verticalDuration: 200
    readonly property int horizontalDuration: verticalDuration
}
