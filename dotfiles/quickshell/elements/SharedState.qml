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
    property string lightDaemonCommand: "light_controller"
    property int targetBrightness: -1
    property int inFlightBrightness: -1

    FileView {
        id: peripheralStateFile
        path: "/tmp/light_state.json"
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
            var raw = JSON.parse(text)
            var state = (raw && raw.light) ? raw.light : raw
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
        command: ["sh", "-c", "light_controller on || ~/.nix-profile/bin/light_controller on"]
        onRunningChanged: if (!running) root.refreshLightStatus()
    }

    Process {
        id: lightOffProc
        command: ["sh", "-c", "light_controller off || ~/.nix-profile/bin/light_controller off"]
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
        command: ["sh", "-c", "light_controller set " + targetBrightness + " || ~/.nix-profile/bin/light_controller set " + targetBrightness]
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
        command: ["sh", "-c", "light_controller color " + targetHue + " " + targetSat + " || ~/.nix-profile/bin/light_controller color " + targetHue + " " + targetSat]
        onRunningChanged: if (!running) root.refreshLightStatus()
    }

    function setLightWhite() {
        lightSetWhiteProc.running = true
    }

    Process {
        id: lightSetWhiteProc
        command: ["sh", "-c", "light_controller white || ~/.nix-profile/bin/light_controller white"]
        onRunningChanged: if (!running) root.refreshLightStatus()
    }

    property bool muted: false
    property double notifVolume: 0.2

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

    function playNotificationSound(notification) {
        if (!root.muted && root.notifVolume > 0) {
            if (notification && notification.hints) {
                var suppress = notification.hints["suppress-sound"]
                if (suppress === true || suppress === 1 || suppress === "true") return
            }
            Quickshell.execDetached(["bash", "-c", "REPO=$(dirname $(dirname $(realpath ~/.config/quickshell))); pw-play --volume " + root.notifVolume / 2 + " \"$REPO/misc/ping.ogg\""])
        }
    }

    // ==========================================
    // Notification State
    // ==========================================
    // Every notification, newest (or most recently updated) first.
    ListModel { id: orderedNotifications }
    property alias notificationsModel: orderedNotifications

    // One row per app, ordered by the app's most recent notification.
    ListModel { id: appGroupsModel }
    property alias groupsModel: appGroupsModel

    // Emitted after the notification list or its per-app grouping changed.
    signal notificationListChanged()

    function groupKey(n) {
        return (n && n.appName) ? n.appName : "Unknown"
    }

    function notifKey(n) {
        return (n && n.id !== undefined && n.id !== null) ? "" + n.id : "" + n
    }

    function indexOfNotification(n) {
        for (var i = 0; i < orderedNotifications.count; ++i) {
            var d = orderedNotifications.get(i).notifData
            if (d === n || (d && d.id !== undefined && d.id === n.id)) return i
        }
        return -1
    }

    // Notifications of one app, in global order (newest first).
    function notificationsOf(appName) {
        var list = []
        for (var i = 0; i < orderedNotifications.count; ++i) {
            var d = orderedNotifications.get(i).notifData
            if (d && root.groupKey(d) === appName) list.push(d)
        }
        return list
    }

    // Reconcile a ListModel (rows of a single `role`) with an ordered list of
    // values using remove/move/insert only, so delegates are kept alive and
    // can animate instead of being rebuilt.
    function syncModel(model, role, values) {
        for (var r = model.count - 1; r >= 0; --r) {
            if (values.indexOf(model.get(r)[role]) < 0) model.remove(r)
        }
        for (var t = 0; t < values.length; ++t) {
            if (t < model.count && model.get(t)[role] === values[t]) continue
            var found = -1
            for (var j = t + 1; j < model.count; ++j) {
                if (model.get(j)[role] === values[t]) { found = j; break }
            }
            if (found >= 0) {
                model.move(found, t, 1)
            } else {
                var row = {}
                row[role] = values[t]
                model.insert(t, row)
            }
        }
    }

    function syncGroups() {
        var names = []
        for (var i = 0; i < orderedNotifications.count; ++i) {
            var k = root.groupKey(orderedNotifications.get(i).notifData)
            if (names.indexOf(k) < 0) names.push(k)
        }
        root.syncModel(appGroupsModel, "appName", names)
        root.notificationListChanged()
    }

    // ── Shared Group Expansion State (shared across all monitors) ──
    // Groups are expanded unless listed here.
    property var collapsedGroups: ({})

    function isGroupExpanded(appName) {
        return root.collapsedGroups[appName] !== true
    }

    function setGroupExpanded(appName, expanded) {
        var copy = Object.assign({}, root.collapsedGroups)
        if (expanded) delete copy[appName]
        else copy[appName] = true
        root.collapsedGroups = copy
    }

    function toggleGroupExpanded(appName) {
        root.setGroupExpanded(appName, !root.isGroupExpanded(appName))
    }

    // ── Active Toast Tracking (shared across all monitors) ──────────
    // notification key -> expiry timestamp in ms (0 = stays until dismissed)
    property var activeToasts: ({})
    readonly property bool hasActiveToasts: Object.keys(root.activeToasts).length > 0

    function getToastTimeout(n) {
        if (!n || n.urgency === Notif.NotificationUrgency.Critical) return 0
        return n.expireTimeout > 0 ? n.expireTimeout : 5000
    }

    function isToastActive(n) {
        return !!n && root.activeToasts[root.notifKey(n)] !== undefined
    }

    function markToastActive(n) {
        if (!n) return
        var timeout = root.getToastTimeout(n)
        var copy = Object.assign({}, root.activeToasts)
        copy[root.notifKey(n)] = timeout > 0 ? Date.now() + timeout : 0
        root.activeToasts = copy
        if (timeout > 0) toastTicker.start()
    }

    function dismissActiveToast(n) {
        var k = root.notifKey(n)
        if (root.activeToasts[k] === undefined) return
        var copy = Object.assign({}, root.activeToasts)
        delete copy[k]
        root.activeToasts = copy
    }

    // Expires toasts; only runs while at least one toast has a timeout.
    Timer {
        id: toastTicker
        interval: 100
        repeat: true
        onTriggered: {
            var now = Date.now()
            var copy = {}
            var pending = false
            var changed = false
            for (var k in root.activeToasts) {
                var expireAt = root.activeToasts[k]
                if (expireAt > 0 && now >= expireAt) {
                    changed = true
                } else {
                    copy[k] = expireAt
                    if (expireAt > 0) pending = true
                }
            }
            if (changed) root.activeToasts = copy
            if (!pending) toastTicker.stop()
        }
    }

    // ── Dismissing Animation Tracking (shared across all monitors) ──
    // notification key -> removal timestamp in ms
    property var dismissingNotifs: ({})

    function isNotificationDismissing(n) {
        return !!n && root.dismissingNotifs[root.notifKey(n)] !== undefined
    }

    Timer {
        id: dismissTicker
        interval: 25
        repeat: true
        onTriggered: {
            var now = Date.now()
            var remaining = {}
            var pending = false
            var toRemove = []
            for (var k in root.dismissingNotifs) {
                var removeAt = root.dismissingNotifs[k]
                if (now >= removeAt) {
                    toRemove.push(k)
                } else {
                    remaining[k] = removeAt
                    pending = true
                }
            }
            if (toRemove.length > 0) {
                root.dismissingNotifs = remaining
                for (var i = orderedNotifications.count - 1; i >= 0; --i) {
                    var d = orderedNotifications.get(i).notifData
                    if (d && toRemove.indexOf(root.notifKey(d)) >= 0) {
                        orderedNotifications.remove(i)
                        if (d.dismiss) d.dismiss()
                    }
                }
                root.syncGroups()
            }
            if (!pending) dismissTicker.stop()
        }
    }

    function addNotification(n) {
        if (!n) return
        var k = root.notifKey(n)
        if (root.dismissingNotifs[k] !== undefined) {
            var copy = Object.assign({}, root.dismissingNotifs)
            delete copy[k]
            root.dismissingNotifs = copy
        }
        var i = root.indexOfNotification(n)
        if (i < 0) orderedNotifications.insert(0, { "notifData": n })
        else if (i > 0) orderedNotifications.move(i, 0, 1)
        root.syncGroups()
    }

    function removeNotification(n) {
        if (!n) return
        root.dismissActiveToast(n)
        var k = root.notifKey(n)
        if (root.dismissingNotifs[k] !== undefined) {
            var copy = Object.assign({}, root.dismissingNotifs)
            delete copy[k]
            root.dismissingNotifs = copy
        }
        var i = root.indexOfNotification(n)
        if (i >= 0) orderedNotifications.remove(i)
        root.syncGroups()
    }

    function dismissNotification(n) {
        if (!n) return
        var k = root.notifKey(n)
        if (root.dismissingNotifs[k] !== undefined) return
        root.dismissActiveToast(n)
        var copy = Object.assign({}, root.dismissingNotifs)
        copy[k] = Date.now() + Theme.verticalDuration
        root.dismissingNotifs = copy
        dismissTicker.start()
    }

    function dismissGroup(appName) {
        var list = root.notificationsOf(appName)
        if (list.length === 0) return
        var copy = Object.assign({}, root.dismissingNotifs)
        var exp = Date.now() + Theme.verticalDuration
        for (var k = 0; k < list.length; ++k) {
            var n = list[k]
            root.dismissActiveToast(n)
            copy[root.notifKey(n)] = exp
        }
        root.dismissingNotifs = copy
        dismissTicker.start()
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
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: notification => {
            notification.tracked = true
            root.addNotification(notification)
            root.markToastActive(notification)
            root.playNotificationSound(notification)

            notification.closed.connect(() => {
                root.removeNotification(notification)
            })

            var onUpdated = function() {
                root.addNotification(notification)
                root.markToastActive(notification)
                root.playNotificationSound(notification)
            }
            notification.bodyChanged.connect(onUpdated)
            notification.summaryChanged.connect(onUpdated)
            notification.imageChanged.connect(onUpdated)
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
    property double weatherLastUpdated: 0
    property string weatherTimeAgo: ""
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
        weatherFetchProc.running = false
        weatherFetchProc.running = true
    }

    function parseWeatherJson() {
        var text = weatherJsonFile.text()
        if (!text || text.trim() === "") return
        try {
            var data = JSON.parse(text)
            if (!data || data.error || !data.current) {
                if (data && data.reason) {
                    console.warn("SharedState (Weather): API response contains error:", data.reason)
                }
                return
            }
            var cur = data.current
            if (cur.temperature_2m !== undefined) {
                root.weatherTemperature = Math.round(cur.temperature_2m)
            }
            root.weatherIsDay       = cur.is_day === 1
            var wmo = cur.weather_code !== undefined ? cur.weather_code : 0
            root.weatherIcon = root.wmoIcon(wmo, root.weatherIsDay)
            root.weatherDesc = root.wmoDesc(wmo)

            // Parse hourly
            var h = data.hourly
            if (h && h.time && h.temperature_2m && h.weather_code && h.is_day) {
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
                    if (idx < h.time.length && h.temperature_2m[idx] !== undefined) {
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
            }

            // Parse daily
            var d = data.daily
            if (d && d.time && d.temperature_2m_max && d.temperature_2m_min && d.weather_code) {
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
            }
            root.weatherLoaded = true
        } catch (e) {
            console.warn("SharedState (Weather): JSON parse error", e)
        }
    }

    // Single unified weather timer: updates relative time display every 30s
    // and triggers a background fetch if 10 minutes have elapsed
    Timer {
        id: weatherTimer
        interval: 30000   // 30 seconds
        running: true
        repeat: true
        onTriggered: {
            root.updateWeatherTimeAgo()
            if (Date.now() - root.weatherLastUpdated >= 600000) {
                root.fetchWeather()
            }
        }
    }

    function updateWeatherTimeAgo() {
        if (!root.weatherLastUpdated || root.weatherLastUpdated <= 0) {
            root.weatherTimeAgo = ""
            return
        }
        var diffSec = Math.floor((Date.now() - root.weatherLastUpdated) / 1000)
        if (diffSec < 0) diffSec = 0
        if (diffSec < 45) {
            root.weatherTimeAgo = "just now"
        } else if (diffSec < 3600) {
            root.weatherTimeAgo = Math.floor(diffSec / 60) + "m ago"
        } else if (diffSec < 86400) {
            var h = Math.floor(diffSec / 3600)
            var m = Math.floor((diffSec % 3600) / 60)
            root.weatherTimeAgo = h + "h" + (m > 0 ? " " + m + "m" : "") + " ago"
        } else {
            root.weatherTimeAgo = Math.floor(diffSec / 86400) + "d ago"
        }
    }

    Process {
        id: weatherFetchProc
        command: [
            "sh", "-c",
            "curl -sf --max-time 15 '" + root.weatherApiUrl + "' -o /tmp/weather.json.tmp && " +
            "grep -q '\"current\"' /tmp/weather.json.tmp && " +
            "mv /tmp/weather.json.tmp /tmp/weather.json && " +
            "date +%s > /tmp/weather_updated_at.txt || rm -f /tmp/weather.json.tmp"
        ]
        onRunningChanged: {
            if (!running) {
                root.weatherUpdating = false
                weatherJsonFile.reload()
                weatherUpdatedFile.reload()
                root.readWeatherLastUpdated()
                root.parseWeatherJson()
                root.updateWeatherTimeAgo()
            }
        }
    }

    FileView {
        id: weatherUpdatedFile
        path: "/tmp/weather_updated_at.txt"
        blockLoading: false
        watchChanges: true
        onLoaded: root.readWeatherLastUpdated()
        onFileChanged: root.readWeatherLastUpdated()
        onTextChanged: root.readWeatherLastUpdated()
    }

    function readWeatherLastUpdated() {
        var txt = weatherUpdatedFile.text()
        if (txt && txt.trim() !== "") {
            var val = parseInt(txt.trim(), 10)
            if (!isNaN(val) && val > 0) {
                root.weatherLastUpdated = val * 1000
                root.updateWeatherTimeAgo()
                return
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
        root.readWeatherLastUpdated()
        root.parseWeatherJson()
        root.fetchWeather()
        root.reloadCalendarEventsFromJson()
        root.fetchCalendar()
    }
}