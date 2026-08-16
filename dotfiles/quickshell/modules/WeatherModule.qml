// Weather module — Budapest V district via open-meteo.com (free, no API key)
// Updates every 10 minutes using XMLHttpRequest
import QtQuick
import QtQuick.Layouts

import "../elements"

ModuleButton {
    id: root

    noHoverColorChange: true
    noPressColorChange: true

    // ── State ─────────────────────────────────────────────────────────
    property real temperature: 0
    property string weatherIcon: "󰖐"       // default: cloudy
    property string weatherDesc: "…"
    property bool   isDay: true
    property bool   loaded: false

    implicitWidth: weatherPill.implicitWidth + 10

    // ── Open-Meteo fetch ──────────────────────────────────────────────
    // Budapest V district: lat 47.5049 lon 19.0495
    readonly property string apiUrl:
        "https://api.open-meteo.com/v1/forecast" +
        "?latitude=47.5049&longitude=19.0495" +
        "&current=temperature_2m,weather_code,is_day" +
        "&timezone=Europe%2FBudapest"

    function fetchWeather() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", root.apiUrl)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    var cur  = data.current
                    root.temperature = Math.round(cur.temperature_2m)
                    root.isDay       = cur.is_day === 1
                    var wmo = cur.weather_code
                    root.weatherIcon = root.wmoIcon(wmo, root.isDay)
                    root.weatherDesc = root.wmoDesc(wmo)
                    root.loaded = true
                } catch (e) {
                    console.warn("WeatherModule: JSON parse error", e)
                }
            } else {
                console.warn("WeatherModule: HTTP", xhr.status)
            }
        }
        xhr.send()
    }

    Component.onCompleted: fetchWeather()

    Timer {
        interval: 600000   // 10 minutes
        running: true
        repeat: true
        onTriggered: root.fetchWeather()
    }

    // ── WMO code → Nerd Font icon (Nerd Font v3, RobotoMono Nerd Font Propo) ──
    function wmoIcon(code, day) {
        if (code === 0)                  return day ? "󰖙" : "󰖔"  // clear sky
        if (code === 1)                  return day ? "󰖙" : "󰖔"  // mainly clear
        if (code === 2)                  return day ? "󰖕" : "󰼱"  // partly cloudy
        if (code === 3)                  return "󰖐"               // overcast
        if (code === 45 || code === 48)  return "󰖑"               // fog / rime fog
        if (code >= 51 && code <= 55)    return "󰖗"               // drizzle
        if (code >= 56 && code <= 57)    return "󰙿"               // freezing drizzle
        if (code >= 61 && code <= 65)    return "󰖗"               // rain
        if (code >= 66 && code <= 67)    return "󰙿"               // freezing rain
        if (code >= 71 && code <= 75)    return "󰼶"               // snow
        if (code === 77)                 return "󰼶"               // snow grains
        if (code >= 80 && code <= 82)    return "󰖗"               // rain showers
        if (code >= 85 && code <= 86)    return "󰼶"               // snow showers
        if (code === 95)                 return "󰖓"               // thunderstorm
        if (code >= 96 && code <= 99)    return "󰖓"               // thunderstorm + hail
        return "󰖐"
    }

    // ── WMO code → short description ─────────────────────────────────
    function wmoDesc(code) {
        if (code === 0)                  return "Clear"
        if (code === 1)                  return "Mostly clear"
        if (code === 2)                  return "Partly cloudy"
        if (code === 3)                  return "Overcast"
        if (code === 45 || code === 48)  return "Foggy"
        if (code >= 51 && code <= 55)    return "Drizzle"
        if (code >= 56 && code <= 57)    return "Freezing drizzle"
        if (code >= 61 && code <= 65)    return "Rain"
        if (code >= 66 && code <= 67)    return "Freezing rain"
        if (code >= 71 && code <= 75)    return "Snow"
        if (code === 77)                 return "Snow grains"
        if (code >= 80 && code <= 82)    return "Showers"
        if (code >= 85 && code <= 86)    return "Snow showers"
        if (code === 95)                 return "Thunderstorm"
        if (code >= 96 && code <= 99)    return "Thunderstorm"
        return "Unknown"
    }

    // ── Distinct Pill Button ──────────────────────────────────────────
    ModuleButton {
        anchors.centerIn: parent
        id: weatherPill
        label: ""
        variant: "neutral"
        border.color: pal.border
        border.width: 2
        radius: implicitHeight / 2
        implicitHeight: Theme.moduleHeight - 10
        implicitWidth: pillContent.implicitWidth

        color: pressedColor

        cursorShape: Qt.ArrowCursor

        RowLayout {
            id: pillContent
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: 8

            // Left padding
            Item { Layout.preferredWidth: 2 }

            // Weather icon (Nerd Font glyph)
            Text {
                text: root.weatherIcon
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 2
                verticalAlignment: Text.AlignVCenter
                opacity: root.loaded ? 1.0 : 0.4
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }

            // Temperature text
            Text {
                text: root.loaded ? root.temperature + "°C" : "—"
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }

            // Separator
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 14
                color: Theme.textPrimary
                opacity: 0.2
                visible: root.loaded
            }

            // Description text
            Text {
                id: descText
                text: root.loaded ? root.weatherDesc : "Loading"
                color: Theme.textPrimary
                opacity: 0.7
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
                font.bold: false
                verticalAlignment: Text.AlignVCenter
            }
            
            // Right padding
            Item { Layout.preferredWidth: 2 }
        }
    }
}
