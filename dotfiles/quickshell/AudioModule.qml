// Audio volume — reads from wpctl, scroll to adjust
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire

ModuleButton {
    id: audioModule
    variant: "dark"
    noHoverColorChange: true
    property bool expanded: false
    property int maxSinkBarLength: 0

    HoverHandler {
        id: parentHover
        onHoveredChanged: {
            if (!parentHover.hovered && expanded) expanded = false
        }
    }
    
    ListModel {
        id: sinksListModel
    }

    property alias sinksModel: sinksListModel

    function updateSinks() {
        sinksListModel.clear()

        var defaultSink = (Pipewire && Pipewire.defaultAudioSink) ? Pipewire.defaultAudioSink : null

        if (Pipewire && Pipewire.nodes && Pipewire.nodes.values) {
            var vals = Pipewire.nodes.values
            var maxSinkLen = 0
            for (var i = 0; i < vals.length; ++i) {
                var n = vals[i]
                if (!n || n.isStream) continue
                if (n.isSink) {
                    var desc = (n.description && n.description.length) ? n.description : ((n.nickname && n.nickname.length) ? n.nickname : n.name)
                    if (!desc) desc = "sink:" + (n.id !== undefined ? n.id : i)

                    var active = false
                    if (defaultSink) {
                        if ((defaultSink.name && n.name && defaultSink.name === n.name) || (defaultSink.id !== undefined && n.id !== undefined && defaultSink.id === n.id)) {
                            active = true
                        }
                    }
                    if (desc.length > maxSinkLen) maxSinkLen = desc.length
                    sinksListModel.append({ "name": desc, "active": active, "id" : n.id })
                    maxSinkBarLength = maxSinkLen * 9 - 90
                }
            }
        }
    }

    implicitHeight: expanded ? Theme.moduleHeight * (1 + sinksListModel.count) + divider.implicitHeight : Theme.moduleHeight
    implicitWidth: expanded ? (maxSinkBarLength + volumeButton.implicitWidth) : volumeButton.implicitWidth

    Behavior on implicitWidth {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
    }
    ColumnLayout {
        id: baseColumn
        spacing: 0

        anchors {
            right: parent.right
            top: parent.top
        }
        
        RowLayout {
            spacing: 0
            layoutDirection: Qt.RightToLeft

            ModuleButton {
                id: volumeButton
                label: "100% "
                variant: "transparentDark"
                textAlign: "right"
                rightMargin: 14

                bottomRightRadius: expanded ? 0 : Theme.moduleRadius
                topLeftRadius: expanded ? 0 : Theme.moduleRadius

                function refresh() {
                    volProc.running = true
                }

                onClicked: {
                    expanded = !expanded
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0)
                            volUpProc.running = true
                        else
                            volDownProc.running = true
                    }
                    onPressed: mouse => {
                        if (mouse.button === Qt.RightButton) pavu.running = true
                    }
                }
            }
            Rectangle {
                visible: expanded
                implicitWidth: expanded ? maxSinkBarLength : 0
                implicitHeight: Theme.moduleHeight
                color: "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "Output Devices:"
                    color: Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                }

            }
        }
        Rectangle {
            id: divider
            visible: expanded
            implicitWidth: audioModule.implicitWidth
            implicitHeight: 10
            color: "transparent"
        }
        // Action buttons — revealed by clip as width expands leftward
        ColumnLayout {
            id: actionColumn
            visible: audioModule.expanded
            spacing: 0
            Repeater {
                model: sinksListModel
                delegate: ModuleButton {
                    required property var modelData
                    variant: modelData.active ? "light" : "transparentDark"
                    implicitWidth: expanded ? maxSinkBarLength + volumeButton.implicitWidth : 0

                    label: modelData.name

                    Process {
                        id: actionProc
                        command: ["bash", "-c", "wpctl set-default " + modelData.id]
                    }

                    onClicked: actionProc.running = true

                }
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

                    if (v === 0) {
                        volumeButton.label = v + "%  "
                    } else if (v > 0 && v < 50) {
                        volumeButton.label = v + "%  "
                    } else {
                        volumeButton.label = v + "%  "
                    }
                }
            }
        }

    Component.onCompleted: {
        audioModule.updateSinks()
    }

    Connections {
        target: Pipewire
        onReadyChanged: audioModule.updateSinks()
        onDefaultAudioSinkChanged: audioModule.updateSinks()
    }

    Connections {
        target: Pipewire.nodes
        onObjectInsertedPost: audioModule.updateSinks()
        onObjectRemovedPost: audioModule.updateSinks()
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
