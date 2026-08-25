// Weather module — Budapest V district via open-meteo.com (free, no API key)
// Updates every 10 minutes using XMLHttpRequest
import QtQuick
import QtQuick.Layouts

import "../elements"

ModuleButton {
    id: root

    noHoverColorChange: expanded ? true : false
    noPressColorChange: expanded ? true : false

    HoverHandler {
        id: parentHover
        onHoveredChanged: {
            if (!parentHover.hovered && expanded) expanded = false
        }
    }
    
    clip: true

    // ── State ─────────────────────────────────────────────────────────
    property real temperature: 0
    property string weatherIcon: "󰖐"       // default: cloudy
    property string weatherDesc: "…"
    property bool   isDay: true
    property bool   loaded: false
    property bool   isUpdating: false
    property bool   fetchFinished: true
    property bool   expanded: false
    property var    hourlyForecast: []
    property var    dailyForecast: []

    bottomLeftRadius: expanded ? Theme.moduleEdgeRadius + 10 : 0
    bottomRightRadius: expanded ? Theme.moduleEdgeRadius + 10 : 0

    implicitWidth: expanded ? baseColumn.implicitWidth : pillContent.implicitWidth + 30
    implicitHeight: expanded ? baseColumn.implicitHeight : Theme.moduleHeight

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }

    // ── Open-Meteo fetch ──────────────────────────────────────────────
    // Budapest V district: lat 47.5049 lon 19.0495
    readonly property string apiUrl:
        "https://api.open-meteo.com/v1/forecast" +
        "?latitude=47.5049&longitude=19.0495" +
        "&current=temperature_2m,weather_code,is_day" +
        "&hourly=temperature_2m,weather_code,is_day" +
        "&daily=weather_code,temperature_2m_max,temperature_2m_min" +
        "&timezone=Europe%2FBudapest"

    function fetchWeather() {
        if (root.isUpdating) return
        root.isUpdating = true
        root.fetchFinished = false
        updateMinTimer.restart()
        var xhr = new XMLHttpRequest()
        xhr.open("GET", root.apiUrl)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            root.fetchFinished = true
            if (!updateMinTimer.running) {
                root.isUpdating = false
            }
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    var cur  = data.current
                    root.temperature = Math.round(cur.temperature_2m)
                    root.isDay       = cur.is_day === 1
                    var wmo = cur.weather_code
                    root.weatherIcon = root.wmoIcon(wmo, root.isDay)
                    root.weatherDesc = root.wmoDesc(wmo)

                    // Parse hourly
                    var h = data.hourly
                    var hData = []
                    var nowTime = new Date().getTime()
                    var startIndex = 0
                    for (var i = 0; i < h.time.length; i++) {
                        var tzTime = new Date(h.time[i]) 
                        if (tzTime.getTime() > nowTime) {
                            startIndex = i
                            break
                        }
                    }
                    for (var j = 0; j < 5; j++) {
                        var idx = startIndex + j
                        if (idx < h.time.length) {
                            var t = new Date(h.time[idx])
                            var hrs = t.getHours().toString().padStart(2, '0')
                            var mins = t.getMinutes().toString().padStart(2, '0')
                            hData.push({
                                time: hrs + ":" + mins,
                                temp: Math.round(h.temperature_2m[idx]),
                                icon: root.wmoIcon(h.weather_code[idx], h.is_day[idx] === 1)
                            })
                        }
                    }
                    root.hourlyForecast = hData

                    // Parse daily
                    var d = data.daily
                    var dData = []
                    var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                    for (var k = 0; k < d.time.length; k++) {
                        var date = new Date(d.time[k])
                        var dayName = (k === 0) ? "Today" : days[date.getDay()]
                        dData.push({
                            day: dayName,
                            icon: root.wmoIcon(d.weather_code[k], true),
                            maxTemp: Math.round(d.temperature_2m_max[k]),
                            minTemp: Math.round(d.temperature_2m_min[k])
                        })
                    }
                    root.dailyForecast = dData
                    
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

    Timer {
        id: updateMinTimer
        interval: 1000
        running: false
        repeat: false
        onTriggered: {
            if (root.fetchFinished) {
                root.isUpdating = false
            }
        }
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

    // ── Layout ──────────────────────────────────────────
    ColumnLayout {
        id: baseColumn
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        PillBarButton {
            id: weatherPill
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: Theme.moduleHeight
            implicitWidth: root.implicitWidth

            noHoverColorChange: !root.expanded
            noPressColorChange: !root.expanded
            colorOverride: !root.expanded
            
            pillVariant: "neutral"
            percent: root.expanded ? 100 : 0

            bottomLeftRadius: root.expanded ? Theme.moduleEdgeRadius : 0
            bottomRightRadius: root.expanded ? Theme.moduleEdgeRadius : 0

            clip: true
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton

                onPressedChanged: {
                    if (!root.expanded) {
                        root.pressed = !root.pressed
                    } else {
                        weatherPill.pressed = !weatherPill.pressed
                    }
                }
                onClicked: {
                    root.expanded = !root.expanded
                }
            }

            Text {
                text: "Weather"
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
                anchors.centerIn: parent
                
                opacity: root.expanded ? 1.0 : 0.0
                visible: opacity > 0
                Behavior on opacity { 
                    NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } 
                }
            }

            RowLayout {
                id: pillContent
                anchors.centerIn: parent
                spacing: 8

                opacity: root.expanded ? 0.0 : 1.0
                visible: opacity > 0
                Behavior on opacity { 
                    NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } 
                }

                Text {
                    text: root.weatherIcon
                    color: Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 2
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    text: root.loaded ? root.temperature + "°C" : "—"
                    color: Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 14
                    color: Theme.textPrimary
                    opacity: 0.2
                    visible: root.loaded
                }

                Text {
                    id: descText
                    text: root.isUpdating ? "Updating..." : (root.loaded ? root.weatherDesc : "Loading")
                    color: Theme.textPrimary
                    opacity: 0.7
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    font.bold: false
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        MouseArea {
            visible: root.expanded
            Layout.preferredWidth: 350
            Layout.preferredHeight: popupCol.implicitHeight
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 10
            acceptedButtons: Qt.NoButton

            ColumnLayout {
                id: popupCol
                width: parent.width
                spacing: 15

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Forecast"
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 2
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    ModuleButton {
                        variant: "light"
                        label: root.isUpdating ? "Updating..." : "󰑐"
                        implicitHeight: 30
                        radius: Theme.moduleEdgeRadius / 2
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.fetchWeather()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: root.hourlyForecast
                        delegate: ModuleButton {
                            variant: "light"
                            radius: Theme.moduleEdgeRadius / 2
                            Layout.fillWidth: true
                            implicitHeight: hourlyCol.implicitHeight + 20
                            
                            ColumnLayout {
                                id: hourlyCol
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: modelData.time
                                    color: Theme.textDark
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 2
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: modelData.icon
                                    color: Theme.textDark
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize + 4
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: modelData.temp + "°"
                                    color: Theme.textDark
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.textPrimary
                    opacity: 0.1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Repeater {
                        model: root.dailyForecast
                        delegate: ModuleButton {
                            variant: "light"
                            radius: Theme.moduleEdgeRadius / 2 + 10
                            Layout.fillWidth: true
                            implicitHeight: dayRow.implicitHeight + 16
                            
                            RowLayout {
                                id: dayRow
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15
                                spacing: 15
                                
                                Text {
                                    text: modelData.day
                                    color: Theme.textDark
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: modelData.day === "Today"
                                    Layout.preferredWidth: 60
                                }
                                Text {
                                    text: modelData.icon
                                    color: Theme.textDark
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize + 4
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: modelData.minTemp + "°"
                                    color: Theme.textDark
                                    opacity: 0.6
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                }
                                Rectangle {
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 4
                                    radius: 2
                                    color: Theme.textDark
                                    opacity: 0.2
                                }
                                Text {
                                    text: modelData.maxTemp + "°"
                                    color: Theme.textDark
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                    horizontalAlignment: Text.AlignRight
                                    Layout.preferredWidth: 30
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
