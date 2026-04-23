// Connections — hovers open downward showing network + bluetooth info
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell._Window
import Quickshell.Io
import Quickshell.Bluetooth

import "../elements"

ModuleButton {
    id: connectionsModule
    property bool expanded: false
    noHoverColorChange: expanded ? true : false

    HoverHandler {
        id: parentHover
        onHoveredChanged: {
            if (!parentHover.hovered && expanded) expanded = false
        }
    }
    
    clip: true

    property int cardWidth: Math.max(netRow.implicitWidth, btRow.implicitWidth, mouseRow.implicitWidth, headsetRow.implicitWidth) + 20

    // ── State ──────────────────────────────────────────────────
    property string netIcon:     "󰈀"
    property string netName:     "..."
    property string netState:    "unknown"
    property color netColor:     Theme.textPrimary

    // Bluetooth — live from Quickshell.Bluetooth
    readonly property var   btAdapter:   Bluetooth.defaultAdapter
    readonly property bool  btPowered:   btAdapter ? btAdapter.enabled : false
    readonly property var   btDevices:   btAdapter ? btAdapter.devices : null
    property color btColor:     connectionsModule.btPowered ? Theme.statusBlue : Theme.statusDisabled
    // 1. The master boolean that controls your icon
    property bool btDevicesConnected: false

    // Headset battery
    property bool headsetBatteryAvailable: false
    property int  headsetBatteryPercent: -1
    property string headsetBatteryLabel: "HyprX Cloud II"
    property string headsetBatteryState: "not available"
    property string headsetBatteryPercentLabel: headsetBatteryPercent + "%"
    
    // Mouse battery
    property bool mouseBatteryAvailable: false
    property int  mouseBatteryPercent: -1
    property string mouseBatteryLabel: "Keychron M6"
    property string mouseBatteryState: "not available"
    property string mouseBatteryPercentLabel: mouseBatteryPercent + "%"
    
    property int statusColumnWidth: 60

    // 2. The function that checks if ANY device in our invisible list is connected
    function updateBtStatus() {
        let anyConnected = false;
        for (let i = 0; i < deviceTracker.count; ++i) {
            let trackerObj = deviceTracker.objectAt(i);
            if (trackerObj && trackerObj.isDeviceConnected) {
                anyConnected = true;
                break;
            }
        }
        btDevicesConnected = anyConnected;
    }

    bottomLeftRadius: expanded ? Theme.moduleEdgeRadius + 5 : Theme.moduleRadius
    bottomRightRadius: expanded ? Theme.moduleEdgeRadius + 5 : Theme.moduleRadius
    // 3. The exact same logic as your Repeater, but invisible
    Instantiator {
        id: deviceTracker
        model: connectionsModule.btDevices ? connectionsModule.btDevices : []
        
        // QtObject is the cheapest non-visual element in QML. 
        // It takes zero screen space.
        delegate: QtObject {
            required property var modelData
            
            // THIS is your working logic:
            property bool isDeviceConnected: modelData && modelData.connected === true
            
            // Whenever this specific device changes state, update the master boolean
            onIsDeviceConnectedChanged: updateBtStatus()
            
            // Make sure to check when devices are first added or removed
            Component.onCompleted: updateBtStatus()
            Component.onDestruction: updateBtStatus()
        }
    }

    // 4. Your icon logic
    property string btIcon: connectionsModule.btPowered ? (btDevicesConnected ? "󰂱" : "󰂯") : "󰂲"
    // ── Sizing ─────────────────────────────────────────────────
    implicitHeight: expanded ? baseColumn.implicitHeight : Theme.moduleHeight
    implicitWidth:  expanded ? baseColumn.implicitWidth : labelRow.implicitWidth

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    ColumnLayout {
        id: baseColumn
        anchors { 
            top: parent.top
            right: parent.right
         }
        spacing: 10

        // ── Header / Collapsed State ───────────────────────────────
        PillBarButton {
            id: collapsedRow
            Layout.alignment: Qt.AlignRight
            implicitHeight: Theme.moduleHeight
            implicitWidth: connectionsModule.implicitWidth

            noHoverColorChange: !connectionsModule.expanded
            noPressColorChange: !connectionsModule.expanded
            colorOverride: !connectionsModule.expanded
            
            pillVariant: "neutral"
            percent: connectionsModule.expanded ? 100 : 0

            bottomLeftRadius: connectionsModule.expanded ? Theme.moduleEdgeRadius : 0
            bottomRightRadius: connectionsModule.expanded ? Theme.moduleEdgeRadius : 0

            clip: true
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton

                onPressedChanged: {
                    if (!connectionsModule.expanded) {
                        connectionsModule.pressed = !connectionsModule.pressed
                    } else {
                        collapsedRow.pressed = !collapsedRow.pressed
                    }
                }
                onClicked: {
                    connectionsModule.expanded = !connectionsModule.expanded
                }
            }

            Text {
                visible: connectionsModule.expanded
                text: "Connections"
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
                anchors.centerIn: parent
            }

            RowLayout {
                visible: !connectionsModule.expanded
                id: labelRow
                anchors.centerIn: parent
                spacing: 0

                Text {
                    text: connectionsModule.netIcon
                    color: connectionsModule.netColor
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    leftPadding: Theme.modulePaddingH; rightPadding: 10
                }
                Text {
                    text: connectionsModule.btIcon
                    color: connectionsModule.btColor
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    leftPadding: 10; rightPadding: Theme.modulePaddingH
                }
            }
        }

        // ── Popup dropdown ─────────────────────────────────────────
        ColumnLayout {
            id: popupCol
            implicitWidth: connectionsModule.cardWidth
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 10
            spacing: 5

            Text {
                text: "Hardware"
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: 22
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                Layout.margins: 10
                Layout.topMargin: 0
            }

            // ── Network ──────────────────────────────────
            ModuleButton {
                id: netModule
                visible: connectionsModule.expanded
                color: Theme.divider
                radius: Theme.moduleEdgeRadius

                bottomLeftRadius: 5
                bottomRightRadius: 5

                implicitWidth: connectionsModule.cardWidth
                implicitHeight: netRow.implicitHeight + 20

                RowLayout {
                    id: netRow

                    anchors {
                        left:    parent.left
                        top:     parent.top
                        leftMargin: 10
                        rightMargin: 10
                        topMargin: 10
                        bottomMargin: 10
                    }

                    spacing: 15

                    ModuleButton {
                        id: netStatusIcon
                        label: connectionsModule.netIcon
                        cursorShape: Qt.PointingHandCursor
                        colorOverride: true
                        textColor: connectionsModule.netColor
                        textFont: 24
                        implicitWidth: textFont * 2
                        Layout.preferredWidth: connectionsModule.statusColumnWidth
                        radius: Theme.moduleEdgeRadius
                        onClicked: netOpen.running = true
                    }

                    Rectangle {
                        width: 4
                        Layout.preferredHeight: parent.height * 0.8
                        Layout.alignment: Qt.AlignVCenter
                        color: Theme.textPrimary
                        opacity: 0.5
                        radius: 2
                    }

                    ColumnLayout {
                        id: netInfoCol
                        Layout.margins: 10
                        spacing: 10
                        Text {
                            text: connectionsModule.netName
                            color: Theme.textPrimary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            font.bold: true

                        }
                        Text {
                            text: connectionsModule.netState
                            color: Theme.textPrimary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize * 0.9
                        }
                    }
                }
            }
                            
            // ── Bluetooth ──────────────────────────────────
            ModuleButton {
                id: btModule
                visible: connectionsModule.expanded
                color: Theme.divider
                radius: Theme.moduleEdgeRadius

                topLeftRadius: 5
                topRightRadius: 5

                implicitWidth: connectionsModule.cardWidth
                implicitHeight: btRow.implicitHeight + 20

                RowLayout {
                    id: btRow
                    
                    anchors {
                        left:    parent.left
                        top:     parent.top
                        leftMargin: 10
                        rightMargin: 10
                        topMargin: 10
                        bottomMargin: 10
                    }

                    spacing: 15

                    ColumnLayout {
                        id: btStatusCol
                        Layout.preferredWidth: connectionsModule.statusColumnWidth
                        Layout.topMargin: 10
                        Layout.bottomMargin: 10

                        ModuleButton {
                            label: connectionsModule.btIcon
                            Layout.alignment: Qt.AlignHCenter
                            cursorShape: Qt.PointingHandCursor
                            textColor: connectionsModule.btColor
                            colorOverride: true
                            radius: Theme.moduleEdgeRadius
                            textFont: 24
                            implicitWidth: textFont * 2

                            onClicked: btOpen.running = true
                        }

                        // Custom-styled switch (smaller, themed)
                        Rectangle {
                            id: btSwitch
                            width: 40
                            height: 22
                            radius: height / 2
                            color: connectionsModule.btColor
                            border.color: connectionsModule.btColor
                            border.width: 1
                            Layout.alignment: Qt.AlignHCenter

                            property bool on: connectionsModule.btPowered

                            Rectangle {
                                id: handle
                                width: parent.height - 6
                                height: parent.height - 6
                                y: 3
                                x: btSwitch.on ? parent.width - width - 3 : 3
                                radius: height / 2
                                color: "white"
                                smooth: true
                                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.InOutCubic } }
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (connectionsModule.btAdapter) connectionsModule.btAdapter.enabled = !connectionsModule.btAdapter.enabled
                                }
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }

                    Rectangle {
                        width: 4
                        Layout.preferredHeight: parent.height * 0.8
                        Layout.alignment: Qt.AlignVCenter
                        color: Theme.textPrimary
                        opacity: 0.5
                        radius: 2
                    }

                    ColumnLayout {
                        id: btInfoCol
                        Layout.fillWidth: true
                        Layout.margins: 10
                        spacing: 10

                        Repeater {
                            model: connectionsModule.btDevices ? connectionsModule.btDevices : []
                            delegate: RowLayout {
                                required property var modelData
                                visible: modelData && modelData.connected === true
                                spacing: 10

                                Text {
                                    text: modelData.name
                                    color: Theme.textPrimary
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                }
                                ModuleButton {
                                    variant: "light"
                                    visible: modelData.batteryAvailable
                                    label: modelData.battery * 100 + "%"
                                    radius: Theme.moduleEdgeRadius / 2
                                    implicitHeight: Theme.fontSize + 10
                                    implicitWidth: label.length * (Theme.fontSize * 0.6) + 10
                                    color: modelData.battery > 0.2 ? Theme.statusGreen : Theme.statusRed
                                }

                            }
                        }

                        Text {
                            visible: !connectionsModule.btDevicesConnected
                            text: connectionsModule.btPowered ? "No devices" : "disabled"
                            color: Theme.textPrimary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                        }
                    }
                }
            }

            Text {
                text: "Peripherals"
                color: Theme.textPrimary
                font.family: Theme.font
                font.pixelSize: 22
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                Layout.margins: 10
            }

            // ── Headset ──────────────────────────────────
            ModuleButton {
                id: headsetModule
                visible: connectionsModule.expanded
                color: Theme.divider
                radius: Theme.moduleEdgeRadius

                bottomLeftRadius: 5
                bottomRightRadius: 5

                implicitWidth: connectionsModule.cardWidth
                implicitHeight: headsetRow.implicitHeight + 20
                
                RowLayout {
                    id: headsetRow

                    anchors {
                        left:    parent.left
                        top:     parent.top
                        leftMargin: 10
                        rightMargin: 10
                        topMargin: 10
                        bottomMargin: 10
                    }
                     
                    spacing: 15

                    ModuleButton {
                        label: ""
                        textColor: connectionsModule.headsetBatteryAvailable ? Theme.palettePaper : Theme.statusDisabled
                        cursorShape: Qt.PointingHandCursor
                        colorOverride: true
                        textFont: 24
                        implicitWidth: textFont * 2
                        Layout.preferredWidth: connectionsModule.statusColumnWidth
                        radius: Theme.moduleEdgeRadius
                        onClicked: headsetProc.running = true
                    }

                    Rectangle {
                        width: 4
                        Layout.preferredHeight: parent.height * 0.8
                        Layout.alignment: Qt.AlignVCenter
                        color: Theme.textPrimary
                        opacity: 0.5
                        radius: 2
                    }
                    
                    ColumnLayout {
                        id: headsetInfoCol
                        spacing: 10
                        Layout.margins: 10
                        RowLayout {
                            spacing: 10

                            Text {
                                text: connectionsModule.headsetBatteryLabel
                                color: Theme.textPrimary
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                            }
                            ModuleButton {
                                variant: "light"
                                visible: connectionsModule.headsetBatteryAvailable
                                label: connectionsModule.headsetBatteryPercentLabel
                                implicitHeight: Theme.fontSize + 10
                                implicitWidth: label.length * (Theme.fontSize * 0.6) + 10
                                radius: Theme.moduleEdgeRadius / 2
                                color: connectionsModule.headsetBatteryPercent > 20 ? Theme.statusGreen : Theme.statusRed
                            }

                        }
                        Text {
                            color: Theme.textPrimary
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize * 0.9
                            text: connectionsModule.headsetBatteryState
                        }
                    }
                }
            }

            // ── Mouse ──────────────────────────────────
            ModuleButton {
                id: mouseModule
                visible: connectionsModule.expanded
                color: Theme.divider
                radius: Theme.moduleEdgeRadius

                topLeftRadius: 5
                topRightRadius: 5
                
                implicitWidth: connectionsModule.cardWidth
                implicitHeight: mouseRow.implicitHeight + 20
                
                RowLayout {
                    id: mouseRow

                    anchors {
                        left:    parent.left
                        top:     parent.top
                        leftMargin: 10
                        rightMargin: 10
                        topMargin: 10
                        bottomMargin: 10
                    }
                     
                    spacing: 15

                    ModuleButton {
                        label: "󰍽"
                        textColor: connectionsModule.mouseBatteryAvailable ? Theme.palettePaper : Theme.statusDisabled
                        cursorShape: Qt.PointingHandCursor
                        colorOverride: true
                        textFont: 24
                        implicitWidth: textFont * 2
                        Layout.preferredWidth: connectionsModule.statusColumnWidth
                        radius: Theme.moduleEdgeRadius
                        onClicked: mouseProc.running = true
                    }

                    Rectangle {
                        width: 4
                        Layout.preferredHeight: parent.height * 0.8
                        Layout.alignment: Qt.AlignVCenter
                        color: Theme.textPrimary
                        opacity: 0.5
                        radius: 2
                    }
                    
                    ColumnLayout {
                        id: mouseInfoCol
                        spacing: 10
                        Layout.margins: 10
                        RowLayout {
                            spacing: 10

                            Text {
                                text: connectionsModule.mouseBatteryLabel
                                color: Theme.textPrimary
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                            }
                            ModuleButton {
                                variant: "light"
                                visible: connectionsModule.mouseBatteryAvailable
                                label: connectionsModule.mouseBatteryPercentLabel
                                implicitHeight: Theme.fontSize + 10
                                implicitWidth: label.length * (Theme.fontSize * 0.6) + 10
                                radius: Theme.moduleEdgeRadius / 2
                                color: connectionsModule.mouseBatteryPercent > 20 ? Theme.statusGreen : Theme.statusRed
                            }

                        }
                        Text {
                            color: Theme.textPrimary
                            opacity: 0.8
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize * 0.9
                            text: connectionsModule.mouseBatteryState
                        }
                    }
                }
            }

        }
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }

    // ── Data refresh ───────────────────────────────────────────
    Process {
        id: nmProc
        command: ["bash", "-c",
            "nmcli -t -f NAME,TYPE,STATE connection show --active 2>/dev/null | grep -v loopback | head -1"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var line = text.trim()
                if (line === "") {
                    connectionsModule.netName  = "Disconnected"
                    connectionsModule.netState = "disconnected"
                    connectionsModule.netIcon  = "󰈂"
                    connectionsModule.netColor = Theme.statusRed
                    return
                }
                var parts = line.split(":")
                connectionsModule.netName  = parts[0] || "Unknown"
                connectionsModule.netState = (parts[2] || "").toLowerCase().includes("activated") ? "connected" : parts[2] || "unknown"
                connectionsModule.netColor = connectionsModule.netState === "connected" ? Theme.statusGreen : Theme.statusRed
                var t = (parts[1] || "").toLowerCase()
                if      (t.includes("wifi") || t.includes("802-11"))      connectionsModule.netIcon = "󰤨"
                else if (t.includes("ethernet") || t.includes("802-3"))   connectionsModule.netIcon = "󰈀"
                else                                                       connectionsModule.netIcon = "󰈂"
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: nmProc.running = true
    }

    Process {
        id: netOpen
        // Try nm-connection-editor first, fall back to gnome control center network
        command: ["bash", "-c", "nm-connection-editor || gnome-control-center network || true"]
    }

    Process {
        id: btOpen
        // Try blueman-manager first, fall back to gnome control center bluetooth
        command: ["bash", "-c", "blueman-manager || gnome-control-center bluetooth || true"]
    }

    // Headset battery probe (calls wrapper script)
    Process {
        id: headsetProc
        command: ["bash", "-c", "~/nixos-config/scripts/HyprHeadset/headset-battery 2>/dev/null || true"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var line = text.trim()
                if (line === "") {
                    connectionsModule.headsetBatteryAvailable = false 
                    connectionsModule.headsetBatteryPercent = -1
                    connectionsModule.headsetBatteryState = "not available"
                    return
                }
                // Expected: "Battery: 45%  (Charging)"
                var re = /Battery:\s*(\d+)%\s*\(([^)]+)\)/
                var m = re.exec(line)
                if (m) {
                    connectionsModule.headsetBatteryAvailable = true
                    connectionsModule.headsetBatteryPercent = parseInt(m[1])
                    connectionsModule.headsetBatteryState = m[2]
                } else {
                    connectionsModule.headsetBatteryAvailable = false
                    connectionsModule.headsetBatteryPercent = -1
                    connectionsModule.headsetBatteryState = line
                }
            }
        }
    }

    Timer {
        id: headsetTimer
        interval: 10000
        running: true
        repeat: true
        onTriggered: headsetProc.running = true
    }

    // Mouse battery probe
    Process {
        id: mouseProc
        command: ["bash", "-c", 'f="/tmp/keychron_battery.txt"; head -n 1 "$f" 2>/dev/null; stat -c %Y "$f" 2>/dev/null || echo ""']
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                if (lines.length < 2 || lines[0] === "" || lines[0] === "?") {
                    connectionsModule.mouseBatteryAvailable = false 
                    connectionsModule.mouseBatteryPercent = -1
                    connectionsModule.mouseBatteryState = lines.length > 0 && lines[0] !== "?" && lines[0] !== "" ? lines[0] : "not available"
                    return
                }
                
                var status = lines[0].trim()
                var modTime = parseInt(lines[1].trim())
                var timeAgo = ""
                
                if (!isNaN(modTime)) {
                    var diffMins = Math.floor((Date.now() - (modTime * 1000)) / 60000)
                    if (diffMins < 0) diffMins = 0 // In case of minor clock desync
                    var days = Math.floor(diffMins / 1440)
                    var hours = Math.floor((diffMins % 1440) / 60)
                    var mins = diffMins % 60
                    
                    if (days > 0) timeAgo += days + "d "
                    if (hours > 0) timeAgo += hours + "h "
                    if (mins > 0 || (days === 0 && hours === 0)) timeAgo += mins + "m "
                    timeAgo += "ago"
                }
                
                if (status.endsWith("%")) {
                    connectionsModule.mouseBatteryAvailable = true
                    connectionsModule.mouseBatteryPercent = parseInt(status)
                    connectionsModule.mouseBatteryState = timeAgo
                } else {
                    connectionsModule.mouseBatteryAvailable = false
                    connectionsModule.mouseBatteryPercent = -1
                    connectionsModule.mouseBatteryState = status + (timeAgo ? " (" + timeAgo + ")" : "")
                }
            }
        }
    }

    Timer {
        id: mouseTimer
        interval: 5000
        running: true
        repeat: true
        onTriggered: mouseProc.running = true
    }
}
