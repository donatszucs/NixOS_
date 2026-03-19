// Control Center — hovers open downward showing network + bluetooth info
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell._Window
import Quickshell.Io
import Quickshell.Bluetooth

import "../elements"

ModuleButton {
    id: controlCenter
    opacity: Theme.moduleOpacity
    property bool expanded: false
    noHoverColorChange: expanded ? true : false

    HoverHandler {
        id: parentHover
        onHoveredChanged: {
            if (!parentHover.hovered && expanded) expanded = false
        }
    }
    
    cursorShape: Qt.PointingHandCursor
    onClicked: expanded = !expanded
    // ── State ──────────────────────────────────────────────────
    property string netIcon:     "󰈀"
    property string netName:     "..."
    property string netState:    "unknown"
    property color netColor:     Theme.textPrimary

    // Bluetooth — live from Quickshell.Bluetooth
    readonly property var   btAdapter:   Bluetooth.defaultAdapter
    readonly property bool  btPowered:   btAdapter ? btAdapter.enabled : false
    readonly property var   btDevices:   btAdapter ? btAdapter.devices : null
    property color btColor:     controlCenter.btPowered ? Theme.statusBlue : Theme.statusDisabled
    // 1. The master boolean that controls your icon
    property bool btDevicesConnected: false

    // Headset battery
    property bool headsetBatteryAvailable: false
    property int  headsetBatteryPercent: -1
    property string headsetBatteryState: "not available"
    property string headsetBatteryLabel: headsetBatteryPercent >= 0 ? ( "HyprX Cloud II: " + headsetBatteryPercent + "%") : "HyprX Cloud II"

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

    bottomLeftRadius: expanded ? Theme.moduleEdgeRadius : Theme.moduleRadius
    bottomRightRadius: expanded ? Theme.moduleEdgeRadius : Theme.moduleRadius
    // 3. The exact same logic as your Repeater, but invisible
    Instantiator {
        id: deviceTracker
        model: controlCenter.btDevices ? controlCenter.btDevices : []
        
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
    property string btIcon: controlCenter.btPowered ? (btDevicesConnected ? "󰂱" : "󰂯") : "󰂲"
    // ── Sizing ─────────────────────────────────────────────────
    implicitHeight: expanded ? dropdownMenu.implicitHeight : Theme.moduleHeight
    implicitWidth:  expanded ? Math.ceil(dropdownMenu.implicitWidth) : Math.ceil(labelRow.implicitWidth)

    // ── Collapsed label ────────────────────────────────────────
    RowLayout {
        visible: !controlCenter.expanded
        id: labelRow
        anchors.centerIn: parent
        spacing: 0

        Text {
            text: controlCenter.netIcon
            color: controlCenter.netColor
            font.family: Theme.font
            
            // Add padding here if your ModuleButton had specific padding
            leftPadding: Theme.modulePaddingH; rightPadding: 10
    }
        Text {
            text: controlCenter.btIcon
            color: controlCenter.btColor
            font.family: Theme.font
            leftPadding: 10; rightPadding: Theme.modulePaddingH
        }
    }

    // ── Popup dropdown ─────────────────────────────────────────
    ModuleButton {
        id: dropdownMenu
        visible: controlCenter.expanded
        noHoverColorChange: true
        color: "transparent"

        implicitWidth: Math.max(netRow.implicitWidth, btRow.implicitWidth, headsetRow.implicitWidth) + 20
        implicitHeight: popupCol.implicitHeight + 10

        ColumnLayout {
            id: popupCol
            anchors {
                left:    parent.left
                right:   parent.right
                top:     parent.top
                leftMargin: 10
                rightMargin: 10
                topMargin: 0
                bottomMargin: 0
            }
            spacing: 8

            ModuleButton {
                visible: controlCenter.expanded
                implicitWidth: parent.width
                implicitHeight: Theme.moduleHeight
                label: "Control Center"
                
                bottomLeftRadius: Theme.moduleEdgeRadius
                bottomRightRadius: Theme.moduleEdgeRadius

                cursorShape: Qt.PointingHandCursor
                onClicked: controlCenter.expanded = false
            }

            // ── Network ──────────────────────────────────
            RowLayout {
                id: netRow
                spacing: 0

                ModuleButton {
                    id: netStatusIcon
                    label: controlCenter.netIcon
                    cursorShape: Qt.PointingHandCursor
                    colorOverride: true
                    textColor: controlCenter.netColor
                    textFont: 24
                    rightMargin: 6
                    implicitWidth: textFont * 2
                    radius: Theme.moduleEdgeRadius
                    onClicked: netOpen.running = true
                }

                ColumnLayout {
                    id: netInfoCol
                    spacing: 0
                    ModuleButton {
                        label: controlCenter.netName
                        color: "transparent"
                        textColor: controlCenter.netColor

                    }
                    ModuleButton {
                        label: controlCenter.netState
                        color: "transparent"
                        textColor: controlCenter.netColor
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 5; color: Theme.divider; radius: Theme.moduleEdgeRadius }

            // ── Bluetooth ─────────────────────────────────
            RowLayout {
                id: btRow
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {

                    ModuleButton {
                        label: controlCenter.btIcon
                        cursorShape: Qt.PointingHandCursor
                        textColor: controlCenter.btColor
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
                        color: controlCenter.btColor
                        border.color: controlCenter.btColor
                        border.width: 1
                        Layout.alignment: Qt.AlignHCenter

                        property bool on: controlCenter.btPowered

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
                                if (controlCenter.btAdapter) controlCenter.btAdapter.enabled = !controlCenter.btAdapter.enabled
                            }
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true

                    Repeater {
                        model: controlCenter.btDevices ? controlCenter.btDevices : []
                        delegate: ModuleButton {
                            required property var modelData
                            label: modelData.batteryAvailable ? modelData.name + ": " + modelData.battery * 100 + "%" : modelData.name
                            color: "transparent"
                            textColor: Theme.textPrimary
                            visible: modelData && modelData.connected === true
                        }
                    }

                    ModuleButton {
                        visible: !controlCenter.btDevicesConnected
                        label: controlCenter.btPowered ? "No devices" : "disabled"
                        color: "transparent"
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 5; color: Theme.divider; radius: Theme.moduleEdgeRadius }

            // ── Headset ──────────────────────────────────
            RowLayout {
                id: headsetRow
                spacing: 0

                ModuleButton {
                    label: ""
                    textColor: controlCenter.headsetBatteryAvailable ? (controlCenter.headsetBatteryPercent > 20 ? Theme.statusGreen : Theme.statusRed) : Theme.textPrimary
                    cursorShape: Qt.PointingHandCursor
                    colorOverride: true
                    textFont: 24
                    rightMargin: 8
                    implicitWidth: textFont * 2
                    radius: Theme.moduleEdgeRadius
                    onClicked: headsetProc.running = true
                }
                
                ColumnLayout {
                    spacing: 0
                    ModuleButton {
                        color: "transparent"
                        textColor: Theme.textPrimary
                        label: controlCenter.headsetBatteryLabel
                    }
                    ModuleButton {
                        color: "transparent"
                        textColor: Theme.textPrimary
                        label: controlCenter.headsetBatteryState
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 5; color: Theme.divider; radius: Theme.moduleEdgeRadius }

            // ── System actions ─────────────────────────────
            RowLayout {
            id: sysRow
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 15

                Text {
                    text: "NixOS"
                    color: Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: 22
                    font.bold: true
                }

                ModuleButton {
                    label: "󰚰"
                    textFont: 24

                    rightMargin: 4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: updateProc.running = true

                    implicitWidth: implicitHeight

                    radius: Theme.moduleEdgeRadius
                }
                
                ModuleButton {
                    label: "󱄅"
                    textFont: 24
                    rightMargin: 6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rebuildProc.running = true

                    implicitWidth: implicitHeight

                    radius: Theme.moduleEdgeRadius
                }
            }
        }
    }

    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
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
                    controlCenter.netName  = "Disconnected"
                    controlCenter.netState = "disconnected"
                    controlCenter.netIcon  = "󰈂"
                    controlCenter.netColor = Theme.statusRed
                    return
                }
                var parts = line.split(":")
                controlCenter.netName  = parts[0] || "Unknown"
                controlCenter.netState = (parts[2] || "").toLowerCase().includes("activated") ? "connected" : parts[2] || "unknown"
                controlCenter.netColor = controlCenter.netState === "connected" ? Theme.statusGreen : Theme.statusRed
                var t = (parts[1] || "").toLowerCase()
                if      (t.includes("wifi") || t.includes("802-11"))      controlCenter.netIcon = "󰤨"
                else if (t.includes("ethernet") || t.includes("802-3"))   controlCenter.netIcon = "󰈀"
                else                                                       controlCenter.netIcon = "󰈂"
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


    Process {
        id: rebuildProc
        command: ["bash", "-c", "kitty -e bash -lc 'cd ~/nixos-config && sudo nixos-rebuild switch --flake .#doni --impure; notify-send 'Rebuild finished'"]
    }

    Process {
        id: updateProc
        command: ["bash", "-c", "kitty -e bash -lc 'cd ~/nixos-config && sudo nix flake update; notify-send 'Flake update finished'"]
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
                    controlCenter.headsetBatteryAvailable = false 
                    controlCenter.headsetBatteryPercent = -1
                    controlCenter.headsetBatteryState = "not available"
                    return
                }
                // Expected: "Battery: 45%  (Charging)"
                var re = /Battery:\s*(\d+)%\s*\(([^)]+)\)/
                var m = re.exec(line)
                if (m) {
                    controlCenter.headsetBatteryAvailable = true
                    controlCenter.headsetBatteryPercent = parseInt(m[1])
                    controlCenter.headsetBatteryState = m[2]
                } else {
                    controlCenter.headsetBatteryAvailable = false
                    controlCenter.headsetBatteryPercent = -1
                    controlCenter.headsetBatteryState = line
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
}
