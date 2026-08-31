// Weather module — Budapest V district via open-meteo.com (free, no API key)
// Updates every 10 minutes using XMLHttpRequest
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "../elements"

ExpandableModule {
    id: root

    // ── State ─────────────────────────────────────────────────────────
    property real temperature: 0
    property string weatherIcon: "󰖐"       // default: cloudy
    property string weatherDesc: "…"
    property bool   isDay: true
    property bool   loaded: false
    property bool   isUpdating: false
    property bool   fetchFinished: true
    property var    hourlyForecast: []
    property var    dailyForecast: []

    implicitWidth: expanded ? baseColumn.implicitWidth : pillContent.implicitWidth + 30
    implicitHeight: expanded ? baseColumn.implicitHeight : Theme.moduleHeight

    // ── Open-Meteo fetch ──────────────────────────────────────────────
    // Budapest V district: lat 47.5049 lon 19.0495
    readonly property string apiUrl:
        "https://api.open-meteo.com/v1/forecast" +
        "?latitude=47.5049&longitude=19.0495" +
        "&current=temperature_2m,weather_code,is_day" +
        "&hourly=temperature_2m,weather_code,is_day" +
        "&daily=weather_code,temperature_2m_max,temperature_2m_min" +
        "&forecast_days=10" +
        "&past_days=2" +
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
                    for (var j = 0; j < 25; j++) {
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
                    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
                    for (var k = 0; k < d.time.length; k++) {
                        var date = new Date(d.time[k])
                        var dayName = (k === 2) ? "Today" : days[date.getDay()]
                        var dateStr = date.getDate() + " " + months[date.getMonth()]
                        dData.push({
                            day: dayName,
                            date: dateStr,
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
            Layout.preferredWidth: 370
            Layout.preferredHeight: popupCol.implicitHeight
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 10
            acceptedButtons: Qt.NoButton

            ColumnLayout {
                id: popupCol
                width: parent.width
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Forecast"
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 8
                        font.bold: true
                        Layout.fillWidth: true
                        Layout.leftMargin: launcherModule.padding
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

                ModuleButton {
                    color: Qt.rgba(1, 1, 1, 0.04)
                    radius: Theme.moduleEdgeRadius / 2 + 10
                    Layout.fillWidth: true
                    implicitHeight: 200

                    Text {
                        id: hourlyTitle
                        text: "Hourly"
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Reset"
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                        opacity: graphFlickable.contentX > 10 ? 0.6 : 0
                        anchors.right: parent.right
                        anchors.rightMargin: 15
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -10
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                resetAnim.start();
                            }
                        }

                        NumberAnimation {
                            id: resetAnim
                            target: graphFlickable
                            property: "contentX"
                            to: 0
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }

                    Flickable {
                        id: graphFlickable
                        anchors.top: hourlyTitle.bottom
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        
                        contentWidth: graphContainer.width
                        contentHeight: height
                        clip: true
                        
                        ScrollBar.horizontal: ScrollBar {
                            contentItem: Rectangle {
                                implicitHeight: 4
                                radius: 2
                                color: Theme.textPrimary
                                opacity: 0.5
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: function(wheel) {
                                if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
                                    graphFlickable.contentX = Math.max(0, graphFlickable.contentX - 50)
                                } else {
                                    graphFlickable.contentX = Math.min(graphFlickable.contentWidth - graphFlickable.width, graphFlickable.contentX + 50)
                                }
                            }
                        }

                        Item {
                            id: graphContainer
                            height: parent.height - 15
                            anchors.top: parent.top
                            width: Math.max(graphFlickable.width, root.hourlyForecast.length * 50)

                        property var model: root.hourlyForecast
                        property real minTemp: 0
                        property real maxTemp: 0

                        onModelChanged: {
                            if (!model || model.length === 0) return;
                            var mn = model[0].temp;
                            var mx = model[0].temp;
                            for (var i = 1; i < model.length; i++) {
                                if (model[i].temp < mn) mn = model[i].temp;
                                if (model[i].temp > mx) mx = model[i].temp;
                            }
                            if (mn === mx) { mn -= 1; mx += 1; }
                            minTemp = mn;
                            maxTemp = mx;
                            if (graphCanvas.available) graphCanvas.requestPaint();
                        }

                        Canvas {
                            id: graphCanvas
                            anchors.fill: parent
                            property bool available: true

                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            property real sidePadding: 20
                            property real topPadding: 45
                            property real bottomPadding: 20
                            property real graphWidth: Math.max(10, width - 2 * sidePadding)
                            property real graphHeight: Math.max(10, height - topPadding - bottomPadding)

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);

                                var m = graphContainer.model;
                                if (!m || m.length === 0) return;

                                var tempRange = graphContainer.maxTemp - graphContainer.minTemp;
                                if (tempRange === 0) tempRange = 1;
                                var stepX = graphWidth / (m.length - 1);

                                function getPt(idx) {
                                    if (idx < 0) idx = 0;
                                    if (idx >= m.length) idx = m.length - 1;
                                    return {
                                        x: sidePadding + idx * stepX,
                                        y: topPadding + graphHeight - ((m[idx].temp - graphContainer.minTemp) / tempRange) * graphHeight
                                    };
                                }

                                function drawSpline() {
                                    var p0 = getPt(0);
                                    ctx.moveTo(p0.x, p0.y);
                                    for (var i = 0; i < m.length - 1; i++) {
                                        var pm1 = getPt(i - 1);
                                        var pi = getPt(i);
                                        var pp1 = getPt(i + 1);
                                        var pp2 = getPt(i + 2);
                                        
                                        // tx controls horizontal stretching (0.25 is similar to the old stepX / 2)
                                        // ty controls vertical swooping (0 is flat plateaus, 0.25 is full swooping splines)
                                        var tx = 0.25;
                                        var ty = 0.15;
                                        ctx.bezierCurveTo(
                                            pi.x + (pp1.x - pm1.x) * tx, pi.y + (pp1.y - pm1.y) * ty,
                                            pp1.x - (pp2.x - pi.x) * tx, pp1.y - (pp2.y - pi.y) * ty,
                                            pp1.x, pp1.y
                                        );
                                    }
                                }

                                // Draw filled area
                                ctx.beginPath();
                                drawSpline();
                                ctx.lineTo(sidePadding + graphWidth, height - bottomPadding + 15);
                                ctx.lineTo(sidePadding, height - bottomPadding + 15);
                                ctx.closePath();

                                var gradient = ctx.createLinearGradient(0, 0, 0, height);
                                gradient.addColorStop(0, Theme.textPrimary.toString());
                                gradient.addColorStop(1, "transparent");
                                ctx.fillStyle = gradient;
                                ctx.globalAlpha = 0.15;
                                ctx.fill();
                                ctx.globalAlpha = 1.0;

                                // Draw line
                                ctx.beginPath();
                                drawSpline();
                                ctx.strokeStyle = Theme.textPrimary.toString();
                                ctx.lineWidth = 2.5;
                                ctx.stroke();

                                // Draw dots
                                ctx.fillStyle = Theme.textPrimary.toString();
                                for (var i = 0; i < m.length; i++) {
                                    var pt = getPt(i);
                                    ctx.beginPath();
                                    ctx.arc(pt.x, pt.y, 3.5, 0, 2 * Math.PI);
                                    ctx.fill();
                                }
                            }
                        }

                        Repeater {
                            model: graphContainer.model
                            delegate: Item {
                                x: graphCanvas.sidePadding + index * (graphCanvas.graphWidth / Math.max(1, graphContainer.model.length - 1))
                                y: 0
                                width: 0
                                height: graphContainer.height

                                Column {
                                    anchors.bottom: dotPoint.top
                                    anchors.bottomMargin: 6
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4
                                    Text {
                                        text: modelData.icon
                                        color: Theme.textPrimary
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize + 2
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Text {
                                        text: modelData.temp + "°"
                                        color: Theme.textPrimary
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 1
                                        font.bold: true
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }

                                Item {
                                    id: dotPoint
                                    y: {
                                        var tempRange = graphContainer.maxTemp - graphContainer.minTemp;
                                        if (tempRange === 0) tempRange = 1;
                                        return graphCanvas.topPadding + graphCanvas.graphHeight - ((modelData.temp - graphContainer.minTemp) / tempRange) * graphCanvas.graphHeight;
                                    }
                                    width: 1
                                    height: 1
                                }

                                Text {
                                    text: modelData.time
                                    color: Theme.textPrimary
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 2
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    opacity: 0.6
                                }
                            }
                        }
                    }
                    }
                }

                Rectangle {
                    color: Qt.rgba(1, 1, 1, 0.04)
                    radius: Theme.moduleEdgeRadius / 2 + 10
                    Layout.fillWidth: true
                    implicitHeight: 200

                    Text {
                        id: dailyTitle
                        text: "10-Day"
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Reset"
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                        opacity: carousel.currentIndex > 2 ? 0.6 : 0
                        anchors.right: parent.right
                        anchors.rightMargin: 15
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -10
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                carousel.currentIndex = 2;
                            }
                        }
                    }

                    ListView {
                        id: carousel
                        anchors.top: dailyTitle.bottom
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 5
                        anchors.bottomMargin: 10
                        model: root.dailyForecast
                        orientation: ListView.Horizontal
                        currentIndex: 2
                        
                        onCurrentIndexChanged: {
                            if (currentIndex < 2) {
                                currentIndex = 2
                            }
                        }
                    
                    // Center the selected item without wrapping
                    preferredHighlightBegin: carousel.width / 2 - 37.5
                    preferredHighlightEnd: carousel.width / 2 + 37.5
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    snapMode: ListView.SnapToItem
                    
                    spacing: 15
                    

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: function(wheel) {
                            if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
                                if (carousel.currentIndex > 2)
                                    carousel.decrementCurrentIndex()
                            } else {
                                carousel.incrementCurrentIndex()
                            }
                        }
                    }
                    
                    delegate: Item {
                        id: delegateRoot
                        width: 75
                        height: 160
                        
                        property real itemCenter: x + width / 2
                        property real viewCenter: carousel.contentX + carousel.width / 2
                        property real centerDist: itemCenter - viewCenter
                        
                        // Create a deadzone so 3 cards stay in full focus (centers are at 0, 90, -90)
                        property real absCenterDist: Math.abs(centerDist)
                        property real outOfFocusDist: Math.max(0, absCenterDist - 95)
                        
                        property real absDist: Math.min(1.0, outOfFocusDist / 100)
                        property real effectiveNormDist: (centerDist < 0 ? -1 : 1) * absDist
                        
                        z: 100 - absDist * 100
                        
                        Item {
                            width: 75
                            height: 110
                            anchors.centerIn: parent
                            
                            // 1.1 base scale for focus zone, plus an extra 0.1 bump for the true center card
                            scale: 1.1 - 0.4 * delegateRoot.absDist + Math.max(0, 1.0 - delegateRoot.absCenterDist / 90) * 0.1
                            
                            transform: Translate {
                                x: -Math.pow(delegateRoot.effectiveNormDist, 3) * 55
                            }
                            
                            ModuleButton {
                                anchors.fill: parent
                                color: Theme.palettePaper
                                radius: Theme.moduleEdgeRadius / 2
                                
                                ColumnLayout {
                                    id: dailyCol
                                    anchors.centerIn: parent
                                    spacing: 2
                                    
                                    Text {
                                        text: modelData.day
                                        color: Theme.textDark
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 2
                                        font.bold: modelData.day === "Today" || carousel.currentIndex === index
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        text: modelData.date
                                        color: Theme.textDark
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 4
                                        opacity: 0.7
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Item { Layout.preferredHeight: 3 }
                                    Text {
                                        text: modelData.icon
                                        color: Theme.textDark
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize + 4
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        text: modelData.maxTemp + "°"
                                        color: Theme.textDark
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize
                                        font.bold: true
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        text: modelData.minTemp + "°"
                                        color: Theme.textDark
                                        opacity: 0.6
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 2
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                                
                                // Darkening shadow for distant cards
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.moduleEdgeRadius / 2
                                    color: "black"
                                    opacity: 0.6 * delegateRoot.absDist
                                }
                            }
                        
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            preventStealing: false
                            onClicked: {
                                if (index >= 2) {
                                    carousel.currentIndex = index
                                }
                            }
                        }
                    }
                    }
                }
            }
        }
    }
}
