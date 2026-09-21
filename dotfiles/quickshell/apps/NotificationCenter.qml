// NotificationCenter.qml — DBus notification server & notification center
// Displays notifications in a unified card inside the corner base container with inverse radiuses.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications as Notif

import "../elements"

Item {
    id: root

    // ── Geometry & State ────────────────────────────────────────────────
    readonly property int cardWidth: 350
    readonly property int maxCardHeight: 650

    property bool inlineReplyInputFocused: false
    property bool isManuallyOpen: false
    property bool hasActiveToasts: false
    property string screenName: ""

    property int contentUpdateTrigger: 0

    function updateActiveToasts() {
        var active = false
        for (var i = 0; i < notificationRepeater.count; ++i) {
            var item = notificationRepeater.itemAt(i)
            if (item && item.isToastActive) {
                active = true
                break
            }
        }
        root.hasActiveToasts = active
        root.contentUpdateTrigger++
    }

    // Hover management
    readonly property bool isHovered: (cornerHoverHandler && cornerHoverHandler.hovered) || (containerRect && containerRect.isHovered === true)
    readonly property bool showAllNotifications: isHovered || isManuallyOpen || inlineReplyInputFocused

    readonly property bool isCardOpen: isManuallyOpen || hasActiveToasts || isHovered || inlineReplyInputFocused

    onIsCardOpenChanged: {
        if (!isCardOpen && typeof notifTopBar !== "undefined" && notifTopBar) {
            notifTopBar.volExpanded = false
        }
    }

    // Overall geometry sizing for Bar.qml's mask Region
    implicitWidth: Math.max(notifGrid.implicitWidth, cornerTrigger.width)
    implicitHeight: Math.max(notifGrid.implicitHeight, cornerTrigger.height)

    width: implicitWidth
    height: implicitHeight

    // IPC support for external toggle (e.g. hyprland keybinding)
    IpcHandler {
        target: screenName !== "" ? "notifications-" + screenName : "notifications"
        function toggle(): void {
            root.isManuallyOpen = !root.isManuallyOpen
        }
        function open(): void {
            root.isManuallyOpen = true
        }
        function close(): void {
            root.isManuallyOpen = false
        }
    }

    function dismissAll() {
        SharedState.dismissAllNotifications()
    }

    // ── Corner Base with Inverse Radiuses ───────────────────────────────
    GridLayout {
        id: notifGrid
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        columns: 2
        columnSpacing: 0
        rowSpacing: 0

        // [Row 0, Col 1] Top Inverse Radius
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
            color: containerRect.color
            animated: false
        }

        // [Row 1, Col 0] Side/Bottom Inverse Radius
        InverseRadius {
            id: sideRadius
            Layout.row: 1
            Layout.column: 0
            Layout.alignment: Qt.AlignRight | Qt.AlignBottom

            cornerPosition: "bottomRight"
            smoothCurve: true
            smoothTolerance: 0.4477 * Theme.moduleEdgeRadius / Math.max(sizeV, 1)
            sizeH: Math.max(containerRect.implicitHeight / 8, Theme.moduleEdgeRadius)
            sizeV: containerRect.implicitHeight
            color: containerRect.color
            expandingH: root.isCardOpen || containerRect.implicitHeight > 1
            expandingV: root.isCardOpen || containerRect.implicitHeight > 1
            animated: false
        }

        // [Row 1, Col 1] Main Notification Container
        Rectangle {
            id: containerRect
            Layout.row: 1
            Layout.column: 1
            Layout.alignment: Qt.AlignRight | Qt.AlignBottom
            Layout.maximumHeight: root.maxCardHeight + 50

            color: Qt.rgba(Theme.dark.base.r, Theme.dark.base.g, Theme.dark.base.b, Theme.moduleOpacity)
            clip: true
            topLeftRadius: Theme.moduleEdgeRadius + 10

            implicitWidth: root.isCardOpen ? (root.showAllNotifications ? (root.cardWidth + 20) : root.cardWidth) : Theme.moduleEdgeRadius
            implicitHeight: root.isCardOpen ? Math.min(root.maxCardHeight, cardContentHeight + 20) : 0

            Behavior on implicitWidth { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

            function calculateNotifColumnHeight() {
                var total = 0
                var visibleCount = 0
                for (var i = 0; i < notificationRepeater.count; ++i) {
                    var item = notificationRepeater.itemAt(i)
                    if (item && item.shouldBeVisible) {
                        total += item.implicitHeight
                        visibleCount++
                    }
                }
                if (visibleCount > 0) {
                    total += (visibleCount - 1) * notifColumn.spacing + notifColumn.topPadding + notifColumn.bottomPadding
                }
                return total
            }

            readonly property int cardContentHeight: {
                var _ = root.contentUpdateTrigger + root.showAllNotifications + notificationRepeater.count
                if (!root.showAllNotifications) {
                    return calculateNotifColumnHeight()
                }
                if (notificationRepeater.count === 0) {
                    return 55 + emptyState.implicitHeight
                }
                return 55 + calculateNotifColumnHeight()
            }

            property bool isHovered: (containerHoverHandler ? containerHoverHandler.hovered : false) || (cardHoverHandler ? cardHoverHandler.hovered : false)

            HoverHandler {
                id: containerHoverHandler
                onHoveredChanged: {
                    if (!containerHoverHandler.hovered && !cornerHoverHandler.hovered) {
                        root.inlineReplyInputFocused = false
                    }
                }
            }

            // ── The Unified Card Inside Base Container ──────────────────
            Rectangle {
                id: card
                anchors.fill: parent
                anchors.margins: 10

                color: root.showAllNotifications ? Theme.bgBlurColor : "transparent"
                radius: Theme.moduleEdgeRadius / 2 + 10
                border.width: root.showAllNotifications ? 2 : 0
                border.color: root.showAllNotifications ? Theme.cardBorder : "transparent"
                clip: true

                Behavior on color { ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

                opacity: root.isCardOpen ? 1.0 : 0.0
                visible: opacity > 0

                HoverHandler {
                    id: cardHoverHandler
                }

                Behavior on opacity { NumberAnimation { duration: Theme.verticalDuration / 2; easing.type: Easing.OutCubic } }

                // ── Card Top Bar ────────────────────────────────────────
                Rectangle {
                    id: notifTopBar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: root.showAllNotifications ? 35 : 0
                    opacity: root.showAllNotifications ? 1.0 : 0.0
                    visible: opacity > 0
                    clip: true
                    Behavior on opacity { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }
                    color: Theme.topBarBlurColor
                    z: 10

                    topLeftRadius: parent.radius
                    topRightRadius: parent.radius
                    bottomLeftRadius: 0
                    bottomRightRadius: 0

                    property bool volExpanded: false

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 6

                        Text {
                            text: notifTopBar.volExpanded ? "Volume" : "Notification Center"
                            color: Theme.textPrimary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize + 1
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        // Clear all button (visible when there are notifications)
                        ModuleButton {
                            id: clearAllBtn
                            visible: notificationRepeater.count > 0
                            variant: "neutral"
                            label: "󰅖"
                            textFont: 14
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.dismissAll()
                            implicitHeight: 24
                            implicitWidth: 24
                            radius: Theme.moduleEdgeRadius / 2
                            border.width: 2
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Button to reveal the volume control / toggle mute
                        ModuleButton {
                            id: volToggleBtn
                            variant: SharedState.muted ? "red" : "neutral"
                            label: SharedState.muted ? "󰖁" : "󰕾"
                            textFont: 14
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!notifTopBar.volExpanded) {
                                    notifTopBar.volExpanded = true
                                } else {
                                    SharedState.muted = !SharedState.muted
                                }
                            }
                            implicitHeight: 24
                            implicitWidth: 24
                            radius: Theme.moduleEdgeRadius / 2
                            border.width: 2
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Inline sliding volume editor
                        Item {
                            id: volEditorContainer
                            clip: true
                            implicitHeight: 24
                            Layout.preferredHeight: 24
                            Layout.preferredWidth: notifTopBar.volExpanded ? 135 : 0
                            visible: Layout.preferredWidth > 0 || notifTopBar.volExpanded
                            opacity: notifTopBar.volExpanded ? 1.0 : 0.0
                            Layout.alignment: Qt.AlignVCenter

                            Behavior on Layout.preferredWidth {
                                NumberAnimation {
                                    duration: Theme.horizontalDuration
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.horizontalDuration
                                    easing.type: Easing.OutCubic
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                spacing: 6

                                StyledSlider {
                                    Layout.fillWidth: true
                                    sliderHeight: 20
                                    radius: Theme.moduleEdgeRadius / 2
                                    from: 0.0
                                    to: 1.0
                                    value: SharedState.notifVolume
                                    onValueChanged: {
                                        SharedState.notifVolume = value
                                        if (value > 0 && SharedState.muted) {
                                            SharedState.muted = false
                                        }
                                    }
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: Math.round(SharedState.notifVolume * 100) + "%"
                                    color: Theme.textPrimary
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 2
                                    font.bold: true
                                    opacity: 0.8
                                    Layout.minimumWidth: 28
                                    horizontalAlignment: Text.AlignRight
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }
                    }
                }

                InverseRadius {
                    anchors.top: notifTopBar.bottom
                    anchors.left: notifTopBar.left
                    color: notifTopBar.color
                    visible: root.showAllNotifications && notifTopBar.height > 0
                    opacity: root.showAllNotifications ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }
                    z: 10
                }

                InverseRadius {
                    cornerPosition: "topRight"
                    anchors.top: notifTopBar.bottom
                    anchors.right: notifTopBar.right
                    color: notifTopBar.color
                    visible: root.showAllNotifications && notifTopBar.height > 0
                    opacity: root.showAllNotifications ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }
                    z: 10
                }

                Item {
                    anchors.top: notifTopBar.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: root.showAllNotifications ? 10 : 0
                    visible: height > 0
                    z: 10
                    MouseArea {
                        anchors.fill: parent
                    }
                }

                Item {
                    id: contentMask
                    anchors.fill: mainContentArea
                    visible: false
                    layer.enabled: true
                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                        radius: Theme.moduleEdgeRadius - 5
                    }
                }

                // ── Main Content Area ───────────────────────────────────
                Item {
                    id: mainContentArea
                    anchors.top: notifTopBar.bottom
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.cardWidth - 20
                    anchors.bottomMargin: root.showAllNotifications ? 10 : 0
                    anchors.topMargin: root.showAllNotifications ? 10 : 0

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: root.showAllNotifications
                        maskSource: contentMask
                    }

                    // ── Empty State ─────────────────────────────────────
                    Item {
                        id: emptyState
                        visible: root.showAllNotifications && notificationRepeater.count === 0
                        anchors.fill: parent
                        implicitHeight: 110

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "󰂚"
                                color: Theme.textPrimary
                                opacity: 0.35
                                font.family: Theme.font
                                font.pixelSize: 32
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: "No notifications"
                                color: Theme.textPrimary
                                opacity: 0.65
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // ── Notifications List ──────────────────────────────
                    Flickable {
                        id: notifFlickable
                        visible: notificationRepeater.count > 0
                        anchors.fill: parent
                        clip: false
                        contentWidth: width
                        contentHeight: notifColumn.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        Connections {
                            target: SharedState.notificationsModel
                            function onRowsInserted(parent, first, last) {
                                if (first === 0 && notifFlickable.contentY !== 0) {
                                    notifFlickable.contentY = 0
                                }
                                root.contentUpdateTrigger++
                            }
                            function onRowsRemoved() {
                                root.contentUpdateTrigger++
                            }
                            function onModelReset() {
                                root.contentUpdateTrigger++
                            }
                        }

                        Column {
                            id: notifColumn
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.cardWidth - 20
                            spacing: 8
                            topPadding: 0
                            bottomPadding: 0

                            move: Transition {
                                NumberAnimation { properties: "y"; duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
                            }

                            Repeater {
                                id: notificationRepeater
                                model: SharedState.notificationsModel
                                delegate: NotificationToast {
                                    id: toast
                                    required property var notifData
                                    required property int index

                                    notif: notifData
                                    notifIndex: index
                                    width: notifColumn.width

                                    onIsToastActiveChanged: root.updateActiveToasts()
                                    Component.onCompleted: root.updateActiveToasts()
                                    Component.onDestruction: root.updateActiveToasts()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Corner Hotspot / Trigger ────────────────────────────────────────
    Item {
        id: cornerTrigger
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: Theme.moduleEdgeRadius
        height: Theme.moduleEdgeRadius
        z: 10

        HoverHandler {
            id: cornerHoverHandler
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.isManuallyOpen = !root.isManuallyOpen
        }
    }

    // ── Single Notification Toast Component ─────────────────────────────
    component NotificationToast: ModuleButton {
        id: toastRow

        property var notif: null
        property int notifIndex: 0
        property bool isToastActive: false
        property string cachedImage: ""

        readonly property bool hasInlineReply: notif && notif.hasInlineReply
        readonly property bool isCritical: notif && notif.urgency === Notif.NotificationUrgency.Critical
        readonly property bool isLow: notif && notif.urgency === Notif.NotificationUrgency.Low
        readonly property int effectiveTimeout: isCritical ? 0 : (notif && notif.expireTimeout > 0 ? notif.expireTimeout : 5000)

        variant: isCritical ? "red" : "neutral"
        radius: Theme.moduleEdgeRadius / 2 + 5
        border.width: 2
        clip: true

        readonly property bool shouldBeVisible: root.showAllNotifications || isToastActive

        implicitHeight: contentGrid.implicitHeight + 20
        height: shouldBeVisible ? implicitHeight : 0
        visible: shouldBeVisible || height > 0
        opacity: shouldBeVisible ? 1.0 : 0.0

        Behavior on height { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

        Component.onCompleted: {
            if (toastRow.notif && toastRow.notif.image !== "")
                toastRow.cachedImage = toastRow.notif.image

            // Only start the 5s timer once when a new notification arrives
            if (toastRow.effectiveTimeout > 0) {
                toastRow.isToastActive = true
                expireTimer.start()
            }
        }

        Timer {
            id: expireTimer
            interval: toastRow.effectiveTimeout
            running: false
            repeat: false
            onTriggered: {
                toastRow.isToastActive = false
            }
        }

        onHoveredChanged: {
            if (toastRow.hovered && expireTimer.running) {
                expireTimer.stop()
                toastRow.isToastActive = false
            }
        }

        function dismiss() {
            expireTimer.stop()
            toastRow.isToastActive = false
            if (toastRow.notif && toastRow.notif.dismiss) {
                toastRow.notif.dismiss()
            }
            SharedState.removeNotification(toastRow.notif)
        }

        function submitInlineReply() {
            if (!toastRow.notif || !toastRow.hasInlineReply) return
            var replyText = replyInput.text.trim()
            if (replyText.length === 0) return
            toastRow.notif.sendInlineReply(replyText)
            replyInput.text = ""
        }

        function revive() {
            if (toastRow.notif && toastRow.notif.image !== "")
                toastRow.cachedImage = toastRow.notif.image
            timeText.text = Qt.formatDateTime(new Date(), "HH:mm")
            if (toastRow.effectiveTimeout > 0) {
                toastRow.isToastActive = true
                expireTimer.restart()
            }
            SharedState.playNotificationSound()
        }

        Connections {
            target: toastRow.notif
            function onBodyChanged()    { toastRow.revive() }
            function onSummaryChanged() { toastRow.revive() }
        }

        onClicked: {
            toastRow.dismiss()
        }

        GridLayout {
            id: contentGrid
            anchors.fill: parent
            anchors.margins: 10
            columns: 2
            rowSpacing: 8
            columnSpacing: 10

            // [Row 0, Col 0] App Icon & Time
            ColumnLayout {
                Layout.row: 0
                Layout.column: 0
                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                spacing: 4

                Item {
                    readonly property bool hasImage: toastRow.cachedImage !== ""
                    readonly property bool hasIcon: toastRow.notif && toastRow.notif.appIcon !== ""
                    visible: hasImage || hasIcon
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40

                    Image {
                        anchors.fill: parent
                        source: parent.hasImage ? toastRow.cachedImage : ((parent.hasIcon && toastRow.notif) ? "image://icon/" + toastRow.notif.appIcon : "")
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        cache: true
                        sourceSize.width: 40
                        sourceSize.height: 40
                    }
                }

                Text {
                    id: timeText
                    text: Qt.formatDateTime(new Date(), "HH:mm")
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 3
                    font.bold: true
                    color: toastRow.textColor
                    opacity: 0.75
                    elide: Text.ElideRight
                    Layout.alignment: Qt.AlignCenter
                }
            }

            // [Row 0, Col 1] Text Info
            ColumnLayout {
                Layout.row: 0
                Layout.column: 1
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                spacing: 5

                // App Name
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
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    color: toastRow.textColor
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    Layout.fillWidth: true
                }

                // Body
                Text {
                    id: bodyText
                    visible: toastRow.notif && toastRow.notif.body !== ""
                    text: toastRow.notif ? toastRow.notif.body : ""
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    color: toastRow.textColor
                    opacity: 0.8
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    elide: Text.ElideRight
                    maximumLineCount: 5
                    Layout.fillWidth: true
                }

                // Show More / Less
                ModuleButton {
                    variant: "light"
                    visible: bodyText.visible && (bodyText.truncated || bodyText.maximumLineCount > 5)
                    label: bodyText.maximumLineCount === 5 ? "Show More" : "Show Less"
                    radius: Theme.moduleEdgeRadius / 2
                    implicitHeight: 20
                    border.width: 2
                    textFont: Theme.fontSize - 3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (bodyText.maximumLineCount === 5) {
                            bodyText.maximumLineCount = 1000
                        } else {
                            bodyText.maximumLineCount = 5
                        }
                    }
                }
            }

            // [Row 1] Actions
            Flickable {
                id: actionFlickable
                Layout.row: 1
                Layout.column: 0
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                visible: toastRow.notif && toastRow.notif.actions.length > 0
                clip: true
                contentWidth: actionRow.implicitWidth
                contentHeight: 26
                interactive: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: actionRow
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: toastRow.notif ? toastRow.notif.actions : []
                        delegate: ModuleButton {
                            variant: "light"
                            label: modelData.text
                            border.width: 2
                            height: 24
                            radius: Theme.moduleEdgeRadius / 2
                            textFont: Theme.fontSize - 2
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.invoke()
                        }
                    }
                }
            }

            // [Row 2] Inline Reply
            ModuleButton {
                id: inlineReplyRow
                Layout.row: 2
                Layout.column: 0
                Layout.columnSpan: 2
                Layout.fillWidth: true
                visible: toastRow.hasInlineReply
                implicitHeight: 28

                variant: "dark"
                noHoverColorChange: true
                radius: Theme.moduleEdgeRadius / 2
                cursorShape: Qt.PointingHandCursor

                TextInput {
                    id: replyInput
                    anchors {
                        fill: parent
                        leftMargin: 8
                        rightMargin: 8
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
                        root.inlineReplyInputFocused = activeFocus
                    }
                }
            }

            // [Row 3] Timer Progress Bar
            Rectangle {
                id: notifTimer
                Layout.row: 3
                Layout.column: 0
                Layout.columnSpan: 2
                Layout.fillWidth: true
                visible: expireTimer.running
                height: 3
                radius: 1.5
                color: Theme.palettePaper
                opacity: 0.4

                property real progress: 1.0
                width: contentGrid.width * progress
                NumberAnimation on progress {
                    from: 1.0
                    to: 0.0
                    duration: expireTimer.interval
                    running: expireTimer.running
                }

                Connections {
                    target: expireTimer
                    function onRunningChanged() {
                        if (!expireTimer.running) {
                            notifTimer.progress = 1.0
                        }
                    }
                }
            }
        }
    }
}
