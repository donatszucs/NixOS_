// NotificationServer.qml — DBus notification server replacing mako entirely
// Renders a stack of toast notifications in the bottom-right corner of the Bar.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications as Notif

import "../elements"

Item {
    id: root

    // ── Geometry ────────────────────────────────────────────────────────
    readonly property int notifWidth:   360
    readonly property int notifSpacing: 0

    property int notificationNumber: 0
    // Whether any notifications are currently shown (used by Bar.qml for InverseRadius visibility)
    readonly property bool noNotifications: notificationNumber === 0

    implicitWidth:  !noNotifications ? notifWidth : 0
    implicitHeight: notifColumn.implicitHeight
    
    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    // ── DBus notification server (replaces mako) ─────────────────────
    Notif.NotificationServer {
        id: server
        keepOnReload: false
        onNotification: notification => {
            notification.tracked = true
        }
    }

    // ── Notification stack ───────────────────────────────────────────────
    RowLayout {
        id: notifRow
        anchors {
            bottom: parent.bottom
            right: parent.right
        }
        spacing: root.notifSpacing

        InverseRadius {
            Layout.alignment: Qt.AlignBottom
            cornerPosition: "bottomRight"
            color: Theme.palette("dark").base
            expandingV: !noNotifications
        }
        ColumnLayout {
            id: notifColumn
            spacing: root.notifSpacing

            InverseRadius {
                Layout.alignment: Qt.AlignRight
                cornerPosition: "bottomRight"
                color: Theme.palette("dark").base
            }

            Repeater {
                model: server.trackedNotifications
                delegate: NotificationToast {
                    required property var modelData
                    required property int index
                    notif: modelData
                    notifIndex: index
                    toastWidth: root.notifWidth
                }
            }
        }
    }

    // ── Single notification toast component ──────────────────────────────
    component NotificationToast: 
    ModuleButton {
        id: toastRow

        property var notif: null
        property int notifIndex: 0
        // Width to expand to (provided by parent)
        property int toastWidth: root.notifWidth

        // Enter state used to animate from zero size to full size
        property bool entered: false
        property bool expiring: false

        // ── Urgency helpers ──────────────────────────────────────────
        readonly property bool isCritical:
            toastRow.notif && toastRow.notif.urgency === Notif.NotificationUrgency.Critical
        readonly property bool isLow:
            toastRow.notif && toastRow.notif.urgency === Notif.NotificationUrgency.Low

        // Effective timeout: use notification's own value; fall back to 5 s;
        // Critical notifications linger until dismissed.
        readonly property int effectiveTimeout:
            isCritical ? 0
            : (toastRow.notif && toastRow.notif.expireTimeout > 0 ? toastRow.notif.expireTimeout : 5000)

        // ── Sizing & shape ────────────────────────────────────────────
        implicitHeight: toastRow.entered ? (contentLayout.implicitHeight + 24) : 0
        clip: true
        topLeftRadius:     toastRow.notifIndex === 0 ? Theme.moduleEdgeRadius : 0
        topRightRadius:    0
        bottomLeftRadius:  0
        bottomRightRadius: 0

        // ── Colors ────────────────────────────────────────────────────
        variant: isCritical ? "danger" : "dark"
        border.color: "#f38ba8"
        border.width: isCritical ? 2 : 0

        // ── Enter animation: slide in from the right ─────────────────
        Component.onCompleted: {
            root.notificationNumber++
            SharedState.setFlag(toastRow.notif.id, false)
            toastRow.entered = true
        }

        Behavior on topLeftRadius {
            NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
        }
        Behavior on implicitHeight {
            NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
        }
        Behavior on implicitWidth {
            NumberAnimation { duration: toastRow.notifIndex === 0 ? Theme.horizontalDuration : 0; easing.type: Easing.OutCubic }
        }

        // Animate vertical position so existing toasts slide up/down smoothly
        Behavior on y {
            NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
        }

        // Expand horizontally from the right edge (so new toasts appear from bottom-right)
        implicitWidth: (toastRow.entered || toastRow.expiring) ? toastWidth : 0

        Timer {
            id: expireTimer
            interval: toastRow.effectiveTimeout

            running: toastRow.effectiveTimeout > 0
            repeat: false

            onTriggered: {
                if (SharedState.expireFlags[toastRow.notif.id] === false && toastRow.notif)
                    toastRow.requestExpire()
            }
        }

        onClicked: toastRow.requestExpire()

        // ── Content ────────────────────────────────────────────────────
        RowLayout {
            id: contentLayout
            anchors {
                top:    parent.top
                left:   parent.left
                right:  parent.right
                margins: 12
            }
            spacing: 10

            // Image block: shows notification image if available, otherwise app icon; hidden if neither are provided
            Item {

                readonly property bool hasImage: toastRow.notif && toastRow.notif.image !== ""
                readonly property bool hasIcon:  toastRow.notif && toastRow.notif.appIcon !== ""
                visible: hasImage || hasIcon

                implicitHeight: hasImage ? 50 : hasIcon ? 30 : 0
                implicitWidth: implicitHeight

                Image {
                    anchors.fill: parent
                    source: toastRow.notif ? toastRow.notif.image : ("image://icon/" + toastRow.notif.appIcon)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }

            // Text block
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                // app name
                Text {
                    text: toastRow.notif ? toastRow.notif.appName : ""
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    font.bold: true
                    color: toastRow.isCritical ? Theme.statusRed
                            : toastRow.isLow      ? Theme.statusDisabled
                            :              Theme.textPrimary
                    opacity: 0.7
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Summary
                Text {
                    visible: toastRow.notif && toastRow.notif.summary !== ""
                    text: toastRow.notif ? toastRow.notif.summary : ""
                    font.family:    Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold:      true
                    color:          Theme.textPrimary
                    wrapMode:       Text.WordWrap
                    Layout.fillWidth: true
                }

                // Body
                Text {
                    visible: toastRow.notif && toastRow.notif.body !== ""
                    text: toastRow.notif ? toastRow.notif.body : ""
                    font.family:    Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    color:          Theme.textPrimary
                    opacity: 0.7
                    wrapMode:       Text.WordWrap
                    Layout.fillWidth: true
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            id: hoverTracker
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            z: 999 
            
            onEntered: {
                SharedState.setFlag(toastRow.notif.id, true)
            }

            onExited: { 
                SharedState.setFlag(toastRow.notif.id, false)
                toastRow.requestExpire()
            }
        }

        function requestExpire() {
            if (!toastRow.notif || toastRow.expiring) return
            root.notificationNumber--
            toastRow.expiring = true
            toastRow.entered = false
            expireCallTimer.start()
        }

        Timer {
            id: expireCallTimer
            interval: Theme.verticalDuration + 20
            repeat: false
            onTriggered: {
                if (toastRow.notif) toastRow.notif.expire()
            }
        }
    }
}
