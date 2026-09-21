pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications as Notif

Item {
    id: root

    // ==========================================
    // Module Mutex (Only one module open at a time)
    // ==========================================
    property var activeModule: null

    function setActiveModule(mod) {
        if (!mod) {
            clearActiveModule(null)
            return
        }
        if (activeModule === mod) return

        var prev = activeModule
        activeModule = mod

        if (prev) {
            if (typeof prev.collapseModule === "function") {
                prev.collapseModule()
            } else if (prev.expanded !== undefined && prev.expanded) {
                prev.expanded = false
            }
            if (typeof prev.closeMenu === "function") {
                prev.closeMenu()
            }
        }
    }

    function clearActiveModule(mod) {
        if (!mod || activeModule === mod) {
            activeModule = null
        }
    }

    function closeActiveModule() {
        if (activeModule) {
            var prev = activeModule
            activeModule = null
            if (typeof prev.collapseModule === "function") {
                prev.collapseModule()
            } else if (prev.expanded !== undefined && prev.expanded) {
                prev.expanded = false
            }
            if (typeof prev.closeMenu === "function") {
                prev.closeMenu()
            }
        }
    }
    
    // ==========================================
    // Light Switch State
    // ==========================================
    property bool lightAvailable: false
    property bool lightActive: true
    property string lightVariant: "light"
    property int lightBrightness: 100
    property int lightHue: 30
    property int lightSaturation: 0
    property string lightDaemonCommand: "peripherial_monitor"
    property int targetBrightness: -1
    property int inFlightBrightness: -1

    FileView {
        id: peripheralStateFile
        path: "/tmp/peripherals.json"
        blockLoading: true
        watchChanges: true
        onLoaded: root.scheduleLightStateUpdate()
        onFileChanged: root.scheduleLightStateUpdate()
        onTextChanged: root.scheduleLightStateUpdate()
    }

    Timer {
        id: lightStateUpdateTimer
        interval: 75
        repeat: false
        onTriggered: root.updateLightState()
    }

    Timer {
        id: lightStateRefreshTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.refreshLightStatus()
    }

    function scheduleLightStateUpdate() {
        lightStateUpdateTimer.restart()
    }

    function refreshLightStatus() {
        peripheralStateFile.reload()
        root.scheduleLightStateUpdate()
    }

    function updateLightState() {
        var text = peripheralStateFile.text()
        if (!text || text.trim() === "") {
            root.scheduleLightStateUpdate()
            return
        }

        try {
            var state = JSON.parse(text).light
            if (!state) {
                root.scheduleLightStateUpdate()
                return
            }
            root.lightAvailable = state.status === "connected"

            var brightnessBusy = brightnessCommandTimer.running
                || lightSetBrightnessProc.running
                || (root.targetBrightness >= 0)
                || (root.inFlightBrightness >= 0)

            if (!brightnessBusy) {
                root.lightActive = state.device_on === true
                root.lightVariant = root.lightActive ? "dark" : "neutral"
                if (state.brightness !== undefined) root.lightBrightness = state.brightness
            }

            if (state.hue !== undefined && !lightSetColorProc.running) root.lightHue = state.hue
            if (state.saturation !== undefined && !lightSetColorProc.running) root.lightSaturation = state.saturation
        } catch (error) {
            root.scheduleLightStateUpdate()
        }
    }

    function toggleLight() {
        if (!root.lightAvailable) return
        if (root.lightActive) {
            root.lightActive = false
            root.lightVariant = "neutral"
            lightOffProc.running = true
        } else {
            root.lightActive = true
            root.lightVariant = "dark"
            lightOnProc.running = true
        }
    }

    Process {
        id: lightOnProc
        command: [root.lightDaemonCommand, "light", "on"]
        onRunningChanged: if (!running) root.refreshLightStatus()
    }

    Process {
        id: lightOffProc
        command: [root.lightDaemonCommand, "light", "off"]
        onRunningChanged: if (!running) root.refreshLightStatus()
    }

    function adjustLightBrightness(delta) {
        if (!root.lightAvailable) return

        if (!root.lightActive) {
            root.lightActive = true
            root.lightVariant = "light"
        }

        var current = (root.targetBrightness >= 0) ? root.targetBrightness : root.lightBrightness
        var next
        if (delta > 0) {
            if (current === 1) {
                next = 5
            } else {
                next = Math.min(100, Math.round((current + delta) / 5) * 5)
            }
        } else {
            next = Math.max(1, Math.min(100, Math.round((current + delta) / 5) * 5))
        }

        root.lightBrightness = next
        root.targetBrightness = next
        brightnessCommandTimer.restart()
    }

    function setLightBrightness(val) {
        if (!root.lightAvailable) return
        var next = Math.max(1, Math.min(100, val))
        root.lightBrightness = next
        root.targetBrightness = next
        brightnessCommandTimer.restart()
    }

    function startBrightnessCommand() {
        if (lightSetBrightnessProc.running || root.targetBrightness < 0) return
        var target = root.targetBrightness
        root.targetBrightness = -1
        root.inFlightBrightness = target
        lightSetBrightnessProc.targetBrightness = target
        lightSetBrightnessProc.running = true
    }

    Timer {
        id: brightnessCommandTimer
        interval: 180
        repeat: false
        onTriggered: root.startBrightnessCommand()
    }

    Process {
        id: lightSetBrightnessProc
        property int targetBrightness: 100
        command: [root.lightDaemonCommand, "light", "set", targetBrightness.toString()]
        onRunningChanged: {
            if (!running) {
                root.inFlightBrightness = -1
                if (root.targetBrightness >= 0 && root.targetBrightness !== targetBrightness) {
                    if (!brightnessCommandTimer.running) {
                        root.startBrightnessCommand()
                    }
                } else {
                    root.refreshLightStatus()
                }
            }
        }
    }

    function setLightColor(hue, sat) {
        lightSetColorProc.targetHue = hue
        lightSetColorProc.targetSat = sat
        lightSetColorProc.running = true
    }

    Process {
        id: lightSetColorProc
        property int targetHue: 30
        property int targetSat: 0
        command: [root.lightDaemonCommand, "light", "color", targetHue.toString(), targetSat.toString()]
        onRunningChanged: if (!running) root.refreshLightStatus()
    }

    function setLightWhite() {
        lightSetWhiteProc.running = true
    }

    Process {
        id: lightSetWhiteProc
        command: [root.lightDaemonCommand, "light", "white"]
        onRunningChanged: if (!running) root.refreshLightStatus()
    }

    property bool muted: false
    property double notifVolume: 0.1

    // ==========================================
    // Night Light (wlsunset) State
    // ==========================================
    property bool nightLightActive: false

    function toggleNightLight() {
        root.nightLightActive = !root.nightLightActive
        if (root.nightLightActive) {
            startNightLightProc.running = true
        } else {
            killNightLightProc.running = true
        }
    }

    Process {
        id: startNightLightProc
        command: ["bash", "-c", "wlsunset -l 47.5 -L 19.0 -t 3500 -T 5000"]
    }

    Process {
        id: killNightLightProc
        command: ["bash", "-c", "pkill wlsunset"]
    }

    function playNotificationSound() {
        if (!root.muted){
            Quickshell.execDetached(["bash", "-c", "REPO=$(dirname $(dirname $(realpath ~/.config/quickshell))); pw-play --volume " + root.notifVolume + " \"$REPO/misc/ping.ogg\""])
        }
    }

    property alias trackedNotifications: server.trackedNotifications

    ListModel {
        id: orderedNotifications
    }

    property alias notificationsModel: orderedNotifications

    function addNotification(notification) {
        if (!notification) return
        for (var i = 0; i < orderedNotifications.count; ++i) {
            var entry = orderedNotifications.get(i)
            if (entry && entry.notifData && (entry.notifData === notification || (entry.notifData.id !== undefined && entry.notifData.id === notification.id))) {
                if (i !== 0) {
                    orderedNotifications.move(i, 0, 1)
                }
                return
            }
        }
        orderedNotifications.insert(0, { "notifData": notification })
    }

    function removeNotification(notification) {
        if (!notification) return
        for (var i = 0; i < orderedNotifications.count; ++i) {
            var entry = orderedNotifications.get(i)
            if (entry && entry.notifData && (entry.notifData === notification || (entry.notifData.id !== undefined && entry.notifData.id === notification.id))) {
                orderedNotifications.remove(i)
                break
            }
        }
    }

    function dismissAllNotifications() {
        if (server.trackedNotifications && server.trackedNotifications.values) {
            var list = server.trackedNotifications.values
            for (var i = list.length - 1; i >= 0; --i) {
                var n = list[i]
                if (n && n.dismiss) n.dismiss()
            }
        }
        orderedNotifications.clear()
    }

    Connections {
        target: server.trackedNotifications
        function onObjectRemovedPost(object, index) {
            root.removeNotification(object)
        }
    }

    Notif.NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        inlineReplySupported: true
        onNotification: notification => {
            notification.tracked = true
            root.addNotification(notification)
            root.playNotificationSound()

            notification.closed.connect(() => {
                root.removeNotification(notification)
            })
            notification.trackedChanged.connect(() => {
                if (!notification.tracked) {
                    root.removeNotification(notification)
                }
            })
        }
    }

    // ==========================================
    // Weather State
    // ==========================================
    property real weatherTemperature: 0
    property string weatherIcon: "󰖐"
    property string weatherDesc: "…"
    property bool weatherIsDay: true
    property bool weatherLoaded: false
    property bool weatherUpdating: false
    property bool weatherFetchFinished: true
    property var weatherHourlyForecast: []
    property var weatherDailyForecast: []

    readonly property string weatherApiUrl:
        "https://api.open-meteo.com/v1/forecast" +
        "?latitude=47.5049&longitude=19.0495" +
        "&current=temperature_2m,weather_code,is_day" +
        "&hourly=temperature_2m,weather_code,is_day" +
        "&daily=weather_code,temperature_2m_max,temperature_2m_min" +
        "&forecast_days=10" +
        "&past_days=2" +
        "&timezone=Europe%2FBudapest"

    function fetchWeather() {
        if (root.weatherUpdating) return
        root.weatherUpdating = true
        root.weatherFetchFinished = false
        weatherUpdateMinTimer.restart()
        weatherFetchProc.running = false
        weatherFetchProc.running = true
    }

    function parseWeatherJson() {
        var text = weatherJsonFile.text()
        if (!text || text.trim() === "") return
        try {
            var data = JSON.parse(text)
            var cur  = data.current
            root.weatherTemperature = Math.round(cur.temperature_2m)
            root.weatherIsDay       = cur.is_day === 1
            var wmo = cur.weather_code
            root.weatherIcon = root.wmoIcon(wmo, root.weatherIsDay)
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
            root.weatherHourlyForecast = hData

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
            root.weatherDailyForecast = dData
            root.weatherLoaded = true
        } catch (e) {
            console.warn("SharedState (Weather): JSON parse error", e)
        }
    }

    Timer {
        id: weatherRefreshTimer
        interval: 600000   // 10 minutes
        running: true
        repeat: true
        onTriggered: root.fetchWeather()
    }

    Timer {
        id: weatherUpdateMinTimer
        interval: 1000
        running: false
        repeat: false
        onTriggered: {
            if (root.weatherFetchFinished) {
                root.weatherUpdating = false
            }
        }
    }

    Process {
        id: weatherFetchProc
        command: ["curl", "-s", root.weatherApiUrl, "-o", "/tmp/weather.json"]
        onRunningChanged: {
            if (!running) {
                root.weatherFetchFinished = true
                if (!weatherUpdateMinTimer.running) {
                    root.weatherUpdating = false
                }
                weatherJsonFile.reload()
                root.parseWeatherJson()
            }
        }
    }

    FileView {
        id: weatherJsonFile
        path: "/tmp/weather.json"
        blockLoading: false
        watchChanges: true
        onLoaded: root.parseWeatherJson()
        onFileChanged: root.parseWeatherJson()
        onTextChanged: root.parseWeatherJson()
    }

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

    // ==========================================
    // Calendar State
    // ==========================================
    property var calendarEventsByDate: ({})
    property var calendarEventColorsByDate: ({})
    property var calendars: []
    property var calendarUpcomingEvents: []
    property bool hasCalendarUrl: false
    property bool calendarUpdating: false

    function fetchCalendar() {
        if (root.calendarUpdating) return
        root.calendarUpdating = true
        fetchCalendarProc.running = false
        fetchCalendarProc.running = true
    }

    function reloadCalendarEventsFromJson() {
        var text = calendarJsonFile.text()
        if (!text || text.trim() === "") return
        try {
            var data = JSON.parse(text)
            root.calendarEventsByDate = data.events_by_date || {}
            root.calendarEventColorsByDate = data.event_colors_by_date || {}
            root.calendars = data.calendars || []
            root.calendarUpcomingEvents = data.upcoming || []
            root.hasCalendarUrl = (data.has_url === true)
        } catch (e) {
            console.log("SharedState: Error parsing calendar json:", e)
        }
    }

    Timer {
        id: calendarRefreshTimer
        interval: 900000 // 15 mins
        running: true
        repeat: true
        onTriggered: root.fetchCalendar()
    }

    Process {
        id: fetchCalendarProc
        command: ["node", Quickshell.env("HOME") + "/.config/quickshell/scripts/fetch_calendar.js"]
        onRunningChanged: {
            if (!running) {
                root.calendarUpdating = false
                calendarJsonFile.reload()
                root.reloadCalendarEventsFromJson()
            }
        }
    }

    FileView {
        id: calendarJsonFile
        path: "/tmp/quickshell_calendar.json"
        blockLoading: false
        watchChanges: true
        onLoaded: root.reloadCalendarEventsFromJson()
        onFileChanged: root.reloadCalendarEventsFromJson()
        onTextChanged: root.reloadCalendarEventsFromJson()
    }

    Component.onCompleted: {
        root.parseWeatherJson()
        root.fetchWeather()
        root.reloadCalendarEventsFromJson()
        root.fetchCalendar()
    }
}