// Control Center — hovers open downward showing network + bluetooth info
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell._Window
import Quickshell.Io
import Quickshell.Bluetooth

ModuleButton {
    id: controlCenter
    property bool expanded: parentHover.hovered
    noHoverColorChange: true

    HoverHandler {
        id: parentHover
    }

    // ── State ──────────────────────────────────────────────────
    property string netIcon:     "󰈀"
    property string netName:     "..."
    property string netState:    "unknown"
    property color netColor:     Theme.textPrimary

    // Bluetooth — live from Quickshell.Bluetooth
    readonly property var   btAdapter:   Bluetooth.defaultAdapter
    readonly property bool  btPowered:   btAdapter ? btAdapter.enabled : false
    readonly property var   btDevices:   btAdapter ? btAdapter.devices : null
    property color btColor:     controlCenter.btPowered ? "#80b0ff" : Qt.rgba(0.6,0.4,0.7,0.7)
    // 1. The master boolean that controls your icon
    property bool btDevicesConnected: false

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
    implicitWidth:  expanded ? dropdownMenu.implicitWidth : labelRow.implicitWidth

    // ── Collapsed label ────────────────────────────────────────
    RowLayout {
        visible: !controlCenter.expanded
        id: labelRow
        anchors.centerIn: parent
        spacing: 0


        ModuleButton {
            color: "transparent"
            label: controlCenter.netIcon
            textColor: controlCenter.netColor
        }
        ModuleButton {
            color: "transparent"
            label: controlCenter.btIcon
            textColor: controlCenter.btColor
        }
    }

    // ── Popup dropdown ─────────────────────────────────────────
    ModuleButton {
        id: dropdownMenu
        visible: controlCenter.expanded
        noHoverColorChange: true
        color: "transparent"

        implicitWidth: Math.max(netRow.implicitWidth, btRow.implicitWidth) + 20
        implicitHeight: popupCol.implicitHeight + 20

        ColumnLayout {
            id: popupCol
            anchors {
                left:    parent.left
                right:   parent.right
                top:     parent.top
                margins: 10
            }
            spacing: 8

            // ── Network ──────────────────────────────────
            RowLayout {
                id: netRow
                spacing: 0

                ModuleButton {
                    id: netStatusIcon
                    label: controlCenter.netIcon
                    variant: "transparentDark"
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

            Rectangle { Layout.fillWidth: true; height: 5; color: Qt.rgba(1,1,1,0.08); radius: Theme.moduleEdgeRadius }

            // ── Bluetooth ─────────────────────────────────
            RowLayout {
                id: btRow
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {

                    ModuleButton {
                        label: controlCenter.btIcon
                        textColor: controlCenter.btColor
                        variant: "transparentDark"
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
                        anchors.horizontalCenter: parent.horizontalCenter

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
                            label: modelData.batteryAvailable ? modelData.name + " (" + modelData.battery * 100 + "%)" : modelData.name
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
        }
    }

    Behavior on implicitWidth {
        NumberAnimation { duration: horizontalDuration; easing.type: Easing.OutCubic }
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
                    controlCenter.netIcon  = "󰤭"
                    controlCenter.netColor = "#e09090"
                    return
                }
                var parts = line.split(":")
                controlCenter.netName  = parts[0] || "Unknown"
                controlCenter.netState = (parts[2] || "").toLowerCase().includes("activated") ? "connected" : parts[2] || "unknown"
                controlCenter.netColor = controlCenter.netState === "connected" ? "#a0e0a0" : "#e09090"
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
}
