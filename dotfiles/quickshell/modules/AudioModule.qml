// Audio volume — reads from wpctl, scroll to adjust
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire

import "../elements"

ExpandableModule {
    id: audioModule
    useDefaultPill: false

    property int maxSinkBarLength: 270
    property int sinkNameMaxChars: 30

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
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

    implicitHeight: expanded ? baseColumn.implicitHeight + Theme.moduleHeight : Theme.moduleHeight
    implicitWidth: expanded ? baseColumn.implicitWidth : volumeButton.implicitWidth

    PillBarButton {
        id: volumeButton
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: Theme.moduleHeight
        implicitHeight: Theme.moduleHeight

        property var pwAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        property bool isMuted: pwAudio ? pwAudio.muted : false
        property real currentVolume: pwAudio ? pwAudio.volume : 0.0

        percent: Math.round(currentVolume * 100)

        pillText: {
            var v = percent
            if (isMuted) return v + "% 󰖁"
            if (v === 0) return v + "% "
            if (v > 0 && v < 50) return v + "% "
            return v + "% "
        }

        pillVariant: "dark"
        variant: "neutral"
        textAlign: "right"

        colorOpacity: 0.5
        pillColorOpacity: Theme.moduleOpacity
        colorOverride: true
        noHoverColorChange: !audioModule.expanded

        rightMargin: Theme.modulePaddingH

        bottomLeftRadius: audioModule.expanded ? Theme.moduleEdgeRadius : 0
        bottomRightRadius: audioModule.expanded ? Theme.moduleEdgeRadius : 0

        MouseArea {
            id: volMouseArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true

            property real startX: 0
            property bool isDragging: false

            onPressed: (mouse) => {
                startX = mouse.x
                isDragging = false
            }

            onPositionChanged: (mouse) => {
                if (mouse.buttons & Qt.LeftButton) {
                    if (Math.abs(mouse.x - startX) > 4) {
                        isDragging = true
                    }
                    if (isDragging && volumeButton.pwAudio) {
                        var trackWidth = volumeButton.width - 10
                        var frac = Math.max(0.0, Math.min(1.0, (mouse.x - 5) / trackWidth))
                        volumeButton.pwAudio.volume = frac
                    }
                }
            }

            onReleased: (mouse) => {
                if (!isDragging) {
                    audioModule.expanded = !audioModule.expanded
                }
                isDragging = false
            }

            onWheel: (wheel) => {
                if (volumeButton.pwAudio) {
                    if (wheel.angleDelta.y > 0) {
                        volumeButton.pwAudio.volume = Math.min(1.0, volumeButton.currentVolume + 0.02)
                    } else {
                        volumeButton.pwAudio.volume = Math.max(0.0, volumeButton.currentVolume - 0.02)
                    }
                }
                wheel.accepted = true
            }
        }
    }

    ColumnLayout {
        id: baseColumn
        spacing: 10

        anchors {
            top: volumeButton.bottom
            right: parent.right
        }

        MouseArea {
            visible: audioModule.expanded
            implicitWidth: audioModule.cardWidth
            Layout.preferredHeight: popupCol.implicitHeight
            Layout.margins: 10
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
                    clip: true
                    border.width: 2
                    border.color: Theme.cardBorder

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
                            delegate: ModuleButton {
                                id: sinkBtn
                                required property var modelData
                                required property int index

                                variant: "neutral"
                                cursorShape: Qt.PointingHandCursor
                                Layout.fillWidth: true
                                implicitHeight: 46
                                radius: Theme.moduleEdgeRadius / 2 + 5
                                opacity: 1.0
                                border.width: 2
                                border.color: modelData.active ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.35) : borderColorAdaptive
                                RowLayout {
                                    id: sinkRow
                                    anchors.fill: parent
                                    anchors.rightMargin: 10
                                    spacing: 12

                                    Rectangle {
                                        id: devIconBox
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: sinkBtn.implicitHeight
                                        implicitWidth: sinkBtn.implicitHeight
                                        implicitHeight: sinkBtn.implicitHeight
                                        color: modelData.active ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.35) : Theme.divider
                                        topLeftRadius: sinkBtn.radius
                                        bottomLeftRadius: sinkBtn.radius

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
                                            id: devIconText
                                            anchors.centerIn: parent
                                            text: modelData.icon
                                            color: modelData.active ? Theme.statusBlue : Theme.textPrimary
                                            opacity: modelData.active ? 1.0 : 0.7
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
                                            fontBold: modelData.active
                                            textColor: Theme.textPrimary
                                        }

                                        Text {
                                            text: modelData.active ? "Active" : "Output"
                                            color: modelData.active ? Theme.statusGreen : Theme.statusDisabled
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize * 0.75
                                            font.bold: modelData.active
                                        }
                                    }
                                }

                                Process {
                                    id: actionProc
                                    command: ["bash", "-c", "wpctl set-default " + modelData.id]
                                }

                                onClicked: actionProc.running = true
                            }
                        }
                    }
                }

                Rectangle {
                    color: Theme.bgBlurColor
                    radius: Theme.moduleEdgeRadius / 2 + 10
                    Layout.fillWidth: true
                    implicitHeight: inputTopBar.height + sourceCol.implicitHeight + 20
                    clip: true
                    border.width: 2
                    border.color: Theme.cardBorder

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

                                variant: "neutral"
                                cursorShape: Qt.PointingHandCursor
                                Layout.fillWidth: true
                                implicitHeight: 46
                                radius: Theme.moduleEdgeRadius / 2 + 5
                                opacity: 1.0
                                border.width: 2
                                border.color: modelData.active ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.35) : borderColorAdaptive

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
                                        color: modelData.active ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.35) : Theme.divider
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
                                            color: modelData.active ? Theme.statusBlue : Theme.textPrimary
                                            opacity: modelData.active ? 1.0 : 0.7
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
                                            fontBold: modelData.active
                                            textColor: Theme.textPrimary
                                        }

                                        Text {
                                            text: modelData.active ? "Active" : "Input"
                                            color: modelData.active ? Theme.statusGreen : Theme.statusDisabled
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize * 0.75
                                            font.bold: modelData.active
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
        function onDefaultAudioSinkChanged() { audioModule.updateDevices() }
        function onDefaultAudioSourceChanged() { audioModule.updateDevices() }
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
