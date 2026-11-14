// notifCenter.qml — DBus notification server & notification center
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
    id: notifCenter

    // ── Geometry & State ────────────────────────────────────────────────
    readonly property int cardWidth: 350
    readonly property int maxCardHeight: 650

    // Gap between stacked items. Every item carries its own gap (scaled by how
    // much of it is shown) instead of using Column spacing, which would step
    // whenever an item flips visible/invisible. The last item's trailing gap is
    // removed by scaling with maxGroupFraction.
    readonly property int itemGap: 8
    readonly property real maxGroupFraction: {
        var maxF = 0
        for (var i = 0; i < groupRepeater.count; ++i) {
            var g = groupRepeater.itemAt(i)
            if (g && g.groupFraction > maxF) maxF = g.groupFraction
        }
        return maxF
    }
    readonly property real listHeight: Math.max(0, notifColumn.implicitHeight - itemGap * maxGroupFraction)

    property bool inlineReplyInputFocused: false
    property bool isManuallyOpen: false
    readonly property bool hasActiveToasts: SharedState.hasActiveToasts
    property string screenName: ""

    readonly property int totalCount: SharedState.notificationsModel.count
    readonly property int activeCount: Math.max(0, totalCount - Object.keys(SharedState.dismissingNotifs).length)

    // A new notification scrolls the list back to the top.
    Connections {
        target: SharedState.notificationsModel
        function onRowsInserted(parent, first, last) {
            if (first === 0) notifFlickable.contentY = 0
        }
    }

    // Hover management
    readonly property bool isHovered: (cornerHoverHandler && cornerHoverHandler.hovered) || (containerRect && containerRect.isHovered === true)
    readonly property bool showAllNotifications: isHovered || isManuallyOpen || inlineReplyInputFocused
    readonly property bool isCardOpen: showAllNotifications || hasActiveToasts

    onIsCardOpenChanged: {
        if (!isCardOpen) {
            card.volExpanded = false
            notifFlickable.contentY = 0
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
            notifCenter.isManuallyOpen = !notifCenter.isManuallyOpen
        }
        function open(): void {
            notifCenter.isManuallyOpen = true
        }
        function close(): void {
            notifCenter.isManuallyOpen = false
        }
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
            expandingH: notifCenter.isCardOpen || containerRect.implicitHeight > 1
            expandingV: notifCenter.isCardOpen || containerRect.implicitHeight > 1
            animated: false
        }

        // [Row 1, Col 1] Main Notification Container
        Rectangle {
            id: containerRect
            Layout.row: 1
            Layout.column: 1
            Layout.alignment: Qt.AlignRight | Qt.AlignBottom
            Layout.maximumHeight: notifCenter.maxCardHeight + 50

            color: Qt.rgba(Theme.dark.base.r, Theme.dark.base.g, Theme.dark.base.b, Theme.moduleOpacity)
            clip: true
            topLeftRadius: Theme.moduleEdgeRadius + 10

            // The container has no height animation of its own: it simply follows
            // its content (toast heights) plus this chrome (paddings + header),
            // which are the only things animating. One animation source keeps
            // opening, closing and group expansion in a single smooth motion.
            property real chromeHeight: !notifCenter.isCardOpen ? 0
                : (notifCenter.showAllNotifications ? Theme.cardHeaderHeight + 40 : 20)
            property real emptyHeight: (notifCenter.showAllNotifications && notifCenter.activeCount === 0) ? emptyState.implicitHeight : 0

            implicitWidth: notifCenter.isCardOpen ? (notifCenter.showAllNotifications ? (notifCenter.cardWidth + 20) : notifCenter.cardWidth) : Theme.moduleEdgeRadius
            implicitHeight: Math.min(notifCenter.maxCardHeight, chromeHeight + emptyHeight + notifCenter.listHeight)

            Behavior on implicitWidth { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutQuint } }
            Behavior on chromeHeight { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutQuint } }
            Behavior on emptyHeight { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutQuint } }

            property bool isHovered: (containerHoverHandler ? containerHoverHandler.hovered : false) || (cardHoverHandler ? cardHoverHandler.hovered : false)

            HoverHandler {
                id: containerHoverHandler
                onHoveredChanged: {
                    if (!containerHoverHandler.hovered && !cornerHoverHandler.hovered) {
                        notifCenter.inlineReplyInputFocused = false
                    }
                }
            }

            // ── The Unified Card Inside Base Container ──────────────────
            BaseCard {
                id: card
                anchors.fill: parent
                anchors.margins: 10

                // Keep the card chrome/background visible while closing so notifications
                // don't jump up when unhovering.
                property bool showCenterChrome: notifCenter.showAllNotifications
                Connections {
                    target: notifCenter
                    function onShowAllNotificationsChanged() {
                        if (notifCenter.showAllNotifications) {
                            card.showCenterChrome = true
                        } else if (notifCenter.hasActiveToasts) {
                            card.showCenterChrome = false
                        }
                    }
                    function onHasActiveToastsChanged() {
                        if (!notifCenter.showAllNotifications && notifCenter.hasActiveToasts) {
                            card.showCenterChrome = false
                        }
                    }
                }
                onVisibleChanged: {
                    if (!visible && !notifCenter.showAllNotifications) {
                        showCenterChrome = false
                    }
                }

                color: showCenterChrome ? Theme.bgBlurColor : "transparent"
                border.width: showCenterChrome ? Theme.cardBorderWidth : 0
                border.color: showCenterChrome ? Theme.cardBorder : "transparent"
                shadowEnabled: false

                opacity: notifCenter.isCardOpen ? 1.0 : 0.0
                visible: opacity > 0

                HoverHandler {
                    id: cardHoverHandler
                }

                Behavior on opacity { NumberAnimation { duration: Theme.verticalDuration / 2; easing.type: Easing.OutCubic } }

                hasHeader: showCenterChrome
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
                    height: notifCenter.showAllNotifications ? 10 : 0
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
                    width: notifCenter.cardWidth - 20
                    anchors.bottomMargin: card.showCenterChrome ? 10 : 0
                    anchors.topMargin: card.showCenterChrome ? 10 : 0

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: card.showCenterChrome
                        maskSource: contentMask
                    }

                    // ── Empty State ─────────────────────────────────────
                    Item {
                        id: emptyState
                        opacity: (notifCenter.showAllNotifications && notifCenter.activeCount === 0) ? 1.0 : 0.0
                        visible: opacity > 0
                        anchors.fill: parent
                        implicitHeight: 110

                        Behavior on opacity { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

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
                        visible: notifCenter.totalCount > 0
                        anchors.fill: parent
                        clip: false
                        contentWidth: width
                        contentHeight: notifCenter.listHeight
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: notifCenter.showAllNotifications

                        Column {
                            id: notifColumn
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: notifCenter.cardWidth - 20
                            spacing: 0
                            topPadding: 0
                            bottomPadding: 0

                            Repeater {
                                id: groupRepeater
                                model: SharedState.groupsModel
                                delegate: NotificationGroup {
                                    width: notifColumn.width
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
            onClicked: notifCenter.isManuallyOpen = !notifCenter.isManuallyOpen
        }
    }

    // ── Single Notification Toast Component ─────────────────────────────
    component NotificationToast: ModuleButton {
        id: toastRow

        property var notif: null
        property int notifIndex: 0
        property var group: null

        readonly property bool isToastActive: SharedState.isToastActive(toastRow.notif)
        readonly property bool isDismissing: SharedState.isNotificationDismissing(toastRow.notif)
        property string cachedImage: (notif && notif.image) ? notif.image : ""

        readonly property bool hasInlineReply: notif && notif.hasInlineReply
        readonly property bool isCritical: notif && notif.urgency === Notif.NotificationUrgency.Critical
        readonly property int effectiveTimeout: SharedState.getToastTimeout(toastRow.notif)

        variant: isCritical ? "red" : "neutral"
        radius: group ? Math.max(0, group.cardRadius - 5) : ((!notifCenter.showAllNotifications ? Theme.cardRadius : Theme.cardItemRadius) - 5)
        border.width: 0
        clip: true

        readonly property bool isNewest: group ? (group.firstActiveNotif === toastRow.notif) : (notifIndex === 0)
        readonly property bool inGroupView: group ? (group.expanded || !group.grouped || isNewest) : true
        readonly property bool shouldBeVisible: !isDismissing && (notifCenter.showAllNotifications ? inGroupView : isToastActive)

        readonly property int minCol0Height: (cachedImage !== "" ? 74 : 40)
        implicitHeight: Math.max(contentGrid.implicitHeight + 20, minCol0Height + 20)

        // 0..1: how much of the toast is currently shown
        readonly property real shownFraction: implicitHeight > 0 ? Math.min(1, height / implicitHeight) : 0

        // Toasts start collapsed so that new ones grow in instead of popping in.
        property bool ready: false
        Component.onCompleted: Qt.callLater(() => toastRow.ready = true)

        // The toast height is the animation source for the whole card: the group,
        // the list and the container all just follow it.
        height: (shouldBeVisible && ready) ? implicitHeight : 0
        visible: height > 0
        opacity: (shouldBeVisible && ready) ? 1.0 : 0.0

        Behavior on height { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: Theme.verticalDuration / 2; easing.type: Easing.OutCubic } }

        onHoveredChanged: {
            if (toastRow.hovered && toastRow.isToastActive) {
                SharedState.dismissActiveToast(toastRow.notif)
            }
        }

        function dismiss() {
            SharedState.dismissNotification(toastRow.notif)
        }

        function submitInlineReply() {
            if (!toastRow.notif || !toastRow.hasInlineReply) return
            var replyText = replyInput.text.trim()
            if (replyText.length === 0) return
            toastRow.notif.sendInlineReply(replyText)
            replyInput.text = ""
            SharedState.dismissNotification(toastRow.notif)
        }

        function revive() {
            if (toastRow.notif && toastRow.notif.image !== "")
                toastRow.cachedImage = toastRow.notif.image
            timeText.text = Qt.formatDateTime(new Date(), "HH:mm")
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

        // Time, locked to the top-right corner of the toast
        Text {
            id: timeText
            z: 1
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 15
            anchors.rightMargin: 20
            text: Qt.formatDateTime(new Date(), "HH:mm")
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 3
            font.bold: true
            color: toastRow.textColor
            opacity: 0.6
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

            // [Row 0, Col 1] Title (summary), centered next to the image
            ColumnLayout {
                Layout.row: 0
                Layout.column: 1
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                spacing: 3

                // Summary
                Text {
                    visible: toastRow.notif && text !== ""
                    text: toastRow.notif ? toastRow.notif.summary : ""
                    textFormat: Text.StyledText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 2
                    font.bold: true
                    color: toastRow.textColor
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    Layout.fillWidth: true
                    Layout.rightMargin: 40
                }
            }

            // [Row 1] Body: spans full width so it flows under the image
            ColumnLayout {
                Layout.row: 1
                Layout.column: 0
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                spacing: 5

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
                Layout.row: 2
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
                Layout.row: 3
                Layout.column: 0
                Layout.columnSpan: 2
                Layout.fillWidth: true
                visible: toastRow.hasInlineReply
                implicitHeight: 28

                variant: "neutral"
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
                    color: Theme.palette("neutral").text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    clip: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: (toastRow.notif && toastRow.notif.inlineReplyPlaceholder !== "")
                                ? toastRow.notif.inlineReplyPlaceholder
                                : "Reply..."
                        color: Theme.palette("neutral").text
                        opacity: 0.7
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        visible: !replyInput.text.length
                    }

                    Keys.onReturnPressed: {
                        notifCenter.inlineReplyInputFocused = false
                        toastRow.submitInlineReply()
                    }
                    onActiveFocusChanged: {
                        notifCenter.inlineReplyInputFocused = activeFocus
                    }
                }
            }

            // [Row 4] Timer Progress Bar
            Rectangle {
                id: notifTimer
                Layout.row: 4
                Layout.column: 0
                Layout.columnSpan: 2
                Layout.fillWidth: true
                visible: toastRow.isToastActive && toastRow.effectiveTimeout > 0
                height: 3
                radius: 1.5
                color: Theme.palettePaper
                opacity: 0.4

                property real progress: 1.0
                width: contentGrid.width * progress
                NumberAnimation on progress {
                    from: 1.0
                    to: 0.0
                    duration: toastRow.effectiveTimeout
                    running: toastRow.isToastActive && toastRow.effectiveTimeout > 0
                }
            }
        }
    }

    // ── App Group (header + stacked/expanded notifications) ─────────────
    // Height = header slot + toast column + peek slot. All three are animated
    // (toast heights by the toasts themselves), so expanding/collapsing a group
    // is one motion that the list and the container simply follow.
    component NotificationGroup: Item {
        id: grp

        required property string appName
        readonly property bool expanded: SharedState.isGroupExpanded(grp.appName)

        // This app's notifications, newest first (kept in sync with the shared list)
        ListModel { id: appNotifsModel }
        property var newest: null

        function syncAppNotifs() {
            var list = SharedState.notificationsOf(grp.appName)
            SharedState.syncModel(appNotifsModel, "notifData", list)
            grp.newest = list.length > 0 ? list[0] : null
        }

        Component.onCompleted: syncAppNotifs()

        Connections {
            target: SharedState
            function onNotificationListChanged() { grp.syncAppNotifs() }
        }

        function dismissGroup() {
            SharedState.dismissGroup(grp.appName)
        }

        readonly property int count: appNotifsModel.count
        readonly property var firstActiveNotif: {
            var _ = SharedState.dismissingNotifs
            for (var i = 0; i < appNotifsModel.count; ++i) {
                var d = appNotifsModel.get(i).notifData
                if (d && !SharedState.isNotificationDismissing(d)) return d
            }
            return null
        }
        readonly property int activeGroupCount: {
            var c = 0
            var _ = SharedState.dismissingNotifs
            for (var i = 0; i < appNotifsModel.count; ++i) {
                var d = appNotifsModel.get(i).notifData
                if (d && !SharedState.isNotificationDismissing(d)) c++
            }
            return c
        }
        readonly property int displayCount: activeGroupCount > 0 ? activeGroupCount : count
        readonly property bool grouped: displayCount > 1
        readonly property int headerHeight: 34
        readonly property int peekHeight: 10
        readonly property int toastGap: 5
        readonly property var pal: Theme.palette("neutral")
        readonly property alias cardRadius: groupCard.radius

        // 0..1: how much of this group is currently shown (driven by its active/visible toasts)
        readonly property real groupFraction: {
            var maxF = 0
            for (var i = 0; i < toastsRepeater.count; ++i) {
                var item = toastsRepeater.itemAt(i)
                if (item && item.toastFraction > maxF) maxF = item.toastFraction
            }
            return maxF
        }

        readonly property real headerSlot: (headerHeight + 5) * groupFraction
        property real peekBase: (notifCenter.showAllNotifications && grouped && !expanded) ? peekHeight : 0
        Behavior on peekBase { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutQuint } }
        readonly property real peekSlot: peekBase * groupFraction
        readonly property real cardBottomPad: 5 * groupFraction
        readonly property real toastMargin: 5

        readonly property real toastsHeight: Math.max(0, toastsCol.implicitHeight - toastGap * groupFraction)
        readonly property real bodyHeight: headerSlot + toastsHeight + peekSlot + cardBottomPad
        // body plus this group's own scaled gap (see notifCenter.itemGap)
        height: bodyHeight + notifCenter.itemGap * groupFraction
        visible: height > 0
        clip: true

        // ── Group Card (envelops header + notifications) ────────────
        Rectangle {
            id: groupCard
            width: parent.width
            height: grp.bodyHeight
            y: 0
            visible: grp.groupFraction > 0
            opacity: grp.groupFraction
            radius: !notifCenter.showAllNotifications ? Theme.cardRadius : Theme.cardItemRadius
            Behavior on radius { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic } }
            color: Qt.lighter(Theme.paletteInk, 1.5)
            border.width: 0
        }

        // ── Group Header (existing buttons) ─────────────────────────
        Item {
            id: groupHeader
            width: parent.width
            height: grp.headerHeight
            y: grp.headerSlot - (grp.headerHeight + 5)
            visible: grp.groupFraction > 0
            opacity: grp.groupFraction

            MouseArea {
                anchors.fill: parent
                enabled: grp.grouped
                cursorShape: grp.grouped ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: SharedState.toggleGroupExpanded(grp.appName)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 4
                spacing: 8

                Image {
                    id: groupIcon
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    Layout.alignment: Qt.AlignVCenter
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    sourceSize.width: 32
                    sourceSize.height: 32
                    visible: status === Image.Ready
                    source: {
                        var n = grp.newest
                        if (!n) return ""
                        var icon = n.appIcon !== "" ? n.appIcon : n.desktopEntry
                        if (!icon) return ""
                        if (icon.indexOf("/") !== -1 || icon.startsWith("file:")) return icon
                        return "image://icon/" + icon
                    }
                }

                Text {
                    visible: !groupIcon.visible
                    text: "󰂚"
                    color: Theme.textPrimary
                    opacity: 0.8
                    font.family: Theme.font
                    font.pixelSize: 15
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: grp.appName
                    color: Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                // Count badge
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 18
                    Layout.preferredWidth: Math.max(18, badgeText.implicitWidth + 10)
                    radius: height / 2
                    color: Theme.palettePaper

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: grp.displayCount
                        color: Theme.paletteInk
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                        font.bold: true
                    }
                }

                HeaderButton {
                    icon: "󰆴"
                    iconColor: Theme.textPrimary
                    iconSize: 15
                    implicitHeight: 24
                    implicitWidth: 24
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: grp.dismissGroup()
                }

                HeaderButton {
                    visible: grp.grouped
                    icon: grp.expanded ? "󰅃" : "󰅀"
                    iconColor: Theme.textPrimary
                    iconSize: 17
                    implicitHeight: 24
                    implicitWidth: 24
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: SharedState.toggleGroupExpanded(grp.appName)
                }
            }
        }

        // ── Group Content Area ──────────────────────────────────────
        Item {
            id: groupContent
            y: grp.headerSlot
            width: parent.width
            height: grp.toastsHeight + grp.peekSlot + grp.cardBottomPad

            // ── Stack Peek (shown when collapsed) ───────────────────
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: grp.toastsHeight + 2
                width: parent.width - 20
                height: 6
                radius: Theme.cardItemRadius
                color: Qt.rgba(Theme.neutral.base.r, Theme.neutral.base.g, Theme.neutral.base.b, Theme.moduleOpacity * 0.25)
                border.width: 0
                visible: grp.peekSlot > 0
                opacity: grp.peekSlot / grp.peekHeight

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SharedState.setGroupExpanded(grp.appName, true)
                }
            }

            // ── Cards Column ────────────────────────────────────────
            Column {
                id: toastsCol
                anchors.left: parent.left
                anchors.leftMargin: grp.toastMargin
                anchors.right: parent.right
                anchors.rightMargin: grp.toastMargin
                spacing: 0

                Repeater {
                    id: toastsRepeater
                    model: appNotifsModel
                    // The 5px gap below each toast scales with the toast's own
                    // height, so lists grow/shrink without any hard layout steps.
                    delegate: Item {
                        id: slot
                        required property var notifData
                        required property int index
                        readonly property alias toastFraction: toast.shownFraction

                        width: toastsCol.width
                        height: toast.height + grp.toastGap * toast.shownFraction

                        NotificationToast {
                            id: toast
                            width: parent.width
                            notif: slot.notifData
                            notifIndex: slot.index
                            group: grp
                        }
                    }
                }
            }
        }
    }
}
