// Audio volume — reads from wpctl, scroll to adjust
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire

import "../elements"

ModuleButton {
    id: audioModule
    colorOverride: implicitHeight === Theme.moduleHeight
    noHoverColorChange: true
    dontAnimateColor: true
    property bool expanded: false
    property int maxSinkBarLength: 270
    property int sinkNameMaxChars: 30

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    HoverHandler {
        id: parentHover
        onHoveredChanged: {
            if (!parentHover.hovered && expanded) expanded = false
        }
    }
    
    ListModel {
        id: sinksListModel
    }

    bottomLeftRadius: expanded ? Theme.moduleEdgeRadius + 10: 0
    bottomRightRadius: expanded ? Theme.moduleEdgeRadius + 10 : 0
    clip: true

    property alias sinksModel: sinksListModel

    function updateSinks() {
        sinksListModel.clear()

        var defaultSink = (Pipewire && Pipewire.defaultAudioSink) ? Pipewire.defaultAudioSink : null

        if (Pipewire && Pipewire.nodes && Pipewire.nodes.values) {
            var vals = Pipewire.nodes.values
            for (var i = 0; i < vals.length; ++i) {
                var n = vals[i]
                if (!n || n.isStream) continue
                if (n.isSink) {
                    var desc = (n.description && n.description.length) ? n.description : ((n.nickname && n.nickname.length) ? n.nickname : n.name)
                    if (!desc) desc = "sink:" + (n.id !== undefined ? n.id : i)

                    var iconStr = "";
                    var p = n.properties || {};
                    var typeInfo = ((p["device.form_factor"] || "") + " " + (p["device.icon_name"] || "") + " " + (p["device.bus"] || "") + " " + desc).toLowerCase();
                    console.log(typeInfo)

                    if (typeInfo.includes("headset") || typeInfo.includes("headphone") || typeInfo.includes("hyperx cloud ii")) iconStr = "";
                    else if (typeInfo.includes("bluetooth") || typeInfo.includes("bluez")) iconStr = "";
                    else if (typeInfo.includes("hdmi") || typeInfo.includes("displayport")) iconStr = "󰽟";
                    else if (typeInfo.includes("iec958") || typeInfo.includes("speaker")) iconStr = "󰓃";
                    else if (typeInfo.includes("usb")) iconStr = "󰟀";

                    var active = false
                    if (defaultSink) {
                        if ((defaultSink.name && n.name && defaultSink.name === n.name) || (defaultSink.id !== undefined && n.id !== undefined && defaultSink.id === n.id)) {
                            active = true
                        }
                    }
                    sinksListModel.append({ "name": desc, "active": active, "id": n.id, "icon": iconStr })
                }
            }
        }
    }

    implicitHeight: expanded ? baseColumn.implicitHeight : Theme.moduleHeight
    implicitWidth: expanded ? baseColumn.implicitWidth : volumeButton.implicitWidth

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    ColumnLayout {
        id: baseColumn
        spacing: 10

        anchors {
            right: parent.right
            top: parent.top
        }
        
        RowLayout {
            spacing: 0
            layoutDirection: Qt.RightToLeft

            PillBarButton {
                id: volumeButton
                
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

                pillVariant: expanded ? "light" : "dark"
                textAlign: "right"
                
                rightMargin: Theme.modulePaddingH

                bottomRightRadius: audioModule.expanded ? Theme.moduleEdgeRadius : 0

                onClicked: expanded = !expanded

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onWheel: wheel => {
                        if (volumeButton.pwAudio) {
                            if (wheel.angleDelta.y > 0) {
                                volumeButton.pwAudio.volume = Math.min(1.0, volumeButton.currentVolume + 0.02)
                            } else {
                                volumeButton.pwAudio.volume = Math.max(0.0, volumeButton.currentVolume - 0.02)
                            }
                        }
                    }
                }
            }

            PillBarButton {
                id: testButton
                implicitWidth: Theme.moduleHeight + 5
                implicitHeight: Theme.moduleHeight
                
                pillText: "󰐊" // Play icon
                cursorShape: Qt.PointingHandCursor
                pillVariant: "dark"
                percent: 0

                onClicked: testSoundProcess.running = true

                Process {
                    id: testSoundProcess
                    command: ["bash", "-c", "REPO=$(dirname $(dirname $(realpath ~/.config/quickshell))); pw-play \"$REPO/misc/ping.ogg\""]
                }
            }

            PillBarButton {
                id: audioMixerBtn
                implicitWidth: maxSinkBarLength - volumeButton.implicitWidth + 20 - testButton.implicitWidth
                implicitHeight: Theme.moduleHeight
                bottomLeftRadius: audioModule.expanded ? Theme.moduleEdgeRadius : 0

                cursorShape: Qt.PointingHandCursor
                onClicked: pavu.running = true

                pillText: "Audio Mixer"
                pillVariant: "dark"
                percent: 100
            }
        }
        // Action buttons — revealed by clip as width expands leftward
        ListView {
            id: actionColumn
            model: sinksListModel
            clip: true
            spacing: 5
            focus: false
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 10
            implicitHeight: contentHeight
            delegate: ModuleButton {
                id: parentButton
                required property var modelData
                required property int index

                variant: modelData.active ? "light" : "neutral"
                cursorShape: Qt.PointingHandCursor
                implicitWidth: maxSinkBarLength
                implicitHeight: Theme.listHeight
                
                topLeftRadius: index === 0 ? Theme.moduleEdgeRadius : 5
                bottomLeftRadius: index === sinksModel.count - 1 ? Theme.moduleEdgeRadius : 5
                bottomRightRadius: index === sinksModel.count - 1 ? Theme.moduleEdgeRadius : 5
                topRightRadius: index === 0 ? Theme.moduleEdgeRadius : 5

                label: ""
                
                border.width: 2

                RowLayout {
                    anchors { fill: parent; rightMargin: 10 }
                    spacing: 10

                    Rectangle {
                        color: parentButton.pal.base
                        topLeftRadius: parentButton.topLeftRadius
                        bottomLeftRadius: parentButton.bottomLeftRadius
                        implicitWidth: Theme.listHeight
                        implicitHeight: Theme.listHeight

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
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: Theme.paletteInk
                            font.family: Theme.font
                            font.pixelSize: 20
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    HoverMarqueeText {
                        Layout.fillWidth: true
                        text: modelData.name
                        textMaxWidth: 200 
                        fontFamily: Theme.font
                        pixelSize: parentButton.textFont
                        fontBold: true
                        textColor: parentButton.textColor
                        clip: true
                    }
                }

                Process {
                    id: actionProc
                    command: ["bash", "-c", "wpctl set-default " + modelData.id]
                }

                onClicked: actionProc.running = true

            }
        }


    Component.onCompleted: {
        audioModule.updateSinks()
    }

    Connections {
        target: Pipewire
        function onReadyChanged() { audioModule.updateSinks() }
        function onDefaultAudioSinkChanged() { audioModule.updateSinks() }
    }

    Connections {
        target: Pipewire.nodes
        function onObjectInsertedPost() { audioModule.updateSinks() }
        function onObjectRemovedPost() { audioModule.updateSinks() }
    }

    Process {
        id: pavu
        command: ["bash", "-c", "pwvucontrol"]
    }

    }
}
