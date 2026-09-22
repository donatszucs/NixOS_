// Clock module — Expandable calendar with Google Calendar integration
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

import "../elements"

ExpandableModule {
    id: root

    // ── Time State (collapsed view) ──────────────────────────────
    property string hours: ""
    property string minutes: ""
    property string seconds: ""
    property string date: ""

    function updateTime() {
        var now = new Date()
        hours = Qt.formatDateTime(now, "HH")
        minutes = Qt.formatDateTime(now, "mm")
        seconds = Qt.formatDateTime(now, "ss")
        date = Qt.formatDateTime(now, "MMM d")

        var todayFormatted = formatDateStr(now.getFullYear(), now.getMonth() + 1, now.getDate())
        if (root.todayDate !== todayFormatted) {
            root.todayDate = todayFormatted
            if (!root.selectedDate || root.selectedDate === "") {
                root.selectedDate = todayFormatted
            }
            updateCalendarGrid()
        }
    }

    // ── Calendar View State ──────────────────────────────────────
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth() // 0-indexed: 0 = Jan, 8 = Sep
    property string todayDate: formatDateStr(new Date().getFullYear(), new Date().getMonth() + 1, new Date().getDate())
    property string selectedDate: todayDate
    property var calendarDays: []

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var monthNamesShort: [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]
    readonly property var dayNamesShort: [
        "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"
    ]

    readonly property string viewMonthName: monthNames[viewMonth]

    // Google Calendar State (backed by SharedState)
    readonly property var eventsByDate: SharedState.calendarEventsByDate
    readonly property var eventColorsByDate: SharedState.calendarEventColorsByDate
    readonly property var calendars: SharedState.calendars
    readonly property var upcomingEvents: SharedState.calendarUpcomingEvents
    readonly property bool hasCalendarUrl: SharedState.hasCalendarUrl
    readonly property bool isUpdating: SharedState.calendarUpdating
    property var selectedEvents: (eventsByDate && eventsByDate[selectedDate]) ? eventsByDate[selectedDate] : []

    onEventsByDateChanged: {
        root.selectedEvents = (root.eventsByDate && root.eventsByDate[root.selectedDate]) ? root.eventsByDate[root.selectedDate] : []
    }

    property int cardWidth: 340
    implicitHeight: expanded ? baseColumn.implicitHeight + Theme.moduleHeight + root.titleBarHeight + 15 : Theme.moduleHeight

    expandedDropdownWidth: cardWidth + 30
    dropdownAlignment: "left"

    collapsedWidth: clockContent.implicitWidth + 20

    pillPercent: expanded ? 100 : 0
    pillVariant: "neutral"
    expandedPillLabel: "Calendar"
    titleIcon: "󰸗"
    expandedBottomLeftRadius: 0
    bottomLeftRadius: 0

    leftCornerStyle: "bottom"
    rightCornerStyle: "side"

    // ── Helper Functions ─────────────────────────────────────────
    function formatDateStr(y, m, d) {
        var mm = m < 10 ? "0" + m : "" + m
        var dd = d < 10 ? "0" + d : "" + d
        return y + "-" + mm + "-" + dd
    }

    function formatFriendlyDate(dateStr) {
        if (!dateStr) return ""
        var parts = dateStr.split("-")
        if (parts.length < 3) return dateStr
        var d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]))
        var days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        if (dateStr === root.todayDate) {
            return "Today, " + d.getDate() + " " + monthNamesShort[d.getMonth()]
        }
        return days[d.getDay()] + ", " + d.getDate() + " " + monthNamesShort[d.getMonth()]
    }

    function formatSpan(startStr, endStr) {
        if (!startStr || !endStr || startStr === endStr) return ""
        var sParts = startStr.split("-")
        var eParts = endStr.split("-")
        if (sParts.length < 3 || eParts.length < 3) return startStr + " - " + endStr
        var sDate = new Date(parseInt(sParts[0]), parseInt(sParts[1]) - 1, parseInt(sParts[2]))
        var eDate = new Date(parseInt(eParts[0]), parseInt(eParts[1]) - 1, parseInt(eParts[2]))
        if (sParts[0] === eParts[0] && sParts[1] === eParts[1]) {
            return monthNamesShort[sDate.getMonth()] + " " + sDate.getDate() + " - " + eDate.getDate()
        } else if (sParts[0] === eParts[0]) {
            return monthNamesShort[sDate.getMonth()] + " " + sDate.getDate() + " - " + monthNamesShort[eDate.getMonth()] + " " + eDate.getDate()
        } else {
            return sParts[0] + " " + monthNamesShort[sDate.getMonth()] + " " + sDate.getDate() + " - " + eParts[0] + " " + monthNamesShort[eDate.getMonth()] + " " + eDate.getDate()
        }
    }

    function updateCalendarGrid() {
        var days = []
        var firstDayOfMonth = new Date(viewYear, viewMonth, 1)
        var daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate()

        // Day of week for 1st day (0 is Sunday, convert to Monday = 0)
        var startDayIndex = (firstDayOfMonth.getDay() + 6) % 7

        var daysInPrevMonth = new Date(viewYear, viewMonth, 0).getDate()
        var prevMonthYear = (viewMonth === 0) ? viewYear - 1 : viewYear
        var prevMonth = (viewMonth === 0) ? 11 : viewMonth - 1

        // Previous month overflow
        for (var p = startDayIndex - 1; p >= 0; p--) {
            var pDay = daysInPrevMonth - p
            var pDateStr = formatDateStr(prevMonthYear, prevMonth + 1, pDay)
            days.push({
                dayNumber: pDay,
                dateString: pDateStr,
                isCurrentMonth: false,
                month: prevMonth,
                year: prevMonthYear
            })
        }

        // Current month days
        for (var d = 1; d <= daysInMonth; d++) {
            var cDateStr = formatDateStr(viewYear, viewMonth + 1, d)
            days.push({
                dayNumber: d,
                dateString: cDateStr,
                isCurrentMonth: true,
                month: viewMonth,
                year: viewYear
            })
        }

        // Next month overflow to complete 42 cells (6 full weeks)
        var nextMonthYear = (viewMonth === 11) ? viewYear + 1 : viewYear
        var nextMonth = (viewMonth === 11) ? 0 : viewMonth + 1
        var nextDay = 1
        while (days.length < 42) {
            var nDateStr = formatDateStr(nextMonthYear, nextMonth + 1, nextDay)
            days.push({
                dayNumber: nextDay,
                dateString: nDateStr,
                isCurrentMonth: false,
                month: nextMonth,
                year: nextMonthYear
            })
            nextDay++
        }

        calendarDays = days
    }

    function prevMonth() {
        if (viewMonth === 0) {
            viewYear--
            viewMonth = 11
        } else {
            viewMonth--
        }
        updateCalendarGrid()
    }

    function nextMonth() {
        if (viewMonth === 11) {
            viewYear++
            viewMonth = 0
        } else {
            viewMonth++
        }
        updateCalendarGrid()
    }

    function goToToday() {
        var now = new Date()
        viewYear = now.getFullYear()
        viewMonth = now.getMonth()
        selectedDate = formatDateStr(viewYear, viewMonth + 1, now.getDate())
        updateCalendarGrid()
    }

    function fetchCalendar() {
        SharedState.fetchCalendar()
    }

    onSelectedDateChanged: {
        root.selectedEvents = (root.eventsByDate && root.eventsByDate[root.selectedDate]) ? root.eventsByDate[root.selectedDate] : []
    }

    // ── Collapsed Content inside headerPill ──────────────────────
    RowLayout {
        id: clockContent
        parent: root.headerPill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: Math.round(Theme.moduleHeight / 2)
        spacing: 10
        z: 6
        visible: opacity > 0
        opacity: root.expanded ? 0.0 : 1.0

        Behavior on opacity {
            NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
        }

        RowLayout {
            spacing: 0

            Item {
                width: 10
            }

            Text {
                text: root.hours
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }

            Text {
                text: ":"
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }

            Text {
                text: root.minutes
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }

            Text {
                text: ":"
                color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, Theme.textPrimary.a * 0.5)
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }

            Text {
                text: root.seconds
                color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, Theme.textPrimary.a * 0.5)
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }
        }

        Rectangle {
            color: Qt.rgba(Theme.neutral.base.r, Theme.neutral.base.g, Theme.neutral.base.b, Theme.neutral.base.a * 0.6)
            radius: (Theme.moduleHeight - 10) / 2
            implicitWidth: 60
            implicitHeight: Theme.moduleHeight - 14

            Layout.rightMargin: -5

            Text {
                anchors.centerIn: parent
                text: root.date
                color: Theme.paletteInk
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
                font.bold: false
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // ── Expanded Content (Calendar Dropdown) ─────────────────────
    ColumnLayout {
        id: baseColumn
        parent: root.overlay
        anchors {
            top: parent.top
            topMargin: root.titleBarHeight
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 10

        visible: opacity > 0
        opacity: root.expanded ? 1.0 : 0.0

        scale: expanded ? 1 : 0
        transformOrigin: Item.Top
        Behavior on scale { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

        Behavior on opacity {
            NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
        }

        // ── Card 1: Month Calendar ───────────────────────────────
        Rectangle {
            id: calendarCard
            implicitWidth: root.cardWidth
            Layout.preferredWidth: root.cardWidth
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: calTopBar.height + calGridContent.implicitHeight + 16
            radius: Theme.moduleEdgeRadius / 2 + 10
            color: Theme.bgBlurColor
            border.width: 2
            border.color: Theme.cardBorder
            clip: true

            // Top Header Bar
            Rectangle {
                id: calTopBar
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 35
                color: Theme.topBarBlurColor
                topLeftRadius: parent.radius
                topRightRadius: parent.radius
                bottomLeftRadius: 0
                bottomRightRadius: 0

                // Prev Month Button
                ModuleButton {
                    id: prevBtn
                    width: 26
                    height: 20
                    radius: 13
                    topRightRadius: 0
                    bottomRightRadius: 0
                    anchors {
                        left: parent.left
                        leftMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    variant: "neutral"
                    label: "󰅁"
                    onClicked: root.prevMonth()
                    cursorShape: Qt.PointingHandCursor
                }
                
                // Next Month Button
                ModuleButton {
                    id: nextBtn
                    width: 26
                    height: 20
                    radius: 13
                    topLeftRadius: 0
                    bottomLeftRadius: 0
                    anchors {
                        left: prevBtn.right
                        verticalCenter: parent.verticalCenter
                    }

                    variant: "neutral"
                    label: "󰅂"
                    onClicked: root.nextMonth()
                    cursorShape: Qt.PointingHandCursor
                }

                // Month & Year Title
                Text {
                    id: monthTitleText
                    anchors {
                        left: nextBtn.right
                        leftMargin: 6
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.viewMonthName + " " + root.viewYear
                    color: Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                // Right action buttons (Today, Refresh, Google Calendar Web)
                RowLayout {
                    anchors {
                        right: parent.right
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 5

                    // "Today" button
                    Rectangle {
                        implicitHeight: 22
                        implicitWidth: todayBtnText.implicitWidth + 12
                        radius: Theme.moduleEdgeRadius / 2
                        color: todayHover.hovered ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.25) : Qt.rgba(1, 1, 1, 0.1)
                        border.width: 1
                        border.color: todayHover.hovered ? Theme.statusBlue : Theme.divider
                        HoverHandler { id: todayHover }

                        Text {
                            id: todayBtnText
                            anchors.centerIn: parent
                            text: "Today"
                            color: todayHover.hovered ? Theme.statusBlue : Theme.textPrimary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize * 0.75
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.goToToday()
                        }
                    }

                    // Refresh Feed Button
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: refreshHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                        HoverHandler { id: refreshHover }

                        Text {
                            id: refreshIconText
                            anchors.centerIn: parent
                            text: "󰑐"
                            color: root.isUpdating ? Theme.statusBlue : (refreshHover.hovered ? Theme.statusBlue : Theme.textPrimary)
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize

                            RotationAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                                running: root.isUpdating
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.fetchCalendar()
                        }
                    }

                    // Google Calendar web shortcut
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: webHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                        HoverHandler { id: webHover }

                        Text {
                            anchors.centerIn: parent
                            text: "󰃭"
                            color: webHover.hovered ? Theme.statusBlue : Theme.textPrimary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize + 1
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calendarProc.running = true
                        }
                    }
                }
            }

            InverseRadius {
                anchors.top: calTopBar.bottom
                anchors.left: calTopBar.left
                color: calTopBar.color
            }

            InverseRadius {
                cornerPosition: "topRight"
                anchors.top: calTopBar.bottom
                anchors.right: calTopBar.right
                color: calTopBar.color
            }

            // Calendar Grid Content
            ColumnLayout {
                id: calGridContent
                anchors {
                    top: calTopBar.bottom
                    left: parent.left
                    right: parent.right
                    margins: 10
                }
                spacing: 5

                // Calendar Legend (showing active calendars and their colors)
                Flow {
                    Layout.fillWidth: true
                    visible: Boolean(root.calendars && root.calendars.length > 1)
                    spacing: 8
                    Layout.bottomMargin: 2

                    Repeater {
                        model: root.calendars
                        delegate: RowLayout {
                            spacing: 4
                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: modelData.color
                            }
                            Text {
                                text: modelData.name
                                color: Theme.textPrimary
                                opacity: 0.65
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize * 0.7
                                font.bold: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Weekday Headers (Mo Tu We Th Fr Sa Su)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: root.dayNamesShort
                        delegate: Item {
                            Layout.fillWidth: true
                            implicitHeight: 20

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: Theme.textPrimary
                                opacity: 0.5
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize * 0.75
                                font.bold: true
                            }
                        }
                    }
                }

                // 42-day Month Grid
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 2
                    rowSpacing: 2

                    Repeater {
                        model: root.calendarDays
                        delegate: Rectangle {
                            id: dayCell
                            required property var modelData

                            readonly property bool isToday: Boolean(modelData && modelData.dateString && (modelData.dateString === root.todayDate))
                            readonly property bool isSelected: Boolean(modelData && modelData.dateString && (modelData.dateString === root.selectedDate))
                            readonly property bool isCurrentMonth: Boolean(modelData && modelData.isCurrentMonth)
                            readonly property var dayColors: (root.eventColorsByDate && root.eventColorsByDate[modelData.dateString]) ? root.eventColorsByDate[modelData.dateString] : []
                            readonly property bool hasEvents: dayColors.length > 0

                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: 6

                            color: isToday 
                                ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.28) 
                                : (isSelected 
                                    ? Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.15) 
                                    : (cellHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"))

                            border.width: isToday ? 1.5 : (isSelected ? 1 : 0)
                            border.color: isToday ? Theme.statusBlue : (isSelected ? Qt.rgba(1, 1, 1, 0.3) : "transparent")

                            HoverHandler { id: cellHover }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 1

                                Text {
                                    text: modelData.dayNumber
                                    color: isToday 
                                        ? Theme.statusBlue 
                                        : (isCurrentMonth ? Theme.textPrimary : Theme.statusDisabled)
                                    opacity: isCurrentMonth ? 1.0 : 0.35
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize * 0.85
                                    font.bold: isToday || isSelected
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                // Colored dot indicators for days with events
                                RowLayout {
                                    spacing: 2
                                    visible: dayCell.hasEvents
                                    Layout.alignment: Qt.AlignHCenter

                                    Repeater {
                                        model: dayCell.dayColors.slice(0, 4)
                                        delegate: Rectangle {
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: modelData
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedDate = modelData.dateString
                                    if (!modelData.isCurrentMonth) {
                                        root.viewYear = modelData.year
                                        root.viewMonth = modelData.month
                                        root.updateCalendarGrid()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Card 2: Selected Day Agenda & Events ─────────────────
        Rectangle {
            id: agendaCard
            implicitWidth: root.cardWidth
            Layout.preferredWidth: root.cardWidth
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: agendaContentCol.implicitHeight + 20
            radius: Theme.moduleEdgeRadius / 2 + 10
            color: Theme.bgBlurColor
            border.width: 2
            border.color: Theme.cardBorder
            clip: true

            ColumnLayout {
                id: agendaContentCol
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 10
                }
                spacing: 10

                // Selected Date Header
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.formatFriendlyDate(root.selectedDate)
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        implicitHeight: 18
                        implicitWidth: eventCountText.implicitWidth + 10
                        radius: 9
                        color: Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.2)
                        visible: root.selectedEvents && root.selectedEvents.length > 0

                        Text {
                            id: eventCountText
                            anchors.centerIn: parent
                            text: (root.selectedEvents ? root.selectedEvents.length : 0) + " events"
                            color: Theme.statusBlue
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize * 0.7
                            font.bold: true
                        }
                    }
                }

                // Events List
                Repeater {
                    model: root.selectedEvents
                    delegate: Rectangle {
                        id: eventItem
                        required property var modelData

                        readonly property color eventColor: (modelData && modelData.calendar_color) ? modelData.calendar_color : Theme.statusBlue

                        Layout.fillWidth: true
                        implicitHeight: eventItemRow.implicitHeight + 15
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: eventItemHover.hovered ? Qt.rgba(eventColor.r, eventColor.g, eventColor.b, 0.4) : Theme.divider

                        HoverHandler { id: eventItemHover }

                        RowLayout {
                            id: eventItemRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 6
                            }
                            spacing: 8

                            // Color strip
                            Rectangle {
                                width: 3
                                Layout.fillHeight: true
                                radius: 1.5
                                color: eventItem.eventColor
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Rectangle {
                                        implicitHeight: 16
                                        implicitWidth: timeBadgeText.implicitWidth + 8
                                        radius: 4
                                        color: Qt.rgba(eventItem.eventColor.r, eventItem.eventColor.g, eventItem.eventColor.b, 0.18)

                                        Text {
                                            id: timeBadgeText
                                            anchors.centerIn: parent
                                            text: modelData.time_display ? modelData.time_display : (modelData.is_all_day ? "All Day" : (modelData.start_time + (modelData.end_time ? " - " + modelData.end_time : "")))
                                            color: eventItem.eventColor
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize * 0.7
                                            font.bold: true
                                        }
                                    }

                                    HoverMarqueeText {
                                        text: modelData.title || "(No title)"
                                        textMaxWidth: root.cardWidth - 110
                                        Layout.fillWidth: true
                                    }
                                }

                                RowLayout {
                                    visible: Boolean(modelData.is_multi_day && modelData.start_date && modelData.end_date && modelData.start_date !== modelData.end_date)
                                    spacing: 4

                                    Text {
                                        text: "󰸗"
                                        color: eventItem.eventColor
                                        opacity: 0.8
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize * 0.75
                                    }

                                    Text {
                                        text: root.formatSpan(modelData.start_date, modelData.end_date)
                                        color: eventItem.eventColor
                                        opacity: 0.85
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize * 0.75
                                        font.bold: true
                                    }
                                }

                                RowLayout {
                                    visible: modelData.location && modelData.location.length > 0
                                    spacing: 4

                                    Text {
                                        text: "󰍎"
                                        color: Theme.textPrimary
                                        opacity: 0.6
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize * 0.75
                                    }

                                    Text {
                                        text: modelData.location || ""
                                        color: Theme.textPrimary
                                        opacity: 0.7
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize * 0.75
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty state when calendar URL configured but no events today
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    visible: root.hasCalendarUrl && (!root.selectedEvents || root.selectedEvents.length === 0)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "󰃭"
                            color: Theme.textPrimary
                            opacity: 0.4
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize + 2
                        }

                        Text {
                            text: "No events scheduled for this day"
                            color: Theme.textPrimary
                            opacity: 0.6
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize * 0.85
                            font.italic: true
                        }
                    }
                }

                // Setup state when no Google Calendar URL configured
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: setupCol.implicitHeight + 16
                    radius: 8
                    color: Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.25)
                    visible: !root.hasCalendarUrl

                    ColumnLayout {
                        id: setupCol
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 10
                        }
                        spacing: 6

                        RowLayout {
                            spacing: 8
                            Text {
                                text: "󰃭"
                                color: Theme.statusBlue
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize + 2
                            }
                            Text {
                                text: "Sync Google Calendar"
                                color: Theme.textPrimary
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize * 0.9
                                font.bold: true
                            }
                        }

                        Text {
                            text: "Paste your Secret iCal URL into:\n~/.config/quickshell/calendar_url.txt"
                            color: Theme.textPrimary
                            opacity: 0.7
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize * 0.75
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            implicitHeight: 22
                            implicitWidth: openGcalText.implicitWidth + 14
                            radius: Theme.moduleEdgeRadius / 2
                            color: openGcalHover.hovered ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.3) : Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.18)
                            border.width: 1
                            border.color: Theme.statusBlue
                            HoverHandler { id: openGcalHover }

                            Text {
                                id: openGcalText
                                anchors.centerIn: parent
                                text: "Open Google Calendar 󰌹"
                                color: Theme.statusBlue
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize * 0.75
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calendarProc.running = true
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Timers & Background Processes ────────────────────────────
    // 1-second clock timer
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.updateTime()
    }

    // Browser launcher process for Google Calendar
    Process {
        id: calendarProc
        command: ["zen", "--new-instance", "-P", "Calendar", "https://calendar.google.com"]
    }

    // Component initialization
    Component.onCompleted: {
        updateTime()
        updateCalendarGrid()
    }
}
