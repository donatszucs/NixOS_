import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "../elements"

Rectangle {
    id: sysmonPanel

    property real targetWidth: contentLayout.implicitWidth + 30
    property real targetHeight: Theme.moduleHeight - 4
    property bool expanded: false
    property string screenName: ""

    focus: expanded
    color: "transparent"

    // Drop down from below the bar
    implicitHeight: expanded ? targetHeight : 0
    implicitWidth: expanded ? targetWidth : 0
    
    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    IpcHandler {
        target: "sysmon-" + sysmonPanel.screenName
        function toggle(): void {
            sysmonPanel.expanded = !sysmonPanel.expanded;
        }
    }

    property string cpuUsage: "0%"
    property string ramUsage: "0 / 0 MB"
    property string gpuUsage: "0%"
    property string vramUsage: "0 / 0 MB"
    property string powerDraw: "0 W"

    Timer {
        interval: 2000
        running: sysmonPanel.expanded
        repeat: true
        onTriggered: statProc.running = true
        triggeredOnStart: true
    }

    Process {
        id: statProc
        command: ["bash", "-c", "top -bn1 | awk '/Cpu\\(s\\)/ {print $2 + $4}'; free -m | awk '/Mem:/ {print $3, $2}'; nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,power.draw --format=csv,noheader,nounits; cpu_pw=0; for f in /sys/class/hwmon/hwmon*/power1_input; do if [ -f \"$f\" ]; then val=$(cat \"$f\" 2>/dev/null); if [ -n \"$val\" ]; then cpu_pw=$(awk -v v=\"$val\" 'BEGIN {print v/1000000}'); break; fi; fi; done; echo \"$cpu_pw\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                if (lines.length >= 3) {
                    sysmonPanel.cpuUsage = parseFloat(lines[0]).toFixed(1) + "%"
                    var ramParts = lines[1].split(" ")
                    if (ramParts.length >= 2) {
                        var usedGb = (parseFloat(ramParts[0]) / 1024).toFixed(1)
                        var totalGb = (parseFloat(ramParts[1]) / 1024).toFixed(1)
                        sysmonPanel.ramUsage = usedGb + " / " + totalGb + " GB"
                    }
                    
                    var cpuPower = 0;
                    if (lines.length >= 4 && lines[3].trim() !== "") {
                        cpuPower = parseFloat(lines[3].trim());
                    }
                    
                    var gpuParts = lines[2].split(",")
                    if (gpuParts.length >= 4) {
                        sysmonPanel.gpuUsage = gpuParts[0].trim() + "%"
                        var vramUsedGb = (parseFloat(gpuParts[1].trim()) / 1024).toFixed(1)
                        var vramTotalGb = (parseFloat(gpuParts[2].trim()) / 1024).toFixed(1)
                        sysmonPanel.vramUsage = vramUsedGb + " / " + vramTotalGb + " GB"
                        
                        var gpuPower = parseFloat(gpuParts[3].trim());
                        if (isNaN(gpuPower)) gpuPower = 0;
                        if (isNaN(cpuPower)) cpuPower = 0;
                        
                        var totalPower = gpuPower + cpuPower;
                        sysmonPanel.powerDraw = totalPower.toFixed(0) + " W"
                    }
                }
            }
        }
    }

    // Hide on Escape
    Keys.onPressed: event => {
        if (!expanded) return;
        if (event.key === Qt.Key_Escape) {
            expanded = false;
            event.accepted = true;
        }
    }

    Rectangle {
        id: containerRect
        anchors.centerIn: parent
        implicitHeight: sysmonPanel.implicitHeight
        implicitWidth: sysmonPanel.implicitWidth
        color: Qt.rgba(Theme.dark.base.r, Theme.dark.base.g, Theme.dark.base.b, Theme.moduleOpacity)
        radius: Theme.moduleEdgeRadius + 2
        clip: true

        RowLayout {
            id: contentLayout
            anchors.centerIn: parent
            spacing: 15
            visible: sysmonPanel.expanded

            ResourceItem {
                icon: ""
                value: sysmonPanel.cpuUsage
                itemColor: Theme.textPrimary
            }
            
            Rectangle { width: 1; height: 16; Layout.alignment: Qt.AlignVCenter; color: Theme.divider }

            ResourceItem {
                icon: ""
                value: sysmonPanel.ramUsage
                itemColor: Theme.textPrimary
            }
            
            Rectangle { width: 1; height: 16; Layout.alignment: Qt.AlignVCenter; color: Theme.divider }

            ResourceItem {
                icon: "󰢮"
                value: sysmonPanel.gpuUsage
                itemColor: Theme.textPrimary
            }

            Rectangle { width: 1; height: 16; Layout.alignment: Qt.AlignVCenter; color: Theme.divider }

            ResourceItem {
                icon: "󰍛"
                value: sysmonPanel.vramUsage
                itemColor: Theme.textPrimary
            }

            Rectangle { width: 1; height: 16; Layout.alignment: Qt.AlignVCenter; color: Theme.divider }

            ResourceItem {
                icon: ""
                value: sysmonPanel.powerDraw
                itemColor: Theme.textPrimary
            }
        }
    }

    component ResourceItem : RowLayout {
        property string icon
        property string value
        property color itemColor
        
        spacing: 5
        Layout.alignment: Qt.AlignVCenter
        
        Text {
            text: icon
            color: itemColor
            font.family: Theme.font
            font.pixelSize: 16
        }
        Text {
            text: value
            color: Theme.textPrimary
            font.family: Theme.font
            font.pixelSize: 14
            font.bold: true
        }
    }
}
