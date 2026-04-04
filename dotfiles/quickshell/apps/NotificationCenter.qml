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


    layer.enabled: true
    
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
            smoothCurve: true
            smoothTolerance: 0.4477 * Theme.moduleEdgeRadius / sizeH
            sizeH: Math.max(containerRect.implicitWidth, Theme.moduleEdgeRadius)
            sizeV: Math.max(containerRect.implicitWidth / 8, Theme.moduleEdgeRadius)
            color: Theme.palette("dark").base
            animated: false
        }

        // [Row 1, Col 0] Side/Bottom Radius
        InverseRadius {
            Layout.row: 1
            Layout.column: 0
            Layout.alignment: Qt.AlignRight | Qt.AlignBottom
            
            cornerPosition: "bottomRight"
            smoothCurve: true
            smoothTolerance: 0.4477 * Theme.moduleEdgeRadius / sizeV
            sizeH: Math.max(containerRect.implicitHeight / 8, Theme.moduleEdgeRadius)
            sizeV: containerRect.implicitHeight
            color: Theme.palette("dark").base
            expandingH: (innerLayout.implicitWidth !== 0 || hoverHandler.hovered)
            expandingV: (innerLayout.implicitWidth !== 0 || hoverHandler.hovered)
            animated: false
        }

        // [Row 1, Col 1] Main Notification Container
        Rectangle {
            id: containerRect
            Layout.row: 1
            Layout.column: 1
            Layout.alignment: Qt.AlignRight | Qt.AlignBottom
            Layout.maximumHeight: 900 

            color: Theme.palette("dark").base
            clip: true
            topLeftRadius: Theme.moduleEdgeRadius + 5
            
            implicitWidth: (innerLayout.implicitWidth === 0 && !hoverHandler.hovered) ? topRadius.size : (Math.max(innerLayout.implicitWidth, headerButton.implicitWidth) + 20)

            property real hoverProgress: hoverHandler.hovered ? 1.0 : 0.0
            Behavior on hoverProgress { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

            property real headerOffset: hoverProgress * (20 + headerButton.implicitHeight)

            property real activePadding: innerLayout.implicitHeight > 0 ? 20 : 0
            Behavior on activePadding { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

            implicitHeight: Math.min(headerOffset + innerLayout.smoothHeight + activePadding, Layout.maximumHeight)

            Behavior on implicitWidth { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic } }

            // ── HEADER ──────────────────────────────────────────────────
            Rectangle {
                id: headerButton
                
                // Simplified positioning mapping seamlessly above the notification scroll area
                anchors.bottom: notifFlickable.top
                anchors.bottomMargin: 20
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                
                opacity: containerRect.hoverProgress
                visible: opacity > 0
                
                implicitHeight: headerColumn.implicitHeight + 15
                implicitWidth: headerColumn.implicitWidth
                
                radius: Theme.moduleEdgeRadius
                color: Theme.divider
                clip: true

                ColumnLayout {
                    id: headerColumn
                    anchors{
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: 10
                        leftMargin: 10
                        rightMargin: 10
                    }
                    
                    ModuleButton {
                        id: headerLabel
                        
                        textFont: 20
                        variant: "dark"
                        color: "transparent"
                        label: "󰎟 Notification Center"
                        radius: Theme.moduleEdgeRadius
                        
                        Layout.preferredHeight: 30
                        Layout.fillWidth: true

                        cursorShape: Qt.PointingHandCursor
                        onClicked: volumeSliderContainer.showing = !volumeSliderContainer.showing
                    }

                    Item {
                        id: volumeSliderContainer
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: parent.width * 0.9
                        
                        property bool showing: false
                        Layout.preferredHeight: showing ? 40 : 0
                        opacity: showing ? 1 : 0
                        clip: true

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
                                onClicked: SharedState.muted = !SharedState.muted
                            }

                            StyledSlider {
                                Layout.fillWidth: true
                                from: 0.0
                                to: 1.0
                                value: SharedState.notifVolume
                                onValueChanged: SharedState.notifVolume = value
                            }
                        }
                    }
                }
            }

            // ── SCROLLING AREA ──────────────────────────────────────────
            Flickable {
                id: notifFlickable
                
                anchors.top: parent.top
                anchors.topMargin: containerRect.headerOffset + 10
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                
                contentWidth: width
                contentHeight: Math.max(innerLayout.smoothHeight + containerRect.activePadding, height)
                
                clip: true
                interactive: true

                onContentHeightChanged: {
                    if (contentHeight > height && !dragging  && !hoverHandler.hovered) {
                        contentY = contentHeight - height
                    }
                }
                onHeightChanged: {
                    if (contentHeight > height && !dragging) {
                        contentY = contentHeight - height
                    }
                }

                Column {
                    id: innerLayout
                    
                    width: parent.width - 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    
                    property real smoothHeight: implicitHeight
                    Behavior on smoothHeight {
                        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
                    }

                    // Bottom alignment glide to prevent layout jumps
                    y: Math.max(10, notifFlickable.height - smoothHeight - 10)

                    move: Transition {
                        NumberAnimation { properties: "y"; duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
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

                            anchors.horizontalCenter: parent.horizontalCenter
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

        property bool showing: false
        property bool dismissing: false

        // Cached image: set on first load, only updated if a new notification brings its own image
        property string cachedImage: ""

        property bool shouldBeVisible: !dismissing && (hoverHandler.hovered || showing)
        visible: opacity > 0 || height > 0

        onOpacityChanged: {
            if (opacity === 0 && dismissing && toastRow.notif) {
                toastRow.notif.dismiss()
            }
        }

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
        property real moduleHeight: contentGrid.implicitHeight + Theme.modulePaddingH * 2
        property real moduleWidth: contentGrid.implicitWidth + Theme.modulePaddingH * 2


        height: shouldBeVisible ? moduleHeight : 0.0
        width: shouldBeVisible ? moduleWidth : 0.0

        clip: true

        radius: Theme.moduleEdgeRadius

        // ── Colors ────────────────────────────────────────────────────
        variant: isCritical ? "danger" : "light"

        opacity: shouldBeVisible ? 1 : 0.0

        border.color: "#f38ba8"
        border.width: isCritical ? 2 : 0

        Component.onCompleted: {
            if (toastRow.notif && toastRow.notif.image !== "")
                toastRow.cachedImage = toastRow.notif.image

            toastRow.showing = true 
        }

        Timer {
            id: expireTimer
            interval: toastRow.effectiveTimeout

            running: toastRow.effectiveTimeout > 0 && !hoverHandler.hovered
            repeat: false

            onTriggered: toastRow.showing = false


        }

        onClicked: {
            toastRow.dismissing = true
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
                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop

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
                    id: timeText
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
                
                spacing: 3
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
                    id: bodyText
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

                // Show More / Show Less button for long notifications
                ModuleButton {
                    visible: bodyText.visible && (bodyText.truncated || bodyText.maximumLineCount > 6)
                    
                    label: bodyText.maximumLineCount === 6 ? "Show More" : "Show Less"
                    
                    radius: Theme.moduleEdgeRadius

                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (bodyText.maximumLineCount === 6) {
                            bodyText.maximumLineCount = 1000
                        } else {
                            bodyText.maximumLineCount = 6
                        }
                    }
                }
            }

            // ─── ROW 1 ─────────────────────────────────────────────────
            // [Row 1, Col 0 & 1] Actions (Spans both columns)
            RowLayout {
                id: actionRow
                Layout.row: 1
                Layout.column: 0
                Layout.columnSpan: 2
                
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
                Layout.columnSpan: 2
                
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

        Behavior on height {
            NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
        }
        
        Behavior on width {
            NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
        }

        function revive() {
            if (toastRow.notif && toastRow.notif.image !== "")
                toastRow.cachedImage = toastRow.notif.image
            timeText.text = Qt.formatDateTime(new Date(), "HH:mm")
            toastRow.showing = true
            expireTimer.restart()
            
            SharedState.playNotificationSound()
        }

        Connections {
            target: toastRow.notif
            function onBodyChanged()    { toastRow.revive() }
            function onSummaryChanged() { toastRow.revive() }
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
