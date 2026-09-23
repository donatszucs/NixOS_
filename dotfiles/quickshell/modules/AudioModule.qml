// Audio volume — PipeWire sink & source control, scroll to adjust
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick.Effects

import "../elements"

ExpandableModule {
    id: audioModule

    property var pwAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    property bool isMuted: pwAudio ? pwAudio.muted : false
    property real currentVolume: pwAudio ? pwAudio.volume : 0.0

    pillPercent: expanded ? 0 : Math.round(currentVolume * 100)
    pillText: {
        if (expanded) return ""
        var v = Math.round(currentVolume * 100)
        if (isMuted) return v + "% 󰖁"
        if (v === 0) return v + "% "
        if (v > 0 && v < 50) return v + "% "
        return v + "% "
    }
    pillVariant: expanded ? "neutral" : "dark"
    expandedPillLabel: "Audio"

    function getNode(nodeId) {
        if (!Pipewire || !Pipewire.nodes || !Pipewire.nodes.values) return null
        var vals = Pipewire.nodes.values
        for (var i = 0; i < vals.length; ++i) {
            if (vals[i] && vals[i].id === nodeId) return vals[i]
        }
        return null
    }

    PwObjectTracker {
        objects: {
            var arr = [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
            if (Pipewire && Pipewire.nodes && Pipewire.nodes.values) {
                for (var i = 0; i < Pipewire.nodes.values.length; ++i) {
                    var n = Pipewire.nodes.values[i]
                    if (n && (n.isSink || (n.properties && n.properties["media.class"] === "Audio/Sink"))) {
                        arr.push(n)
                    }
                }
            }
            return arr
        }
    }

    ListModel {
        id: sinksListModel
    }

    ListModel {
        id: sourcesListModel
    }

    property alias sinksModel: sinksListModel
    property alias sourcesModel: sourcesListModel

    function updateDevices() {
        sinksListModel.clear()
        sourcesListModel.clear()

        var defaultSink = (Pipewire && Pipewire.defaultAudioSink) ? Pipewire.defaultAudioSink : null
        var defaultSource = (Pipewire && Pipewire.defaultAudioSource) ? Pipewire.defaultAudioSource : null

        if (Pipewire && Pipewire.nodes && Pipewire.nodes.values) {
            var vals = Pipewire.nodes.values
            for (var i = 0; i < vals.length; ++i) {
                var n = vals[i]
                if (!n || n.isStream) continue

                var p = n.properties || {}
                var mediaClass = p["media.class"] || ""
                var desc = (n.description && n.description.length) ? n.description : ((n.nickname && n.nickname.length) ? n.nickname : n.name)

                // Skip monitor sources
                if (n.name && n.name.indexOf(".monitor") !== -1) continue

                if (n.isSink || mediaClass === "Audio/Sink") {
                    if (!desc) desc = "sink:" + (n.id !== undefined ? n.id : i)

                    var sinkIconStr = "";
                    var sinkTypeInfo = ((p["device.form_factor"] || "") + " " + (p["device.icon_name"] || "") + " " + (p["device.bus"] || "") + " " + desc).toLowerCase();

                    if (sinkTypeInfo.includes("headset") || sinkTypeInfo.includes("headphone") || sinkTypeInfo.includes("hyperx")) sinkIconStr = "";
                    else if (sinkTypeInfo.includes("bluetooth") || sinkTypeInfo.includes("bluez")) sinkIconStr = "";
                    else if (sinkTypeInfo.includes("hdmi") || sinkTypeInfo.includes("displayport")) sinkIconStr = "󰽟";
                    else if (sinkTypeInfo.includes("iec958") || sinkTypeInfo.includes("speaker")) sinkIconStr = "󰓃";
                    else if (sinkTypeInfo.includes("usb")) sinkIconStr = "󰟀";

                    var sinkActive = false
                    if (defaultSink) {
                        if ((defaultSink.name && n.name && defaultSink.name === n.name) || (defaultSink.id !== undefined && n.id !== undefined && defaultSink.id === n.id)) {
                            sinkActive = true
                        }
                    }
                    sinksListModel.append({ "name": desc, "active": sinkActive, "id": n.id, "icon": sinkIconStr })
                } else if (mediaClass === "Audio/Source" || mediaClass.indexOf("Source") !== -1 || (!n.isSink && n.audio !== null)) {
                    if (!desc) desc = "source:" + (n.id !== undefined ? n.id : i)

                    var srcIconStr = "";
                    var srcTypeInfo = ((p["device.form_factor"] || "") + " " + (p["device.icon_name"] || "") + " " + (p["device.bus"] || "") + " " + desc).toLowerCase();

                    if (srcTypeInfo.includes("headset") || srcTypeInfo.includes("headphone") || srcTypeInfo.includes("hyperx")) srcIconStr = "󰋎";
                    else if (srcTypeInfo.includes("bluetooth") || srcTypeInfo.includes("bluez")) srcIconStr = "";
                    else if (srcTypeInfo.includes("usb")) srcIconStr = "󰍬";

                    var srcActive = false
                    if (defaultSource) {
                        if ((defaultSource.name && n.name && defaultSource.name === n.name) || (defaultSource.id !== undefined && n.id !== undefined && defaultSource.id === n.id)) {
                            srcActive = true
                        }
                    }
                    sourcesListModel.append({ "name": desc, "active": srcActive, "id": n.id, "icon": srcIconStr })
                }
            }
        }
    }

    function updateSinks() {
        updateDevices()
    }

    property int cardWidth: 280

    implicitHeight: expanded ? baseColumn.implicitHeight + Theme.moduleHeight + audioModule.titleBarHeight + 15 : Theme.moduleHeight

    // Overlay dropdown setup
    expandedDropdownWidth: cardWidth + 30
    dropdownAlignment: "center"

    leftCornerStyle: "side"
    rightCornerStyle: "side"

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

    onPillWheel: (wheel) => {
        if (pwAudio) {
            if (wheel.angleDelta.y > 0) {
                pwAudio.volume = Math.min(1.0, currentVolume + 0.02)
            } else {
                pwAudio.volume = Math.max(0.0, currentVolume - 0.02)
            }
            wheel.accepted = true
        }
    }

    ColumnLayout {
        id: baseColumn
        parent: audioModule.overlay
        spacing: 10

        anchors {
            top: parent.top
            topMargin: audioModule.titleBarHeight
            horizontalCenter: parent.horizontalCenter
        }

        scale: expanded ? 1 : 0
        transformOrigin: Item.Top
        Behavior on scale { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

        MouseArea {
            visible: audioModule.contentVisible
            opacity: audioModule.contentOpacity
            implicitWidth: audioModule.cardWidth
            Layout.preferredWidth: audioModule.cardWidth
            Layout.preferredHeight: popupCol.implicitHeight
            Layout.alignment: Qt.AlignHCenter
            acceptedButtons: Qt.NoButton

            ColumnLayout {
                id: popupCol
                width: parent.width
                spacing: 10

                Rectangle {
                    color: Theme.bgBlurColor
                    radius: Theme.moduleEdgeRadius / 2 + 10
                    Layout.fillWidth: true
                    implicitHeight: audioTopBar.height + sinkCol.implicitHeight + 20
                    border.width: 2
                    border.color: Theme.cardBorder

                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: cardShadowEffect

                    Rectangle {
                        id: audioTopBar
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 35
                        color: Theme.topBarBlurColor

                        topLeftRadius: parent.radius
                        topRightRadius: parent.radius
                        bottomLeftRadius: 0
                        bottomRightRadius: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: "Output Devices"
                                color: Theme.textPrimary
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize + 1
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item { Layout.fillWidth: true } // spacer

                            ModuleButton {
                                variant: "light"
                                label: ""
                                textFont: 14
                                cursorShape: Qt.PointingHandCursor
                                onClicked: testSoundProcess.running = true
                                implicitHeight: 24
                                implicitWidth: 24
                                radius: Theme.moduleEdgeRadius / 2
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ModuleButton {
                                variant: "light"
                                label: "󰓃"
                                textFont: 14
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pavu.running = true
                                implicitHeight: 24
                                implicitWidth: 24
                                radius: Theme.moduleEdgeRadius / 2
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }

                    InverseRadius {
                        anchors.top: audioTopBar.bottom
                        anchors.left: audioTopBar.left
                        color: audioTopBar.color
                    }

                    InverseRadius {
                        cornerPosition: "topRight"
                        anchors.top: audioTopBar.bottom
                        anchors.right: audioTopBar.right
                        color: audioTopBar.color
                    }

                    ColumnLayout {
                        id: sinkCol
                        anchors {
                            top: audioTopBar.bottom
                            left: parent.left
                            right: parent.right
                            margins: 10
                        }
                        spacing: 5

                        Repeater {
                            model: sinksListModel
                            delegate: Rectangle {
                                id: sinkBtn
                                required property var modelData
                                required property int index

                                property var devNode: audioModule.getNode(modelData.id)
                                property var devAudio: devNode ? devNode.audio : null
                                property real devVolume: devAudio ? devAudio.volume : 0.0
                                property bool devMuted: devAudio ? devAudio.muted : false

                                readonly property bool isSinkActive: {
                                    var def = Pipewire.defaultAudioSink
                                    if (!def) return false
                                    if (def.id !== undefined && modelData.id !== undefined && def.id === modelData.id) return true
                                    if (def.name && devNode && devNode.name && def.name === devNode.name) return true
                                    return false
                                }

                                Layout.fillWidth: true
                                implicitHeight: 75
                                radius: Theme.moduleEdgeRadius / 2 + 5
                                color: isSinkActive ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.15) : Theme.divider
                                border.width: 2
                                border.color: isSinkActive ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.45) : Theme.cardBorder
                                clip: true

                                Behavior on color { ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }
                                Behavior on border.color { ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

                                Process {
                                    id: actionProc
                                    command: ["bash", "-c", "wpctl set-default " + modelData.id]
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 28

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: actionProc.running = true
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                spacing: 8

                                                Rectangle {
                                                    width: 28
                                                    height: 28
                                                    radius: 6
                                                    color: isSinkActive ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.35) : Theme.divider
                                                    Behavior on color { ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.icon
                                                        color: isSinkActive ? Theme.statusBlue : Theme.textPrimary
                                                        opacity: isSinkActive ? 1.0 : 0.7
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.fontSize + 2
                                                        font.bold: true
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1

                                                    HoverMarqueeText {
                                                        text: modelData.name
                                                        textMaxWidth: audioModule.cardWidth - 145
                                                        Layout.fillWidth: true
                                                        fontFamily: Theme.font
                                                        pixelSize: Theme.fontSize
                                                        fontBold: isSinkActive
                                                        textColor: Theme.textPrimary
                                                    }

                                                    Text {
                                                        text: isSinkActive ? "Active" : "Output"
                                                        color: isSinkActive ? Theme.statusGreen : Theme.statusDisabled
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.fontSize * 0.72
                                                        font.bold: isSinkActive
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            text: devMuted ? "Muted" : Math.round(devVolume * 100) + "%"
                                            color: devMuted ? Theme.statusRed : (isSinkActive ? Theme.textPrimary : Theme.statusDisabled)
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize - 1
                                            font.bold: true
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        ModuleButton {
                                            variant: devMuted ? "red" : (isSinkActive ? "light" : "neutral")
                                            label: devMuted ? "󰖁" : ""
                                            textFont: 12
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (devAudio) {
                                                    devAudio.muted = !devAudio.muted
                                                }
                                            }
                                            implicitHeight: 24
                                            implicitWidth: 24
                                            radius: 5
                                            border.width: 1
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    StyledSlider {
                                        id: devSlider
                                        Layout.fillWidth: true
                                        sliderHeight: 18
                                        radius: 5
                                        from: 0.0
                                        to: 1.0
                                        value: devVolume
                                        onMoved: {
                                            if (devAudio) {
                                                devAudio.volume = value
                                                if (devAudio.muted && value > 0) {
                                                    devAudio.muted = false
                                                }
                                            }
                                        }
                                        Layout.alignment: Qt.AlignVCenter

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
                    implicitHeight: inputTopBar.height + sourceCol.implicitHeight + 20
                    border.width: 2
                    border.color: Theme.cardBorder

                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: cardShadowEffect

                    Rectangle {
                        id: inputTopBar
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 35
                        color: Theme.topBarBlurColor

                        topLeftRadius: parent.radius
                        topRightRadius: parent.radius
                        bottomLeftRadius: 0
                        bottomRightRadius: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: "Input Devices"
                                color: Theme.textPrimary
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize + 1
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item { Layout.fillWidth: true } // spacer

                            ModuleButton {
                                property var pwSourceAudio: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
                                property bool isMuted: pwSourceAudio ? pwSourceAudio.muted : false

                                variant: isMuted ? "red" : "light"
                                label: isMuted ? "" : ""
                                textFont: 14
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (pwSourceAudio) {
                                        pwSourceAudio.muted = !pwSourceAudio.muted
                                    }
                                }
                                implicitHeight: 24
                                implicitWidth: 24
                                radius: Theme.moduleEdgeRadius / 2
                                border.width: 1
                                Layout.alignment: Qt.AlignVCenter
                            } 
                        }
                    }

                    InverseRadius {
                        anchors.top: inputTopBar.bottom
                        anchors.left: inputTopBar.left
                        color: inputTopBar.color
                    }

                    InverseRadius {
                        cornerPosition: "topRight"
                        anchors.top: inputTopBar.bottom
                        anchors.right: inputTopBar.right
                        color: inputTopBar.color
                    }

                    ColumnLayout {
                        id: sourceCol
                        anchors {
                            top: inputTopBar.bottom
                            left: parent.left
                            right: parent.right
                            margins: 10
                        }
                        spacing: 5

                        Repeater {
                            model: sourcesListModel
                            delegate: ModuleButton {
                                id: sourceBtn
                                required property var modelData
                                required property int index

                                readonly property bool isSourceActive: {
                                    var def = Pipewire.defaultAudioSource
                                    if (!def) return false
                                    if (def.id !== undefined && modelData.id !== undefined && def.id === modelData.id) return true
                                    return false
                                }

                                variant: "neutral"
                                cursorShape: Qt.PointingHandCursor
                                Layout.fillWidth: true
                                implicitHeight: 46
                                radius: Theme.moduleEdgeRadius / 2 + 5
                                opacity: 1.0
                                border.width: 2
                                border.color: isSourceActive ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.35) : borderColorAdaptive
                                Behavior on border.color { ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

                                RowLayout {
                                    id: sourceRow
                                    anchors.fill: parent
                                    anchors.rightMargin: 10
                                    spacing: 12

                                    Rectangle {
                                        id: srcIconBox
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: sourceBtn.implicitHeight
                                        implicitWidth: sourceBtn.implicitHeight
                                        implicitHeight: sourceBtn.implicitHeight
                                        color: isSourceActive ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.35) : Theme.divider
                                        Behavior on color { ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }
                                        topLeftRadius: sourceBtn.radius
                                        bottomLeftRadius: sourceBtn.radius

                                        InverseRadius {
                                            anchors.top: parent.top
                                            anchors.left: parent.right
                                            cornerPosition: "topLeft"
                                            color: parent.color
                                            size: 10
                                        }

                                        InverseRadius {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.right
                                            cornerPosition: "bottomLeft"
                                            color: parent.color
                                            size: 10
                                        }

                                        Text {
                                            id: srcIconText
                                            anchors.centerIn: parent
                                            text: modelData.icon
                                            color: isSourceActive ? Theme.statusBlue : Theme.textPrimary
                                            opacity: isSourceActive ? 1.0 : 0.7
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize + 3
                                            font.bold: true
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2

                                        HoverMarqueeText {
                                            text: modelData.name
                                            textMaxWidth: audioModule.cardWidth - 85
                                            Layout.fillWidth: true
                                            fontFamily: Theme.font
                                            pixelSize: Theme.fontSize
                                            fontBold: isSourceActive
                                            textColor: Theme.textPrimary
                                        }

                                        Text {
                                            text: isSourceActive ? "Active" : "Input"
                                            color: isSourceActive ? Theme.statusGreen : Theme.statusDisabled
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize * 0.75
                                            font.bold: isSourceActive
                                        }
                                    }
                                }

                                Process {
                                    id: actionSourceProc
                                    command: ["bash", "-c", "wpctl set-default " + modelData.id]
                                }

                                onClicked: actionSourceProc.running = true
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        audioModule.updateDevices()
    }

    Connections {
        target: Pipewire
        function onReadyChanged() { audioModule.updateDevices() }
    }

    Connections {
        target: Pipewire.nodes
        function onObjectInsertedPost() { audioModule.updateDevices() }
        function onObjectRemovedPost() { audioModule.updateDevices() }
    }

    Process {
        id: pavu
        command: ["bash", "-c", "pwvucontrol"]
    }

    Process {
        id: testSoundProcess
        command: ["bash", "-c", "REPO=$(dirname $(dirname $(realpath ~/.config/quickshell))); pw-play \"$REPO/misc/ping.ogg\""]
    }
}
