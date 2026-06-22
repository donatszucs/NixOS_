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
                percent: 100
                pillText: "100% "
                pillVariant: expanded ? "light" : "dark"
                textAlign: "right"
                
                rightMargin: Theme.modulePaddingH

                bottomRightRadius: audioModule.expanded ? Theme.moduleEdgeRadius : 0

                function refresh() {
                    volProc.running = true
                }

                onClicked: expanded = !expanded

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0)
                            volUpProc.running = true
                        else
                            volDownProc.running = true
                    }
                }
            }

            ModuleButton {
                implicitWidth: maxSinkBarLength - volumeButton.implicitWidth + 20
                implicitHeight: Theme.moduleHeight
                bottomLeftRadius: audioModule.expanded ? Theme.moduleEdgeRadius : 0

                cursorShape: Qt.PointingHandCursor
                onClicked: pavu.running = true

                label: "Audio"

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

                                    
                colorOverride: modelData.active 
                overrideColor: Qt.darker(Theme.palettePaper, 1.4)
                
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

    Process {
            id: volProc
            command: ["bash", "-c",
                "wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -oP '[0-9]+\\.[0-9]+' | awk '{printf \"%d\", $1 * 100}'"
            ]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    var s = text.trim()
                    if (s.length === 0) return

                    var v = parseInt(s, 10)
                    if (isNaN(v)) return

                    volumeButton.percent = v
                    if (v === 0) {
                        volumeButton.pillText = v + "% "
                    } else if (v > 0 && v < 50) {
                        volumeButton.pillText = v + "% "
                    } else {
                        volumeButton.pillText = v + "% "
                    }
                }
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

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: volumeButton.refresh()
    }

    Process {
        id: pavu
        command: ["bash", "-c", "pwvucontrol"]
    }

    Process {
        id: volUpProc
        command: ["bash", "-c", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 2%+"]
        onRunningChanged: if (!running) volumeButton.refresh()
    }

    Process {
        id: volDownProc
        command: ["bash", "-c", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 2%-"]
        onRunningChanged: if (!running) volumeButton.refresh()
    }
    }
}
