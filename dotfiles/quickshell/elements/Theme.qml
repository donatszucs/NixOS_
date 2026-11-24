pragma Singleton
import QtQuick

QtObject {
    id: theme
    // ── Divider-anchored palette seed ───────────────────────────────
    readonly property color palettePaper:        '#e5c2f7'
    readonly property color paletteInk:          '#1f1f1f'

    // ── Base colors ──────────────────────────────────────────────────
    readonly property color textPrimary:  palettePaper
    readonly property color textDark:     paletteInk
    readonly property color accentBorder: paletteInk
    // status colors
    readonly property color statusGreen:   "#a0e0a0"
    readonly property color statusRed:     "#e09090"
    readonly property color statusBlue:      "#80b0ff"
    readonly property color statusYellow:    "#e0d080"
    readonly property color statusDisabled:     Qt.rgba(palettePaper.r * 0.7, palettePaper.g * 0.7, palettePaper.b * 0.7, 0.7)

    readonly property color divider:        Qt.rgba(1,1,1,0.12)
    readonly property color cardBorder:     Qt.rgba(palettePaper.r, palettePaper.g, palettePaper.b, 0.22)
    readonly property color bgBlurColor:    Qt.rgba(palettePaper.r * 0.75, palettePaper.g * 0.75, palettePaper.b * 0.75, 0.24)
    readonly property color topBarBlurColor:    Qt.rgba(palettePaper.r * 0.7, palettePaper.g * 0.7, palettePaper.b * 0.7, 0.4)

    // ── Variant palettes ─────────────────────────────────────────────
    // Each variant defines only its core identity (base, text, border).
    // Interactive states (hover/pressed/glass/frame/pill) are derived by the elements themselves.
    // Use as: Theme.palette("light") or Theme.light
    readonly property QtObject dark: QtObject {
        readonly property color base:   theme.paletteInk
        readonly property color text:   theme.palettePaper
        readonly property color border: Qt.rgba(base.r, base.g, base.b, 0.7)
    }

    readonly property QtObject neutral: QtObject {
        readonly property color white:  "#ffffff"
        readonly property color base:   Qt.rgba(1, 1, 1, 0.22)
        readonly property color text:   theme.palettePaper
        readonly property color border: Qt.rgba(1, 1, 1, 0.24)
    }

    readonly property QtObject light: QtObject {
        readonly property color base:   theme.palettePaper
        readonly property color text:   theme.paletteInk
        readonly property color border: Qt.rgba(base.r, base.g, base.b, 0.8)
    }

    readonly property QtObject red: QtObject {
        readonly property color base:   "#e17580"
        readonly property color text:   "#2a202f"
        readonly property color border: Qt.darker(theme.statusRed, 1.2)
    }

    readonly property QtObject blue: QtObject {
        readonly property color base:   theme.statusBlue
        readonly property color text:   theme.paletteInk
        readonly property color border: Qt.rgba(base.r, base.g, base.b, 0.8)
    }

    readonly property QtObject green: QtObject {
        readonly property color base:   theme.statusGreen
        readonly property color text:   theme.paletteInk
        readonly property color border: Qt.rgba(base.r, base.g, base.b, 0.8)
    }

    readonly property QtObject yellow: QtObject {
        readonly property color base:   theme.statusYellow
        readonly property color text:   theme.paletteInk
        readonly property color border: Qt.rgba(base.r, base.g, base.b, 0.8)
    }

    readonly property QtObject transparent: QtObject {
        readonly property color base:   Qt.rgba(0, 0, 0, 0)
        readonly property color text:   theme.palettePaper
        readonly property color border: Qt.rgba(0, 0, 0, 0)
    }

    // Helper: resolve a variant name string → palette object
    function palette(name) {
        if (name === "light")       return theme.light
        if (name === "red")         return theme.red
        if (name === "blue")        return theme.blue
        if (name === "green")       return theme.green
        if (name === "yellow")      return theme.yellow
        if (name === "neutral")     return theme.neutral
        if (name === "transparent") return theme.transparent
        return theme.dark
    }

    // Helper: smoked-glass tint composited over paletteInk (shared by BaseCard & ListButton)
    function glassColor(tint, tintAlpha, inkAlpha) {
        if (tint.a <= 0.001) return Qt.rgba(0, 0, 0, 0)
        var a = tintAlpha + inkAlpha * (1.0 - tintAlpha)
        if (a <= 0.001) return Qt.rgba(0, 0, 0, 0)
        var w = inkAlpha * (1.0 - tintAlpha)
        return Qt.rgba(
            (tint.r * tintAlpha + theme.paletteInk.r * w) / a,
            (tint.g * tintAlpha + theme.paletteInk.g * w) / a,
            (tint.b * tintAlpha + theme.paletteInk.b * w) / a,
            a
        )
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
    readonly property int topCornerRadius: moduleEdgeRadius
    readonly property int expandedTopCornerRadius: 30
    readonly property int modulePaddingH: 15
    readonly property int modulePaddingV: 5

    // ── Pill & Expanded Module Radii (Master Parameters) ─────────────
    readonly property int  pillHeight:                moduleHeight - 10
    readonly property int  pillCollapsedRadius:       pillHeight / 2
    readonly property int  pillCollapsedPaddingH:     10
    readonly property int  closeButtonRadius:         pillCollapsedRadius

    // Master outer radius & layer paddings — inner radii are derived concentrically (outerRadius - padding)
    readonly property int  expandedModuleRadius:      36
    readonly property int  pillExpandedMargin:        5
    readonly property int  pillExpandedPaddingH:      pillExpandedMargin * 2
    readonly property int  pillExpandedRadius:        Math.max(0, expandedModuleRadius - pillExpandedMargin)

    // ── Card & Inner Element Radii (Concentric) ──────────────────────
    readonly property int  cardMargin:                10
    readonly property int  dropdownMargin:            pillExpandedMargin + cardMargin
    readonly property int  cardPadding:               10
    readonly property int  cardItemPadding:           8

    readonly property int  cardRadius:                Math.max(0, pillExpandedRadius - cardMargin)
    readonly property int  cardBorderWidth:           0
    readonly property real cardHeaderHeight:          cardRadius * 2
    readonly property int  cardItemRadius:            Math.max(0, cardRadius - cardPadding)
    readonly property int  cardHeaderInverseRadius:   cardRadius
    readonly property int  cardItemIconInverseRadius: cardItemRadius
    readonly property int  cardButtonRadius:          cardItemRadius
    readonly property int  sliderRadius:              Math.max(4, cardItemRadius - cardItemPadding)
    readonly property int  innerElementRadius:        Math.max(4, cardItemRadius - cardItemPadding)

    // ── Animations ─────────────────────────────────────────────────
    readonly property int verticalDuration: 200
    readonly property int horizontalDuration: verticalDuration
}
