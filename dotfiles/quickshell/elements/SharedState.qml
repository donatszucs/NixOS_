pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications as Notif

Item {
    id: root
    
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
                root.lightVariant = root.lightActive ? "light" : "dark"
                if (state.brightness !== undefined) root.lightBrightness = state.brightness
            }

            if (state.hue !== undefined && !lightSetColorProc.running) root.lightHue = state.hue
            if (state.saturation !== undefined && !lightSetColorProc.running) root.lightSaturation = state.saturation
        } catch (error) {
            root.scheduleLightStateUpdate()
        }
    }

    function toggleLight() {
        if (root.lightActive) {
            lightOffProc.running = true
        } else {
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
}