// NotificationServer.qml — DBus notification server
// Renders a stack of toast notifications in the bottom-right corner of the Bar.
import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls
import Quickshell.Services.Notifications as Notif

import "../elements"

Item {
    id: root

    // ── Geometry ────────────────────────────────────────────────────────
    readonly property int notifWidth:   300

    property bool inlineReplyInputFocused: false

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

            SharedState.playNotificationSound()
        }
    }

    // ── Notification stack ───────────────────────────────────────────────
    GridLayout {
        id: notifGrid
        columns: 2
        columnSpacing: 0
        rowSpacing: 0

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
            size: Math.max(Theme.moduleEdgeRadius, Math.floor(innerLayout.implicitHeight / 8))
            color: Theme.palette("dark").base
            expandingH: (innerLayout.implicitWidth !== 0 || hoverHandler.hovered)
            expandingV: (innerLayout.implicitWidth !== 0 || hoverHandler.hovered)
            animationDuration: Theme.verticalDuration
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
            implicitHeight: innerLayout.implicitHeight === 0 ? 0 : (innerLayout.implicitHeight + 20)

            Behavior on implicitHeight {
                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
            }
            Behavior on implicitWidth {
                NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }

            // Your exact inner layout, untouched
            Column {
                id: innerLayout
                anchors {
                    top: parent.top
                    topMargin: 10
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    bottomMargin: 10
                }

                spacing: 10
                clip: true

                move: Transition {
                    NumberAnimation { 
                        properties: "y" 
                        duration: Theme.verticalDuration 
                        easing.type: Easing.OutCubic 
                    }
                }

                // NEW: Animates new elements appearing
                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "scale"; from: 0.2; to: 1.0; duration: Theme.verticalDuration; easing.type: Easing.OutBack }
                    }
                }

                Rectangle {
                    id: headerButton
                    
                    anchors.horizontalCenter: parent.horizontalCenter 

                    visible: hoverHandler.hovered
                    implicitWidth: root.notifWidth + 20
                    implicitHeight: headerColumn.implicitHeight + 15
                    radius: Theme.moduleEdgeRadius
                    color: Theme.divider

                    ColumnLayout {
                        id: headerColumn

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        
                        ModuleButton {
                            
                            textFont: 20
                            variant: "dark"
                            color: "transparent"
                            label: "󰎟 Notification Center"

                            radius: Theme.moduleEdgeRadius
                            
                            // Use standard height/width instead of Layout.preferred
                            implicitHeight: 30
                            implicitWidth: root.notifWidth

                            cursorShape: Qt.PointingHandCursor
                            onClicked: volumeSliderContainer.showing = !volumeSliderContainer.showing
                        }

                        Item {
                            id: volumeSliderContainer
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: root.notifWidth * 0.9
                            Layout.preferredHeight: showing ? 40 : 0
                            
                            property bool showing: false
                            clip: true
                            opacity: showing ? Theme.moduleOpacity : 0

                            Behavior on Layout.preferredHeight {
                                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
                            }

                            RowLayout {
                                anchors.fill: parent
                                spacing: 10

                                ModuleButton {
                                    label: SharedState.muted ? "󰖁" : "󰕾"
                                    color: "transparent"

                                    implicitWidth: 30
                                    textFont: 20

                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        SharedState.muted = !SharedState.muted
                                        console.log("Muted:", SharedState.muted, "Volume:", SharedState.notifVolume)
                                    }
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 0.0
                                    to: 1.0
                                    value: SharedState.notifVolume
                                    onValueChanged: SharedState.notifVolume = value

                                    background: Rectangle {
                                        x: parent.leftPadding
                                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                        implicitWidth: 200
                                        implicitHeight: 14
                                        width: parent.availableWidth
                                        height: implicitHeight
                                        radius: 7
                                        color: Theme.palette("dark").hover

                                        Rectangle {
                                            id: progressFill
                                            width: parent.parent.visualPosition * parent.width
                                            height: parent.height
                                            color: parent.pressed ? Theme.palette("dark").hover : Theme.palette("light").base
                                            radius: 7
                                        }
                                    }

                                    handle: Rectangle {
                                        color: "transparent"
                                    }
                                }
                            }
                        }
                    }
                }
                
                Repeater {
                    id: notificationRepeater
                    model: server.trackedNotifications
                    delegate: NotificationToast {
                        id: toast
                        required property var modelData
                        required property int index
                        
                        notif: modelData
                        notifIndex: index

                        // Replaced Layout.alignment with standard anchors
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
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

        visible: (hoverHandler.hovered || entered && !expiring) && !forceClose

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
            : (toastRow.notif && toastRow.notif.expireTimeout > 0 ? toastRow.notif.expireTimeout : 5000)

        // ── Sizing & shape ────────────────────────────────────────────
        height: contentGrid.implicitHeight + Theme.modulePaddingH * 2
        width: contentGrid.implicitWidth + Theme.modulePaddingH * 2

        clip: true

        radius: Theme.moduleEdgeRadius

        // ── Colors ────────────────────────────────────────────────────
        variant: isCritical ? "danger" : "light"
        opacity: Theme.moduleOpacity
        border.color: "#f38ba8"
        border.width: isCritical ? 2 : 0

        // ── Enter animation: slide in from the right ─────────────────
        Component.onCompleted: {
            toastRow.entered = true
            if (toastRow.notif && toastRow.notif.image !== "")
                toastRow.cachedImage = toastRow.notif.image
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
            id: contentGrid
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left

            columns: 2
            rowSpacing: Theme.modulePaddingH
            columnSpacing: Theme.modulePaddingH
            anchors.margins: Theme.modulePaddingH

            // ─── ROW 0 ─────────────────────────────────────────────────
            // [Row 0, Col 0] Image Block
            ColumnLayout {
                id: imageColumn
                Layout.row: 0
                Layout.column: 0
                
                spacing: 5
                Layout.alignment: Qt.AlignCenter

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

                        sourceSize.width: 50
                        sourceSize.height: 50
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
                    Layout.alignment: Qt.AlignCenter
                }
            }

            // [Row 0, Col 1] Text Block
            ColumnLayout {
                Layout.row: 0
                Layout.column: 1
                
                spacing: 0
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                Layout.minimumWidth: root.notifWidth - 50
                Layout.maximumWidth: Math.max(root.notifWidth - 50, contentGrid.implicitWidth - imageColumn.implicitWidth - (Theme.modulePaddingH * 4))
                
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
                    font.pixelSize: Theme.fontSize
                    font.bold:      true
                    color:          toastRow.textColor
                    wrapMode:       Text.WrapAtWordBoundaryOrAnywhere
                    Layout.fillWidth: true
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
                }
            }

            // ─── ROW 1 ─────────────────────────────────────────────────
            // [Row 1, Col 0 & 1] Actions (Spans both columns)
            RowLayout {
                id: actionRow
                Layout.row: 1
                Layout.column: 0
                Layout.columnSpan: 2 // Stretches all the way across the grid
                
                Layout.alignment: Qt.AlignLeft
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
                Layout.alignment: Qt.AlignCenter
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
            
            SharedState.playNotificationSound()
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
