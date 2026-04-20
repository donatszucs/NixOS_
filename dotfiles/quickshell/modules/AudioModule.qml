// Audio volume — reads from wpctl, scroll to adjust
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire

import "../elements"

ModuleButton {
    id: audioModule
    color: implicitHeight === Theme.moduleHeight ? "transparent" : Theme.palette("dark").base
    dontAnimateColor: true
    property bool expanded: false
    property int maxSinkBarLength: 0
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

    bottomLeftRadius: expanded ? Theme.moduleEdgeRadius + 5 : Theme.moduleRadius
    bottomRightRadius: expanded ? Theme.moduleEdgeRadius + 5 : Theme.moduleRadius
    clip: true

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
                    var cappedLen = Math.min(desc.length, sinkNameMaxChars)
                    if (cappedLen > maxSinkLen) maxSinkLen = cappedLen
                    sinksListModel.append({ "name": desc, "active": active, "id" : n.id })
                }
            }
            maxSinkBarLength = maxSinkLen * 9 + 7
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
                radius: Theme.moduleEdgeRadius
                label: ""

                readonly property string truncatedName: {
                    if (modelData.name.length <= sinkNameMaxChars) return modelData.name
                    if (sinkNameMaxChars <= 3) return modelData.name.slice(0, sinkNameMaxChars)
                    return modelData.name.slice(0, sinkNameMaxChars - 3) + "..."
                }

                Item {
                    id: sinkNameViewport
                    anchors {
                        fill: parent
                        leftMargin: Theme.modulePaddingH
                        rightMargin: Theme.modulePaddingH
                    }
                    clip: true

                    Text {
                        id: sinkNameText
                        text: parentButton.hovered ? modelData.name : parentButton.truncatedName
                        color: parentButton.textColor
                        font.family: Theme.font
                        font.pixelSize: parentButton.textFont
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                        x: 0
                    }

                    SequentialAnimation {
                        id: sinkNameMarquee
                        running: parentButton.hovered && sinkNameText.width > sinkNameViewport.width
                        loops: Animation.Infinite

                        onRunningChanged: {
                                if (!running) {
                                    sinkNameText.x = 0;
                                }
                            }

                        PauseAnimation { duration: 250 }
                        NumberAnimation {
                            target: sinkNameText
                            property: "x"
                            from: 0
                            to: -(sinkNameText.width - sinkNameViewport.width)
                            duration: Math.max(1200, (sinkNameText.width - sinkNameViewport.width) * 30)
                            easing.type: Easing.Linear
                        }
                        PauseAnimation { duration: 500 }
                        NumberAnimation {
                            target: sinkNameText
                            property: "x"
                            to: 0
                            duration: 250
                            easing.type: Easing.OutCubic
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
