// Weather module — powered by SharedState & Open-Meteo
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects

import "../elements"

ExpandableModule {
    id: root

    Component {
        id: cardShadowEffect
        MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.65)
            shadowBlur: 0.8
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 0
        }
    }

    readonly property real   temperature:    SharedState.weatherTemperature
    readonly property string weatherIcon:    SharedState.weatherIcon
    readonly property string weatherDesc:    SharedState.weatherDesc
    readonly property bool   isDay:          SharedState.weatherIsDay
    readonly property bool   loaded:         SharedState.weatherLoaded
    readonly property bool   isUpdating:     SharedState.weatherUpdating
    readonly property var    hourlyForecast: SharedState.weatherHourlyForecast
    readonly property var    dailyForecast:  SharedState.weatherDailyForecast

    function fetchWeather() {
        SharedState.fetchWeather()
    }

    property int cardWidth: 310

    implicitHeight: expanded ? baseColumn.implicitHeight + Theme.moduleHeight + root.titleBarHeight + 15 : Theme.moduleHeight

    readonly property real weatherNaturalWidth: Math.max(80, Math.round(pillContent.implicitWidth + 30))
    property real lastWeatherWidth: 100

    onWeatherNaturalWidthChanged: {
        if (!expanded && weatherNaturalWidth > 80) {
            lastWeatherWidth = weatherNaturalWidth
        }
    }

    collapsedWidth: expanded ? lastWeatherWidth : weatherNaturalWidth

    expandedDropdownWidth: cardWidth + 30
    dropdownAlignment: "center"

    leftCornerStyle: "side"
    rightCornerStyle: "side"

    pillPercent: 0
    pillVariant: "neutral"
    expandedPillLabel: "Weather"

    // Collapsed content inside the base pill
    RowLayout {
        id: pillContent
        parent: root.headerPill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: Math.round(Theme.moduleHeight / 2)
        spacing: 8
        z: 6

        opacity: root.expanded ? 0.0 : 1.0
        visible: opacity > 0
        Behavior on opacity { 
            NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } 
        }

        Text {
            text: root.weatherIcon
            color: Theme.textPrimary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 2
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            text: root.loaded ? root.temperature + "°C" : "—"
            color: Theme.textPrimary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.bold: true
            verticalAlignment: Text.AlignVCenter
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 14
            color: Theme.textPrimary
            opacity: 0.2
            visible: root.loaded
        }

        Text {
            id: descText
            text: root.isUpdating ? "Updating..." : (root.loaded ? root.weatherDesc : "Loading")
            color: Theme.textPrimary
            opacity: 0.7
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            font.bold: false
            verticalAlignment: Text.AlignVCenter
        }
    }

    ColumnLayout {
        id: baseColumn
        parent: root.overlay
        spacing: 10
        anchors {
            top: parent.top
            topMargin: root.titleBarHeight
            horizontalCenter: parent.horizontalCenter
        }

        scale: expanded ? 1 : 0
        transformOrigin: Item.Top
        Behavior on scale { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

        MouseArea {
            visible: root.contentVisible
            opacity: root.contentOpacity
            implicitWidth: root.cardWidth
            Layout.preferredWidth: root.cardWidth
            Layout.preferredHeight: popupCol.implicitHeight
            Layout.alignment: Qt.AlignHCenter
            acceptedButtons: Qt.NoButton

            ColumnLayout {
                id: popupCol
                width: parent.width
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Forecast"
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 8
                        font.bold: true
                        Layout.fillWidth: true
                        Layout.leftMargin: launcherModule.padding
                    }
                    ModuleButton {
                        variant: "light"
                        label: root.isUpdating ? "Updating..." : "󰑐"
                        implicitHeight: 30
                        radius: Theme.moduleEdgeRadius / 2
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.fetchWeather()
                    }
                }

                Rectangle {
                    color: Theme.bgBlurColor
                    radius: Theme.moduleEdgeRadius / 2 + 10
                    Layout.fillWidth: true
                    implicitHeight: 200
                    border.width: 2
                    border.color: Theme.cardBorder
                    clip: true

                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: cardShadowEffect

                    Rectangle {
                        id: hourlyTopBar
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 35
                        color: Theme.topBarBlurColor

                        topLeftRadius: parent.radius
                        topRightRadius: parent.radius
                        bottomLeftRadius: 0
                        bottomRightRadius: 0

                        Text {
                            id: hourlyTitle
                            text: "Hourly"
                            color: Theme.textPrimary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                            anchors.centerIn: parent
                        }

                        Text {
                            text: "Reset"
                            color: Theme.textPrimary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 2
                            opacity: graphFlickable.contentX > 10 ? 0.6 : 0
                            anchors.right: parent.right
                            anchors.rightMargin: 15
                            anchors.verticalCenter: parent.verticalCenter
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -10
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    resetAnim.start();
                                }
                            }

                            NumberAnimation {
                                id: resetAnim
                                target: graphFlickable
                                property: "contentX"
                                to: 0
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    InverseRadius {
                        anchors.top: hourlyTopBar.bottom
                        anchors.left: hourlyTopBar.left
                        color: hourlyTopBar.color
                    }

                    InverseRadius {
                        cornerPosition: "topRight"
                        anchors.top: hourlyTopBar.bottom
                        anchors.right: hourlyTopBar.right
                        color: hourlyTopBar.color
                    }

                    Flickable {
                        id: graphFlickable
                        anchors.top: hourlyTopBar.bottom
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        
                        contentWidth: graphContainer.width
                        contentHeight: height
                        clip: true
                        
                        ScrollBar.horizontal: ScrollBar {
                            contentItem: Rectangle {
                                implicitHeight: 4
                                radius: 2
                                color: Theme.textPrimary
                                opacity: 0.5
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: function(wheel) {
                                if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
                                    graphFlickable.contentX = Math.max(0, graphFlickable.contentX - 50)
                                } else {
                                    graphFlickable.contentX = Math.min(graphFlickable.contentWidth - graphFlickable.width, graphFlickable.contentX + 50)
                                }
                            }
                        }

                        Item {
                            id: graphContainer
                            height: parent.height - 15
                            anchors.top: parent.top
                            width: Math.max(graphFlickable.width, root.hourlyForecast.length * 50)

                        property var model: root.hourlyForecast
                        property real minTemp: 0
                        property real maxTemp: 0

                        onModelChanged: {
                            if (!model || model.length === 0) return;
                            var mn = model[0].temp;
                            var mx = model[0].temp;
                            for (var i = 1; i < model.length; i++) {
                                if (model[i].temp < mn) mn = model[i].temp;
                                if (model[i].temp > mx) mx = model[i].temp;
                            }
                            if (mn === mx) { mn -= 1; mx += 1; }
                            minTemp = mn;
                            maxTemp = mx;
                            if (graphCanvas.available) graphCanvas.requestPaint();
                        }

                        Canvas {
                            id: graphCanvas
                            anchors.fill: parent
                            property bool available: true

                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            property real sidePadding: 20
                            property real topPadding: 45
                            property real bottomPadding: 20
                            property real graphWidth: Math.max(10, width - 2 * sidePadding)
                            property real graphHeight: Math.max(10, height - topPadding - bottomPadding)

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);

                                var m = graphContainer.model;
                                if (!m || m.length === 0) return;

                                var tempRange = graphContainer.maxTemp - graphContainer.minTemp;
                                if (tempRange === 0) tempRange = 1;
                                var stepX = graphWidth / (m.length - 1);

                                function getPt(idx) {
                                    if (idx < 0) idx = 0;
                                    if (idx >= m.length) idx = m.length - 1;
                                    return {
                                        x: sidePadding + idx * stepX,
                                        y: topPadding + graphHeight - ((m[idx].temp - graphContainer.minTemp) / tempRange) * graphHeight
                                    };
                                }

                                function drawSpline() {
                                    var p0 = getPt(0);
                                    ctx.moveTo(p0.x, p0.y);
                                    for (var i = 0; i < m.length - 1; i++) {
                                        var pm1 = getPt(i - 1);
                                        var pi = getPt(i);
                                        var pp1 = getPt(i + 1);
                                        var pp2 = getPt(i + 2);
                                        
                                        // tx controls horizontal stretching (0.25 is similar to the old stepX / 2)
                                        // ty controls vertical swooping (0 is flat plateaus, 0.25 is full swooping splines)
                                        var tx = 0.25;
                                        var ty = 0.15;
                                        ctx.bezierCurveTo(
                                            pi.x + (pp1.x - pm1.x) * tx, pi.y + (pp1.y - pm1.y) * ty,
                                            pp1.x - (pp2.x - pi.x) * tx, pp1.y - (pp2.y - pi.y) * ty,
                                            pp1.x, pp1.y
                                        );
                                    }
                                }

                                // Draw filled area
                                ctx.beginPath();
                                drawSpline();
                                ctx.lineTo(sidePadding + graphWidth, height - bottomPadding + 15);
                                ctx.lineTo(sidePadding, height - bottomPadding + 15);
                                ctx.closePath();

                                var gradient = ctx.createLinearGradient(0, 0, 0, height);
                                gradient.addColorStop(0, Theme.textPrimary.toString());
                                gradient.addColorStop(1, "transparent");
                                ctx.fillStyle = gradient;
                                ctx.globalAlpha = 0.15;
                                ctx.fill();
                                ctx.globalAlpha = 1.0;

                                // Draw line
                                ctx.beginPath();
                                drawSpline();
                                ctx.strokeStyle = Theme.textPrimary.toString();
                                ctx.lineWidth = 2.5;
                                ctx.stroke();

                                // Draw dots
                                ctx.fillStyle = Theme.textPrimary.toString();
                                for (var i = 0; i < m.length; i++) {
                                    var pt = getPt(i);
                                    ctx.beginPath();
                                    ctx.arc(pt.x, pt.y, 3.5, 0, 2 * Math.PI);
                                    ctx.fill();
                                }
                            }
                        }

                        Repeater {
                            model: graphContainer.model
                            delegate: Item {
                                x: graphCanvas.sidePadding + index * (graphCanvas.graphWidth / Math.max(1, graphContainer.model.length - 1))
                                y: 0
                                width: 0
                                height: graphContainer.height

                                Column {
                                    anchors.bottom: dotPoint.top
                                    anchors.bottomMargin: 6
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4
                                    Text {
                                        text: modelData.icon
                                        color: Theme.textPrimary
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize + 2
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Text {
                                        text: modelData.temp + "°"
                                        color: Theme.textPrimary
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 1
                                        font.bold: true
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }

                                Item {
                                    id: dotPoint
                                    y: {
                                        var tempRange = graphContainer.maxTemp - graphContainer.minTemp;
                                        if (tempRange === 0) tempRange = 1;
                                        return graphCanvas.topPadding + graphCanvas.graphHeight - ((modelData.temp - graphContainer.minTemp) / tempRange) * graphCanvas.graphHeight;
                                    }
                                    width: 1
                                    height: 1
                                }

                                Text {
                                    text: modelData.time
                                    color: Theme.textPrimary
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 2
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    opacity: 0.6
                                }
                            }
                        }
                    }
                    }
                }

                Rectangle {
                    color: Theme.bgBlurColor
                    radius: Theme.moduleEdgeRadius / 2 + 10
                    Layout.fillWidth: true
                    implicitHeight: 165
                    border.width: 2
                    border.color: Theme.cardBorder
                    clip: true

                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: cardShadowEffect

                    Rectangle {
                        id: dailyTopBar
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 35
                        color: Theme.topBarBlurColor

                        radius: parent.radius
                        topLeftRadius: parent.radius
                        topRightRadius: parent.radius
                        bottomLeftRadius: 0
                        bottomRightRadius: 0

                        Text {
                            id: dailyTitle
                            text: "10-Day"
                            color: Theme.textPrimary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                            anchors.centerIn: parent
                        }

                        Text {
                            text: "Reset"
                            color: Theme.textPrimary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 2
                            opacity: carousel.currentIndex > 2 ? 0.6 : 0
                            anchors.right: parent.right
                            anchors.rightMargin: 15
                            anchors.verticalCenter: parent.verticalCenter
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -10
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    carousel.currentIndex = 2;
                                }
                            }
                        }
                    }

                    InverseRadius {
                        anchors.top: dailyTopBar.bottom
                        anchors.left: dailyTopBar.left
                        color: dailyTopBar.color
                    }

                    InverseRadius {
                        cornerPosition: "topRight"
                        anchors.top: dailyTopBar.bottom
                        anchors.right: dailyTopBar.right
                        color: dailyTopBar.color
                    }

                    ListView {
                        id: carousel
                        anchors.top: dailyTopBar.bottom
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 5
                        anchors.bottomMargin: 8
                        model: root.dailyForecast
                        orientation: ListView.Horizontal
                        currentIndex: 2
                        
                        onCurrentIndexChanged: {
                            if (currentIndex < 2) {
                                currentIndex = 2
                            }
                        }
                    
                        // Center the selected item without wrapping
                        preferredHighlightBegin: carousel.width / 2 - 37.5
                        preferredHighlightEnd: carousel.width / 2 + 37.5
                        highlightRangeMode: ListView.StrictlyEnforceRange
                        snapMode: ListView.SnapToItem
                        
                        spacing: 15

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: function(wheel) {
                                if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
                                    if (carousel.currentIndex > 2)
                                        carousel.decrementCurrentIndex()
                                } else {
                                    carousel.incrementCurrentIndex()
                                }
                            }
                        }
                        
                        delegate: Item {
                            id: delegateRoot
                            width: 70
                            height: carousel.height
                            
                            property real itemCenter: x + width / 2
                            property real viewCenter: carousel.contentX + carousel.width / 2
                            property real centerDist: itemCenter - viewCenter
                            
                            // Create a deadzone so 3 cards stay in full focus (centers are at 0, 90, -90)
                            property real absCenterDist: Math.abs(centerDist)
                            property real outOfFocusDist: Math.max(0, absCenterDist - 90)
                            
                            property real absDist: Math.min(1.0, outOfFocusDist / 100)
                            property real effectiveNormDist: (centerDist < 0 ? -1 : 1) * absDist
                            
                            z: 100 - absDist * 100
                            
                            Item {
                                width: 70
                                height: 90
                                anchors.centerIn: parent
                                
                                // 1.1 base scale for focus zone, plus an extra 0.1 bump for the true center card
                                scale: 1.1 - 0.4 * delegateRoot.absDist + Math.max(0, 1.0 - delegateRoot.absCenterDist / 90) * 0.1
                                
                                transform: Translate {
                                    x: -Math.pow(delegateRoot.effectiveNormDist, 3) * 100
                                }
                                
                                Rectangle {
                                    id: cardBg
                                    anchors.fill: parent
                                    color: Qt.darker(Theme.palettePaper, 1.1)
                                    radius: Theme.moduleEdgeRadius / 2

                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.effect: MultiEffect {
                                        brightness: -delegateRoot.absDist * 0.3
                                        contrast: -delegateRoot.absDist * 0.7
                                        shadowEnabled: true
                                        shadowColor: Qt.rgba(0, 0, 0, 0.6)
                                        shadowBlur: 0.8
                                        shadowVerticalOffset: 0
                                        shadowHorizontalOffset: 0

                                        Behavior on shadowColor {
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                                
                                ColumnLayout {
                                    id: dailyCol
                                    anchors.centerIn: parent
                                    spacing: 1
                                    opacity: 1.0 - delegateRoot.absDist * 0.4
                                    
                                    Text {
                                        text: modelData.day
                                        color: Theme.textDark
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 3
                                        font.bold: modelData.day === "Today" || carousel.currentIndex === index
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        text: modelData.date
                                        color: Theme.textDark
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 3
                                        opacity: 0.7
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Item { Layout.preferredHeight: 2 }
                                    Text {
                                        text: modelData.icon
                                        color: Theme.textDark
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        text: modelData.maxTemp + "°"
                                        color: Theme.textDark
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 2
                                        font.bold: true
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        text: modelData.minTemp + "°"
                                        color: Theme.textDark
                                        opacity: 0.6
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 4
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                preventStealing: false
                                onClicked: {
                                    if (index >= 2) {
                                        carousel.currentIndex = index
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
