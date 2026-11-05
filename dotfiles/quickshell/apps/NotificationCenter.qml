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
        if (!isCardOpen && typeof card !== "undefined" && card) {
            card.volExpanded = false
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

            Behavior on implicitWidth { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutQuint } }
            Behavior on implicitHeight { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutQuint } }

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
                    return (Theme.cardHeaderHeight + 20) + emptyState.implicitHeight
                }
                return (Theme.cardHeaderHeight + 20) + calculateNotifColumnHeight()
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
            BaseCard {
                id: card
                anchors.fill: parent
                anchors.margins: 10

                color: root.showAllNotifications ? Theme.bgBlurColor : "transparent"
                border.width: root.showAllNotifications ? Theme.cardBorderWidth : 0
                border.color: root.showAllNotifications ? Theme.cardBorder : "transparent"
                shadowEnabled: false

                opacity: root.isCardOpen ? 1.0 : 0.0
                visible: opacity > 0

                HoverHandler {
                    id: cardHoverHandler
                }

                Behavior on opacity { NumberAnimation { duration: Theme.verticalDuration / 2; easing.type: Easing.OutCubic } }

                hasHeader: root.showAllNotifications
                property bool volExpanded: false

                headerContent: [
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                    },

                    // Centered default title "Notifications"
                    Text {
                        id: notifTitle
                        anchors.centerIn: parent
                        text: "Notifications"
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 3
                        font.bold: true
                        opacity: card.volExpanded ? 0.0 : 1.0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.horizontalDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                    },

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 7
                        spacing: 8


                        // Title when volume controls are expanded
                        Text {
                            id: volumeTitle
                            text: "Volume"
                            color: Theme.textPrimary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize + 1
                            font.bold: true
                            opacity: card.volExpanded ? 1.0 : 0.0
                            visible: opacity > 0
                            Layout.alignment: Qt.AlignVCenter

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.horizontalDuration
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        // Spacer pushing action controls to the right
                        Item {
                            Layout.fillWidth: true
                        }

                        // Inline sliding volume editor
                        Item {
                            id: volEditorContainer
                            clip: true
                            implicitHeight: 26
                            Layout.preferredHeight: 26
                            Layout.preferredWidth: card.volExpanded ? 165 : 0
                            visible: Layout.preferredWidth > 0 || card.volExpanded
                            opacity: card.volExpanded ? 1.0 : 0.0
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

                                // Button to toggle mute
                                HeaderButton {
                                    id: volMuteBtn
                                    icon: SharedState.muted ? "󰖁" : "󰕾"
                                    iconColor: SharedState.muted ? Theme.statusRed : Theme.textPrimary
                                    iconSize: 17
                                    implicitHeight: 22
                                    implicitWidth: 22
                                    onClicked: {
                                        SharedState.muted = !SharedState.muted
                                    }
                                }

                                StyledSlider {
                                    Layout.fillWidth: true
                                    sliderHeight: 24
                                    radius: Theme.cardButtonRadius - 6
                                    from: 0.0
                                    to: 1.0
                                    value: SharedState.notifVolume
                                    showText: true
                                    text: SharedState.muted ? "Muted" : Math.round(SharedState.notifVolume * 100) + "%"
                                    textColor: SharedState.muted ? Theme.statusRed : Theme.textPrimary
                                    onValueChanged: {
                                        SharedState.notifVolume = value
                                        if (value > 0 && SharedState.muted) {
                                            SharedState.muted = false
                                        }
                                    }
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }

                        // Button to toggle volume control expansion
                        HeaderButton {
                            id: volToggleBtn
                            icon: !card.volExpanded ? (SharedState.muted ? "󰖁" : "󰕾") : ""
                            iconColor: (!card.volExpanded && SharedState.muted) ? Theme.statusRed : Theme.textPrimary
                            iconSize: 17
                            onClicked: {
                                card.volExpanded = !card.volExpanded
                            }
                        }
                    }
                ]

                Item {
                    anchors.top: card.headerBar.bottom
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
                    anchors.top: card.headerBar.bottom
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
                                NumberAnimation { properties: "y"; duration: Theme.verticalDuration; easing.type: Easing.OutQuint }
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
        property string cachedImage: (notif && notif.image) ? notif.image : ""

        readonly property bool hasInlineReply: notif && notif.hasInlineReply
        readonly property bool isCritical: notif && notif.urgency === Notif.NotificationUrgency.Critical
        readonly property bool isLow: notif && notif.urgency === Notif.NotificationUrgency.Low
        readonly property int effectiveTimeout: isCritical ? 0 : (notif && notif.expireTimeout > 0 ? notif.expireTimeout : 5000)

        variant: isCritical ? "red" : "neutral"
        radius: expireTimer.running ? Theme.cardRadius : Theme.cardItemRadius
        border.width: 0
        clip: true

        readonly property bool shouldBeVisible: root.showAllNotifications || isToastActive

        readonly property int minCol0Height: (cachedImage !== "" ? 74 : 40)
        implicitHeight: Math.max(contentGrid.implicitHeight + 20, minCol0Height + 20)
        height: shouldBeVisible ? implicitHeight : 0
        visible: shouldBeVisible || height > 0
        opacity: shouldBeVisible ? 1.0 : 0.0

        Behavior on height { NumberAnimation { duration: Theme.verticalDuration; easing.type: toastRow.shouldBeVisible ? Easing.OutQuint : Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.verticalDuration; easing.type: toastRow.shouldBeVisible ? Easing.OutQuint : Easing.OutCubic } }

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
            SharedState.playNotificationSound(toastRow.notif)
        }


        Connections {
            target: toastRow.notif
            function onBodyChanged()    { toastRow.revive() }
            function onSummaryChanged() { toastRow.revive() }
            function onImageChanged()   { toastRow.revive() }
        }

        onClicked: {
            if (bodyText && bodyText.hoveredLink !== "") return
            toastRow.dismiss()
        }

        GridLayout {
            id: contentGrid
            anchors.fill: parent
            anchors.margins: 10
            columns: 2
            rowSpacing: 8
            columnSpacing: 10

            // [Row 0, Col 0] Media: big sent image with small app icon overlapping bottom-right
            Item {
                id: mediaItem
                Layout.row: 0
                Layout.column: 0
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop

                readonly property bool hasAppIcon: toastRow.notif && (toastRow.notif.appIcon !== "" || toastRow.notif.desktopEntry !== "")
                readonly property bool hasImage: toastRow.cachedImage !== ""
                readonly property int mainSize: hasImage ? 68 : 40
                readonly property int badgeSize: 26

                Layout.preferredWidth: mainSize + (hasImage ? 6 : 0)
                Layout.preferredHeight: mainSize + (hasImage ? 6 : 0)

                // Sent image (large, top-left corner)
                Item {
                    id: sentImageBox
                    visible: mediaItem.hasImage
                    x: 0
                    y: 0
                    width: mediaItem.mainSize
                    height: mediaItem.mainSize
                    readonly property real radius: Theme.cardButtonRadius

                    Image {
                        id: sentImageRaw
                        anchors.fill: parent
                        source: toastRow.cachedImage
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        cache: true
                        asynchronous: true
                        sourceSize.width: 160
                        sourceSize.height: 160
                        visible: false
                    }

                    Item {
                        id: sentImageMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        layer.smooth: true

                        Rectangle {
                            anchors.fill: parent
                            radius: sentImageBox.radius
                            color: "black"
                            antialiasing: true
                        }
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: sentImageRaw
                        maskEnabled: true
                        maskSource: sentImageMask
                        visible: sentImageRaw.status === Image.Ready
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (toastRow.cachedImage.startsWith("file://") || toastRow.cachedImage.startsWith("/")) {
                                Qt.openUrlExternally(toastRow.cachedImage)
                            } else {
                                toastRow.dismiss()
                            }
                        }
                    }
                }

                // App icon (small badge overlapping the image's bottom-right corner;
                // standalone and larger when there is no image)
                Item {
                    id: appIconBox
                    visible: mediaItem.hasAppIcon || !mediaItem.hasImage
                    width: mediaItem.hasImage ? mediaItem.badgeSize : mediaItem.mainSize
                    height: width
                    x: mediaItem.hasImage ? parent.width - width : 0
                    y: mediaItem.hasImage ? parent.height - height : 0

                    // soft backing so the badge separates from the image
                    Rectangle {
                        visible: mediaItem.hasImage
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(0.08, 0.06, 0.12, 0.92)
                    }

                    Image {
                        id: appIconImage
                        anchors.fill: parent
                        anchors.margins: mediaItem.hasImage ? 4 : 2
                        source: {
                            var icon = toastRow.notif ? toastRow.notif.appIcon : ""
                            if (icon !== "") {
                                if (icon.indexOf("/") !== -1 || icon.startsWith("file:")) return icon
                                return "image://icon/" + icon
                            }
                            var desktop = toastRow.notif ? toastRow.notif.desktopEntry : ""
                            if (desktop !== "") {
                                if (desktop.indexOf("/") !== -1 || desktop.startsWith("file:")) return desktop
                                return "image://icon/" + desktop
                            }
                            return ""
                        }
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        cache: true
                        sourceSize.width: 64
                        sourceSize.height: 64
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: appIconImage.status !== Image.Ready || appIconImage.source == ""
                        text: "󰂚"
                        font.family: Theme.font
                        font.pixelSize: mediaItem.hasImage ? 13 : 22
                        color: toastRow.textColor
                        opacity: 0.8
                    }
                }
            }

            // [Row 0, Col 1] Text Info
            ColumnLayout {
                Layout.row: 0
                Layout.column: 1
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                spacing: 5

                // Header: app name + time
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

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

                    Text {
                        id: timeText
                        text: Qt.formatDateTime(new Date(), "HH:mm")
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                        font.bold: true
                        color: toastRow.textColor
                        opacity: 0.6
                    }
                }

                // Summary
                Text {
                    visible: toastRow.notif && text !== ""
                    text: toastRow.notif ? toastRow.notif.summary : ""
                    textFormat: Text.StyledText
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
                    visible: toastRow.notif && text !== ""
                    text: (toastRow.notif && toastRow.notif.body) ? String(toastRow.notif.body).replace(/\n/g, "<br>") : ""
                    textFormat: Text.StyledText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    color: toastRow.textColor
                    linkColor: Theme.statusBlue
                    opacity: 0.85
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    elide: Text.ElideRight
                    maximumLineCount: 5
                    Layout.fillWidth: true

                    onLinkActivated: link => Qt.openUrlExternally(link)

                    HoverHandler {
                        cursorShape: (bodyText.hoveredLink !== "") ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }

                // Show More / Less
                ModuleButton {
                    variant: "neutral"
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
                            variant: "neutral"
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
