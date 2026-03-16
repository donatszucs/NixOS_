// NotificationServer.qml — DBus notification server
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
    property bool inlineReplyInputFocused: false
    // Whether any notifications are currently shown (used by Bar.qml for InverseRadius visibility)
    property bool noNotifications: (SharedState.notificationCounter === 0 || innerLayout.implicitHeight === 0)

    implicitWidth:  notifGrid.implicitWidth
    implicitHeight: notifGrid.implicitHeight

    // ── DBus notification server ─────────────────────
    Notif.NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        inlineReplySupported: true
        onNotification: notification => {
            notification.tracked = true

            Quickshell.execDetached(["pw-play", "--volume", "2.0", "/home/doni/nixos-config/misc/ping.ogg"])
        }
    }

    // ── Notification stack ───────────────────────────────────────────────
    GridLayout {
        id: notifGrid
        columns: 2
        columnSpacing: root.notifSpacing
        rowSpacing: root.notifSpacing

        // [Row 0, Col 1] Top Radius
        InverseRadius {
            id: topRadius
            Layout.row: 0
            Layout.column: 1
            Layout.alignment: Qt.AlignRight | Qt.AlignBottom
            
            cornerPosition: "bottomRight"
            size: innerLayout.implicitWidth === 0 ? Theme.moduleEdgeRadius : (innerLayout.implicitWidth / 8)
            color: Theme.palette("dark").base
        }

        // [Row 1, Col 0] Side/Bottom Radius
        InverseRadius {
            Layout.row: 1
            Layout.column: 0
            Layout.alignment: Qt.AlignRight | Qt.AlignBottom
            
            cornerPosition: "bottomRight"
            // Swapped notifColumn.implicitHeight to innerLayout.implicitHeight since notifColumn is gone
            size: Math.floor(innerLayout.implicitHeight / 8)
            color: Theme.palette("dark").base
            expandingH: (innerLayout.implicitWidth !== 0 || hoverHandler.hovered)
            expandingV: (innerLayout.implicitWidth !== 0 || hoverHandler.hovered)
            animationDuration: Theme.verticalDuration / 2
        }

        // [Row 1, Col 1] Main Notification Container
        Rectangle {
            id: containerRect
            Layout.row: 1
            Layout.column: 1
            Layout.alignment: Qt.AlignBottom | Qt.AlignRight
            
            color: Theme.palette("dark").base
            clip: true
            opacity: Theme.moduleOpacity
            topLeftRadius: Theme.moduleEdgeRadius + 5
            
            implicitWidth: (innerLayout.implicitWidth === 0 && !hoverHandler.hovered) ? topRadius.size : (innerLayout.implicitWidth + 20)
            implicitHeight: (innerLayout.implicitHeight === 0 && !hoverHandler.hovered) ? 0 : (innerLayout.implicitHeight + 25)

            Behavior on implicitHeight {
                NumberAnimation { duration: Theme.verticalDuration / 2; easing.type: Easing.OutCubic }
            }
            Behavior on implicitWidth {
                NumberAnimation { duration: Theme.horizontalDuration / 2; easing.type: Easing.OutCubic }
            }

            // Your exact inner layout, untouched
            ColumnLayout {
                id: innerLayout
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                layoutDirection: Qt.RightToLeft
                spacing: 5
                clip: true

                ModuleButton {
                    visible: implicitHeight > 0 || hoverHandler.hovered
                    id: headerButton
                    Layout.alignment: Qt.AlignHCenter
                    textFont: 20
                    color: "transparent"
                    label: "󰎟 Notification Center"
                    Layout.preferredHeight: hoverHandler.hovered ? 30 : 0
                    Layout.preferredWidth: hoverHandler.hovered ? notifWidth : 0

                    Behavior on Layout.preferredHeight {
                        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
                    }

                    Behavior on Layout.preferredWidth {
                        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
                    }
                }

                Repeater {
                    id: notificationRepeater
                    model: server.trackedNotifications
                    delegate: NotificationToast {

                        required property var modelData
                        required property int index
                        id: toast
                        notif: modelData
                        notifIndex: index

                        Layout.alignment: Qt.AlignHCenter

                        Behavior on y {
                            NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
                        }
                    }
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

        // Enter state used to animate from zero size to full size
        property bool entered: false
        property bool expiring: false
        property bool forceClose: false

        // Cached image: set on first load, only updated if a new notification brings its own image
        property string cachedImage: ""

        visible: Layout.preferredWidth > 0 && Layout.preferredHeight > 0
        property bool isShowing: (hoverHandler.hovered || entered && !expiring) && !forceClose

        readonly property bool hasInlineReply:
            toastRow.notif && toastRow.notif.hasInlineReply

        // ── Urgency helpers ──────────────────────────────────────────
        readonly property bool isCritical:
            toastRow.notif && toastRow.notif.urgency === Notif.NotificationUrgency.Critical
        readonly property bool isLow:
            toastRow.notif && toastRow.notif.urgency === Notif.NotificationUrgency.Low

        // Effective timeout: use notification's own value; fall back to 5 s;
        // Critical notifications linger until dismissed.
        readonly property int effectiveTimeout:
            isCritical ? 0
            : (toastRow.notif && toastRow.notif.expireTimeout > 0 ? toastRow.notif.expireTimeout : 15000)

        // ── Sizing & shape ────────────────────────────────────────────
        Layout.preferredHeight: toastRow.isShowing ? (contentColumn.implicitHeight + 20) : 0
        Layout.preferredWidth: toastRow.isShowing ? contentColumn.implicitWidth : 0

        Layout.minimumWidth: toastRow.isShowing ? root.notifWidth : 0
        clip: true

        radius: Theme.moduleEdgeRadius

        // ── Colors ────────────────────────────────────────────────────
        variant: isCritical ? "danger" : "light"
        opacity: Theme.moduleOpacity
        border.color: "#f38ba8"
        border.width: isCritical ? 2 : 0

        // ── Enter animation: slide in from the right ─────────────────
        Component.onCompleted: {
            root.notificationNumber++
            SharedState.notificationCounter = root.notificationNumber
            toastRow.entered = true
            if (toastRow.notif && toastRow.notif.image !== "")
                toastRow.cachedImage = toastRow.notif.image
        }

        Behavior on Layout.preferredHeight {
            NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
        }
        Behavior on Layout.preferredWidth {
            NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
        }

        Timer {
            id: expireTimer
            interval: toastRow.effectiveTimeout

            running: toastRow.effectiveTimeout > 0
            repeat: false

            onTriggered: toastRow.entered = false

        }

        onClicked: {
            toastRow.forceClose = true
            toastRow.requestDismiss()
        }

        function submitInlineReply() {
            if (!toastRow.notif || !toastRow.hasInlineReply) return
            var replyText = replyInput.text.trim()
            if (replyText.length === 0) return
            toastRow.notif.sendInlineReply(replyText)
            replyInput.text = ""
        }

        // ── Content ────────────────────────────────────────────────────
        GridLayout {
            id: contentColumn // Kept original ID in case it is referenced outside
            anchors.fill: parent

            columns: 2
            rowSpacing: 0 // From your original contentColumn
            columnSpacing: Theme.modulePaddingH // From your original contentLayout

            // ─── ROW 0 ─────────────────────────────────────────────────
            // [Row 0, Col 0] Image Block
            ColumnLayout {
                id: imageColumn
                Layout.row: 0
                Layout.column: 0
                
                spacing: 0
                Layout.alignment: Qt.AlignLeft
                Layout.leftMargin: Theme.modulePaddingH

                // Image block: shows notification image if available, otherwise app icon; hidden if neither are provided
                Item {

                    readonly property bool hasImage: toastRow.cachedImage !== ""
                    readonly property bool hasIcon:  toastRow.notif && toastRow.notif.appIcon !== ""
                    visible: hasImage || hasIcon

                    Layout.preferredHeight: hasImage || hasIcon ? 50 : 0
                    Layout.preferredWidth: hasImage || hasIcon ? 50 : 0

                    Image {
                        anchors.fill: parent
                        source: parent.hasImage ? toastRow.cachedImage : ("image://icon/" + toastRow.notif.appIcon)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        cache: true
                    }
                }

                Text {
                    text: Qt.formatDateTime(new Date(), "HH:mm")
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 3
                    font.bold: true
                    color: toastRow.textColor
                    opacity: 0.8
                    elide: Text.ElideRight
                    Layout.topMargin: 5
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // [Row 0, Col 1] Text Block
            ColumnLayout {
                Layout.row: 0
                Layout.column: 1
                
                spacing: 0
                Layout.fillWidth: true
                Layout.rightMargin: Theme.modulePaddingH
                
                // app name
                Text {
                    text: toastRow.notif ? toastRow.notif.appName : ""
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    font.bold: true
                    color: toastRow.textColor
                    opacity: 0.7
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                // Summary
                Text {
                    visible: toastRow.notif && toastRow.notif.summary !== ""
                    text: toastRow.notif ? toastRow.notif.summary : ""
                    font.family:    Theme.font
                    font.pixelSize: toastRow.Theme.fontSize
                    font.bold:      true
                    color:          toastRow.textColor
                    wrapMode:       Text.WrapAtWordBoundaryOrAnywhere
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.max(actionRow.implicitWidth - imageColumn.implicitWidth, root.notifWidth - imageColumn.implicitWidth - Theme.modulePaddingH * 4)
                }

                // Body
                Text {
                    visible: toastRow.notif && toastRow.notif.body !== ""
                    text: toastRow.notif ? toastRow.notif.body : ""
                    font.family:    Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    color:          toastRow.textColor
                    opacity: 0.7
                    wrapMode:       Text.WrapAtWordBoundaryOrAnywhere
                    elide: Text.ElideRight
                    maximumLineCount: 6
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.max(actionRow.implicitWidth - imageColumn.implicitWidth, root.notifWidth - imageColumn.implicitWidth - Theme.modulePaddingH * 4)
                }
            }

            // ─── ROW 1 ─────────────────────────────────────────────────
            // [Row 1, Col 0 & 1] Actions (Spans both columns)
            RowLayout {
                id: actionRow
                Layout.row: 1
                Layout.column: 0
                Layout.columnSpan: 2 // Stretches all the way across the grid
                
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignLeft
                Layout.leftMargin: Theme.modulePaddingH
                Layout.rightMargin: Theme.modulePaddingH
                Layout.bottomMargin: toastRow.hasInlineReply ? 8 : Theme.modulePaddingH
                spacing: 8
                
                // Only show this row if the notification actually has actions
                visible: toastRow.notif && toastRow.notif.actions.length > 0

                Repeater {
                    model: toastRow.notif ? toastRow.notif.actions : []

                    delegate: ModuleButton {
                        label: modelData.text
                        Layout.preferredHeight: 28
                        radius: Theme.moduleEdgeRadius
                        textFont: Theme.fontSize - 2
                        
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.invoke()
                    }
                }
            }

            // ─── ROW 2 ─────────────────────────────────────────────────
            // [Row 2, Col 0 & 1] Inline Reply (Spans both columns)
            ModuleButton {
                id: inlineReplyRow
                Layout.row: 2
                Layout.column: 0
                Layout.columnSpan: 2 // Stretches all the way across the grid
                
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: Theme.modulePaddingH
                Layout.rightMargin: Theme.modulePaddingH
                Layout.bottomMargin: Theme.modulePaddingH
                visible: toastRow.hasInlineReply
                implicitHeight: 30

                variant: "dark"
                noHoverColorChange: true
                radius: Theme.moduleEdgeRadius
                cursorShape: Qt.PointingHandCursor

                TextInput {
                    id: replyInput
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.palette("dark").text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    clip: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: (toastRow.notif && toastRow.notif.inlineReplyPlaceholder !== "")
                                ? toastRow.notif.inlineReplyPlaceholder
                                : "Reply..."
                        color: Theme.palette("dark").text
                        opacity: 0.7
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        visible: !replyInput.text.length
                    }

                    Keys.onReturnPressed: {
                        root.inlineReplyInputFocused = false
                        toastRow.submitInlineReply()
                    }
                    onActiveFocusChanged: {
                        if (activeFocus) {
                            root.inlineReplyInputFocused = true
                        } else {
                            root.inlineReplyInputFocused = false
                        }
                    }
                }
            }
        }

        function requestDismiss() {
            if (!toastRow.notif || toastRow.expiring) return
            toastRow.entered = false
            toastRow.expiring = true
            root.inlineReplyInputFocused = false
            expireCallTimer.start()
        }

        function revive() {
            if (toastRow.notif && toastRow.notif.image !== "")
                toastRow.cachedImage = toastRow.notif.image
            toastRow.forceClose = false
            toastRow.expiring = false
            toastRow.entered = true
            expireCallTimer.stop()
            expireTimer.restart()
            Quickshell.execDetached(["pw-play", "--volume", "2.0", "/home/doni/nixos-config/misc/ping.ogg"])
        }

        Connections {
            target: toastRow.notif
            function onBodyChanged()    { toastRow.revive() }
            function onSummaryChanged() { toastRow.revive() }
        }

        Timer {
            id: expireCallTimer
            interval: Theme.verticalDuration + 20
            repeat: false
            onTriggered: {
                root.notificationNumber--
                SharedState.notificationCounter = root.notificationNumber
                if (toastRow.notif) toastRow.notif.dismiss()
            }
        }
    }
    HoverHandler {
        id: hoverHandler

        onHoveredChanged: {
            if (!hoverHandler.hovered) {
                root.inlineReplyInputFocused = false
            }
        }
    }
}
