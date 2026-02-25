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
    noHoverColorChange: true
    property bool expanded: parentHover.hovered

    HoverHandler { id: parentHover }

    // ── State ──────────────────────────────────────────────────
    property string netIcon:     "󰈀"
    property string netName:     "..."
    property string netState:    "unknown"

    // Bluetooth — live from Quickshell.Bluetooth
    readonly property var   btAdapter:   Bluetooth.defaultAdapter
    readonly property bool  btPowered:   btAdapter ? btAdapter.enabled : false
    readonly property var   btDevices:   btAdapter ? btAdapter.devices : null
    readonly property var   btFirstDev:  (btDevices && btDevices.count > 0) ? btDevices.get(0) : null
    readonly property string btConnected: btFirstDev ? btFirstDev.name : ""

    // ── Sizing ─────────────────────────────────────────────────
    implicitHeight: expanded ? dropdownWindow.height : Theme.moduleHeight
    implicitWidth:  expanded ? dropdownWindow.width : labelRow.implicitWidth + 16

    // ── Collapsed label ────────────────────────────────────────
    RowLayout {
        visible: !controlCenter.expanded
        id: labelRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: controlCenter.netIcon
            color: Theme.textPrimary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.bold: true
        }
        Text {
            text: controlCenter.btPowered
                    ? (controlCenter.btConnected !== "" ? "󰂱" : "󰂯")
                    : "󰂲"
            color: controlCenter.btPowered ? "#80b0ff" : Qt.rgba(0.7,0.5,0.8,0.8)
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.bold: true
        }
    }

    // ── Popup dropdown ─────────────────────────────────────────
    ModuleButton {
        id: dropdownWindow
        visible: controlCenter.expanded
        noHoverColorChange: true

        property bool containsMouse: dropdownHover.hovered

        HoverHandler { id: dropdownHover }

        width:  220
        height: popupCol.implicitHeight + 20

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
            Text {
                text: "  Network"
                color: Theme.accentBorder
                font.family: Theme.font
                font.pixelSize: 11
                font.bold: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: controlCenter.netIcon
                    color: controlCenter.netState === "connected" ? "#a0e0a0" : Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: 18
                    font.bold: true
                }

                ColumnLayout {
                    spacing: 0
                    Text {
                        text: controlCenter.netName
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.maximumWidth: 140
                    }
                    Text {
                        text: controlCenter.netState
                        color: controlCenter.netState === "connected" ? "#a0e0a0" : "#e09090"
                        font.family: Theme.font
                        font.pixelSize: 10
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08) }

            // ── Bluetooth ─────────────────────────────────
            Text {
                text: "  Bluetooth"
                color: Theme.accentBorder
                font.family: Theme.font
                font.pixelSize: 11
                font.bold: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: controlCenter.btPowered
                            ? (controlCenter.btConnected !== "" ? "󰂱" : "󰂯")
                            : "󰂲"
                    color: controlCenter.btPowered ? "#80b0ff" : Qt.rgba(0.6,0.4,0.7,0.7)
                    font.family: Theme.font
                    font.pixelSize: 18
                    font.bold: true
                }

                ColumnLayout {
                    spacing: 0
                    Text {
                        text: controlCenter.btPowered ? "Enabled" : "Disabled"
                        color: controlCenter.btPowered ? "#80b0ff" : Qt.rgba(0.7,0.5,0.8,0.8)
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Text {
                        visible: controlCenter.btConnected !== ""
                        text: controlCenter.btConnected !== "" ? controlCenter.btConnected : " "
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.maximumWidth: 120
                    }
                }

                Item { Layout.fillWidth: true }

                // Toggle switch
                Switch {
                    checked: controlCenter.btPowered
                    onClicked: if (controlCenter.btAdapter) controlCenter.btAdapter.enabled = !controlCenter.btAdapter.enabled
                }
            }

            Item { implicitHeight: 2 }
        }
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
                    return
                }
                var parts = line.split(":")
                controlCenter.netName  = parts[0] || "Unknown"
                controlCenter.netState = (parts[2] || "").toLowerCase().includes("activated") ? "connected" : parts[2] || "unknown"
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
}
