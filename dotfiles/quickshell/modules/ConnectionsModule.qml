// Connections — hovers open downward showing network + bluetooth info
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell._Window
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth

import "../elements"

ExpandableModule {
    id: connectionsModule
    property int currentPage: 0


    property int cardWidth: 280
    property int textMaxWidth: cardWidth - 40

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
    property bool showUnpairedDevices: false
    onBtPoweredChanged: {
        if (!btPowered) showUnpairedDevices = false;
        if (btPowered && btAdapter) {
            try { btAdapter.pairable = true; } catch (e) {}
        }
    }

    // Bluetooth device icon helper
    function getBtDeviceIcon(iconName, isConnected, isBusy) {
        if (isBusy) return "󰑐";
        var ic = (iconName || "").toLowerCase();
        if (ic.indexOf("headset") !== -1 || ic.indexOf("headphone") !== -1 || ic.indexOf("audio") !== -1) return "󰋋";
        if (ic.indexOf("mouse") !== -1) return "󰍽";
        if (ic.indexOf("keyboard") !== -1) return "󰌌";
        if (ic.indexOf("gaming") !== -1 || ic.indexOf("gamepad") !== -1 || ic.indexOf("joystick") !== -1) return "󰊴";
        if (ic.indexOf("phone") !== -1) return "󰏲";
        if (ic.indexOf("computer") !== -1 || ic.indexOf("laptop") !== -1) return "󰌢";
        return isConnected ? "󰂱" : "󰂯";
    }

    // Bluetooth device helpers
    function pairBtDevice(addr) {
        if (!addr) return;
        if (btAdapter) {
            try { btAdapter.pairable = true; } catch (e) {}
        }
        Quickshell.execDetached(["bash", "-c", "bluetoothctl pair " + addr + " && bluetoothctl trust " + addr + " && bluetoothctl connect " + addr]);
    }

    function cancelPairBtDevice(addr) {
        if (!addr) return;
        Quickshell.execDetached(["bash", "-c", "pkill -f 'bluetoothctl.*" + addr + "' || true"]);
    }

    function trustBtDevice(dev) {
        if (!dev) return;
        var addr = "";
        if (typeof dev === "string") {
            addr = dev;
        } else {
            try {
                dev.trusted = true;
            } catch (e) {}
            addr = dev.address || "";
        }
        if (addr && addr.length > 0) {
            Quickshell.execDetached(["bluetoothctl", "trust", addr]);
        }
    }

    function untrustBtDevice(dev) {
        if (!dev) return;
        var addr = "";
        if (typeof dev === "string") {
            addr = dev;
        } else {
            try {
                dev.trusted = false;
            } catch (e) {}
            addr = dev.address || "";
        }
        if (addr && addr.length > 0) {
            Quickshell.execDetached(["bluetoothctl", "untrust", addr]);
        }
    }

    // Headset battery
    property bool headsetBatteryAvailable: false
    property int  headsetBatteryPercent: -1
    property string headsetBatteryLabel: "HyprX Cloud II"
    property string headsetBatteryState: "not available"
    property string headsetBatteryPercentLabel: headsetBatteryPercent + "%"
    
    // Mouse battery & status
    property bool   mouseBatteryAvailable: false
    property int    mouseBatteryPercent: -1
    property string mouseBatteryLabel: "Keychron M6S"
    property string mouseBatteryState: "not available"
    property string mouseBatteryPercentLabel: mouseBatteryPercent + "%"
    property string mouseStatus: "disconnected"
    property bool   mouseCharging: false
    property bool   mousePollingActive: false
    
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
    // ── Standard pill setup ──────────────────────────────────────
    pillPercent: 0
    pillVariant: "neutral"
    expandedPillLabel: "Connections"

    // ── Sizing ─────────────────────────────────────────────────
    implicitHeight: expanded ? baseColumn.implicitHeight + Theme.moduleHeight + connectionsModule.titleBarHeight + 15 : Theme.moduleHeight

    collapsedWidth: 65

    // Overlay dropdown setup
    expandedDropdownWidth: cardWidth + 30
    dropdownAlignment: "center"

    leftCornerStyle: "side"
    rightCornerStyle: "side"

    // Collapsed content inside the base pill
    Row {
        id: labelRow
        parent: connectionsModule.headerPill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: Math.round(Theme.moduleHeight / 2)
        height: implicitHeight
        spacing: 12
        z: 6

        opacity: connectionsModule.expanded ? 0.0 : 1.0
        visible: opacity > 0
        Behavior on opacity { 
            NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } 
        }

        Text {
            text: connectionsModule.netIcon
            color: connectionsModule.netColor
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 1
        }
        Text {
            text: connectionsModule.btIcon
            color: connectionsModule.btColor
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 1
        }
    }

    ColumnLayout {
        id: baseColumn
        parent: connectionsModule.overlay
        anchors { 
            top: parent.top
            topMargin: connectionsModule.titleBarHeight
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 10


        scale: expanded ? 1 : 0
        transformOrigin: Item.Top
        Behavior on scale { NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

        // ── Popup dropdown ─────────────────────────────────────────
        MouseArea {
            visible: connectionsModule.contentVisible
            opacity: connectionsModule.contentOpacity
            implicitWidth: connectionsModule.cardWidth
            Layout.preferredWidth: connectionsModule.cardWidth
            Layout.preferredHeight: popupCol.implicitHeight
            Layout.alignment: Qt.AlignHCenter

            acceptedButtons: Qt.NoButton
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) {
                    if (connectionsModule.currentPage !== 1) connectionsModule.currentPage = 1
                    else connectionsModule.currentPage = 0
                }
                else if (wheel.angleDelta.y < 0) {
                    if (connectionsModule.currentPage !== 0) connectionsModule.currentPage = 0
                    else connectionsModule.currentPage = 1
                }
            }

            ColumnLayout {
                id: popupCol
                width: parent.width
                spacing: 10

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.margins: 10
                spacing: 20

                Text {
                    text: "Hardware"
                    color: Theme.textPrimary
                    opacity: connectionsModule.currentPage === 0 ? 1.0 : 0.5
                    font.family: Theme.font
                    font.pixelSize: 18
                    font.bold: true
                    
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: connectionsModule.currentPage = 0
                    }
                }

                Text {
                    text: "Peripherals"
                    color: Theme.textPrimary
                    opacity: connectionsModule.currentPage === 1 ? 1.0 : 0.5
                    font.family: Theme.font
                    font.pixelSize: 18
                    font.bold: true
                    
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: connectionsModule.currentPage = 1
                    }
                }
            }

            // ── Network ──────────────────────────────────
            BaseCard {
                id: netModule
                visible: connectionsModule.contentVisible && connectionsModule.currentPage === 0
                Layout.fillWidth: true
                implicitWidth: connectionsModule.cardWidth
                implicitHeight: headerBar.height + netContentCol.implicitHeight + 20
                hasHeader: true

                headerContent: [
                    Text {
                        id: netStatusIcon
                        text: connectionsModule.netIcon
                        color: connectionsModule.netColor
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 2
                        anchors.left: parent.left
                        anchors.leftMargin: 15
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: netOpen.running = true
                        }
                    },

                    Text {
                        id: netTitle
                        text: "Network"
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 1
                        font.bold: true
                        anchors.centerIn: parent
                    }
                ]

                ColumnLayout {
                    id: netContentCol
                    anchors {
                        top: netModule.headerBar.bottom
                        left: parent.left
                        right: parent.right
                        margins: 15
                        topMargin: 10
                    }
                    spacing: 4

                    HoverMarqueeText {
                        text: connectionsModule.netName
                        textMaxWidth: connectionsModule.cardWidth - 30
                        Layout.fillWidth: true
                    }

                    Text {
                        text: connectionsModule.netState
                        color: Theme.textPrimary
                        opacity: 0.7
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize * 0.9
                    }
                }
            }
                            
            // ── Bluetooth ──────────────────────────────────
            BaseCard {
                id: btModule
                visible: connectionsModule.contentVisible && connectionsModule.currentPage === 0
                Layout.fillWidth: true
                implicitWidth: connectionsModule.cardWidth
                implicitHeight: headerBar.height + btInfoCol.implicitHeight + 20
                hasHeader: true

                headerContent: [
                    Text {
                        id: btStatusIcon
                        text: connectionsModule.btIcon
                        color: connectionsModule.btColor
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 2
                        anchors.left: parent.left
                        anchors.leftMargin: 15
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: btOpen.running = true
                        }
                    },

                    Text {
                        id: btTitle
                        text: "Bluetooth"
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 1
                        font.bold: true
                        anchors.centerIn: parent
                    },

                    // Custom-styled switch (smaller, themed)
                    Rectangle {
                        id: btSwitch
                        width: 34
                        height: 22
                        radius: height / 2
                        color: connectionsModule.btColor
                        border.color: connectionsModule.btColor
                        border.width: 1
                        anchors.right: parent.right
                        anchors.rightMargin: 15
                        anchors.verticalCenter: parent.verticalCenter

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
                ]

                ColumnLayout {
                    id: btInfoCol
                    anchors {
                        top: btModule.headerBar.bottom
                        left: parent.left
                        right: parent.right
                        margins: 12
                        topMargin: 10
                    }
                    spacing: 5

                    ModuleButton {
                        id: toggleUnpairedBtn
                        variant: "light"
                        visible: connectionsModule.btPowered
                        label: connectionsModule.showUnpairedDevices 
                            ? (connectionsModule.btAdapter && connectionsModule.btAdapter.discovering ? "󰑐 Scanning..." : " Hide Unpaired") 
                            : " Scan & Pair Devices"
                        implicitHeight: 26
                        textFont: Theme.fontSize * 0.8
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 5
                        radius: Theme.moduleEdgeRadius / 2
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            connectionsModule.showUnpairedDevices = !connectionsModule.showUnpairedDevices;
                            if (connectionsModule.btAdapter) {
                                connectionsModule.btAdapter.discovering = connectionsModule.showUnpairedDevices;
                                if (connectionsModule.showUnpairedDevices) {
                                    try { connectionsModule.btAdapter.pairable = true; } catch (e) {}
                                }
                            }
                        }
                    }

                    Repeater {
                        id: pairedDeviceRepeater
                        model: connectionsModule.btPowered && connectionsModule.btDevices ? connectionsModule.btDevices : []
                        delegate: ModuleButton {
                            id: pairedDeviceBtn
                            required property var modelData

                            visible: modelData && modelData.paired
                            variant: "neutral"

                            readonly property bool isConnected: modelData && (modelData.connected === true || modelData.state === 1)
                            readonly property bool isConnecting: modelData && (modelData.state === 3)
                            readonly property bool isDisconnecting: modelData && (modelData.state === 2)
                            readonly property bool isBusy: isConnecting || isDisconnecting

                            readonly property string statusText: {
                                if (!modelData) return "";
                                if (isConnecting) return "Connecting...";
                                if (isDisconnecting) return "Disconnecting...";
                                if (isConnected) return "Connected";
                                return "Paired";
                            }

                            readonly property color statusColor: {
                                if (isConnecting) return Theme.statusBlue;
                                if (isDisconnecting) return Theme.statusDisabled;
                                if (isConnected) return Theme.statusGreen;
                                return Theme.statusDisabled;
                            }

                            Layout.fillWidth: true
                            implicitHeight: 46
                            radius: Theme.moduleEdgeRadius / 2 + 5
                            opacity: 1.0
                            border.width: 2
                            border.color: (isConnected || isBusy) ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.35) : borderColorAdaptive
                            cursorShape: isBusy ? Qt.WaitCursor : Qt.PointingHandCursor

                            function doConnect() {
                                connectionsModule.trustBtDevice(modelData);
                                if (typeof modelData.connect === "function") modelData.connect();
                                else modelData.connected = true;
                            }

                            function doDisconnect() {
                                if (typeof modelData.disconnect === "function") modelData.disconnect();
                                else modelData.connected = false;
                            }

                            function doForget() {
                                connectionsModule.untrustBtDevice(modelData);
                                if (typeof modelData.forget === "function") modelData.forget();
                            }

                            Component.onCompleted: {
                                if (modelData && modelData.paired && !modelData.trusted) {
                                    connectionsModule.trustBtDevice(modelData);
                                }
                            }

                            Connections {
                                target: modelData
                                function onPairedChanged() {
                                    if (modelData && modelData.paired && !modelData.trusted) {
                                        connectionsModule.trustBtDevice(modelData);
                                    }
                                }
                            }

                            onClicked: {
                                if (isBusy) return;
                                if (isConnected) doDisconnect();
                                else doConnect();
                            }

                            RowLayout {
                                id: pairedDeviceRow
                                anchors.fill: parent
                                anchors.rightMargin: 6
                                spacing: 12

                                Rectangle {
                                    id: pairedIconBox
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: pairedDeviceBtn.implicitHeight
                                    implicitWidth: pairedDeviceBtn.implicitHeight
                                    implicitHeight: pairedDeviceBtn.implicitHeight
                                    color: (isConnected || isBusy) ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.35) : Theme.divider
                                    topLeftRadius: pairedDeviceBtn.radius
                                    bottomLeftRadius: pairedDeviceBtn.radius

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
                                        text: connectionsModule.getBtDeviceIcon(modelData.icon, isConnected, isBusy)
                                        color: isConnected ? Theme.statusBlue : (isBusy ? Theme.statusBlue : Theme.textPrimary)
                                        opacity: isConnected || isBusy ? 1.0 : 0.7
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize + 3
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter

                                        rotation: isBusy ? spinAnim.angle : 0

                                        NumberAnimation {
                                            id: spinAnim
                                            property real angle: 0
                                            target: spinAnim
                                            property: "angle"
                                            from: 0
                                            to: 360
                                            duration: 900
                                            loops: Animation.Infinite
                                            running: isBusy
                                            onStopped: angle = 0
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2

                                    HoverMarqueeText {
                                        text: modelData.name || modelData.deviceName || "Unknown Device"
                                        textMaxWidth: connectionsModule.cardWidth - rightActionsRow.implicitWidth - 85
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: statusText
                                        color: statusColor
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize * 0.75
                                        font.bold: isConnected || isBusy
                                    }
                                }

                                RowLayout {
                                    id: rightActionsRow
                                    spacing: 6
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.rightMargin: 6

                                    ModuleButton {
                                        id: pairedDeviceBatteryBtn
                                        variant: "light"
                                        visible: modelData.batteryAvailable
                                        label: Math.round(modelData.battery * 100) + "%"
                                        radius: Theme.moduleEdgeRadius / 2
                                        implicitHeight: 20
                                        implicitWidth: label.length * (Theme.fontSize * 0.6) + 12
                                        color: modelData.battery > 0.2 ? Theme.statusGreen : Theme.statusRed
                                    }

                                    // Forget / Unpair button on hover
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: forgetHover.hovered ? Qt.rgba(1, 0.3, 0.3, 0.3) : Qt.rgba(1, 1, 1, 0.1)
                                        visible: pairedDeviceBtn.hovered && !isBusy

                                        HoverHandler { id: forgetHover }

                                        Text {
                                            anchors.centerIn: parent
                                            text: ""
                                            color: forgetHover.hovered ? Theme.statusRed : Theme.textPrimary
                                            font.family: Theme.font
                                            font.pixelSize: 11
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: doForget()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: connectionsModule.btPowered && connectionsModule.showUnpairedDevices
                        text: "Available Devices"
                        color: Theme.textPrimary
                        opacity: 0.5
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize * 0.75
                        font.bold: true
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.leftMargin: 4
                    }

                    Repeater {
                        id: unpairedDeviceRepeater
                        model: connectionsModule.btPowered && connectionsModule.btDevices ? connectionsModule.btDevices : []
                        delegate: ModuleButton {
                            id: unpairedDeviceBtn
                            required property var modelData

                            visible: connectionsModule.showUnpairedDevices && modelData && !modelData.paired
                            variant: "neutral"

                            readonly property bool isPairing: modelData && (modelData.pairing === true)
                            readonly property bool isConnecting: modelData && (modelData.state === 3)
                            readonly property bool isBusy: isPairing || isConnecting

                            readonly property string statusText: {
                                if (!modelData) return "";
                                if (isPairing) return "Pairing...";
                                if (isConnecting) return "Connecting...";
                                return "Ready to pair";
                            }

                            Layout.fillWidth: true
                            implicitHeight: 46
                            radius: Theme.moduleEdgeRadius / 2 + 5
                            opacity: isBusy ? 1.0 : 0.8
                            border.width: 2
                            border.color: isBusy ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.35) : borderColorAdaptive
                            cursorShape: isBusy ? Qt.WaitCursor : Qt.PointingHandCursor

                            function doPair() {
                                if (isBusy) return;
                                if (connectionsModule.btAdapter) {
                                    try { connectionsModule.btAdapter.pairable = true; } catch (e) {}
                                }
                                if (typeof modelData.pair === "function") {
                                    try { modelData.pair(); } catch (e) {}
                                }
                                if (modelData && modelData.address) {
                                    connectionsModule.pairBtDevice(modelData.address);
                                }
                            }

                            function doCancelPair() {
                                if (typeof modelData.cancelPair === "function") {
                                    try { modelData.cancelPair(); } catch (e) {}
                                }
                                if (modelData && modelData.address) {
                                    connectionsModule.cancelPairBtDevice(modelData.address);
                                }
                            }

                            function doConnect() {
                                if (typeof modelData.connect === "function") modelData.connect();
                                else modelData.connected = true;
                            }

                            // Auto-trust and auto-connect once pairing completes successfully
                            Connections {
                                target: modelData
                                function onPairedChanged() {
                                    if (modelData && modelData.paired) {
                                        connectionsModule.trustBtDevice(modelData);
                                        if (!modelData.connected) {
                                            doConnect();
                                        }
                                    }
                                }
                            }

                            onClicked: {
                                if (!isBusy) doPair();
                            }

                            RowLayout {
                                id: unpairedDeviceRow
                                anchors.fill: parent
                                anchors.rightMargin: 6
                                spacing: 12

                                Rectangle {
                                    id: unpairedIconBox
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: unpairedDeviceBtn.implicitHeight
                                    implicitWidth: unpairedDeviceBtn.implicitHeight
                                    implicitHeight: unpairedDeviceBtn.implicitHeight
                                    color: isBusy ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.35) : Theme.divider
                                    topLeftRadius: unpairedDeviceBtn.radius
                                    bottomLeftRadius: unpairedDeviceBtn.radius

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
                                        id: unpairedIconText
                                        anchors.centerIn: parent
                                        text: connectionsModule.getBtDeviceIcon(modelData.icon, false, isBusy)
                                        color: isBusy ? Theme.statusBlue : Theme.textPrimary
                                        opacity: isBusy ? 1.0 : 0.6
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize + 3
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter

                                        rotation: isBusy ? unpairedSpinAnim.angle : 0

                                        NumberAnimation {
                                            id: unpairedSpinAnim
                                            property real angle: 0
                                            target: unpairedSpinAnim
                                            property: "angle"
                                            from: 0
                                            to: 360
                                            duration: 900
                                            loops: Animation.Infinite
                                            running: isBusy
                                            onStopped: angle = 0
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 2

                                    HoverMarqueeText {
                                        text: modelData.name || modelData.deviceName || modelData.address || "Unknown Device"
                                        textMaxWidth: connectionsModule.cardWidth - unpairedRightActions.implicitWidth - 85
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: statusText
                                        color: isBusy ? Theme.statusBlue : Theme.statusDisabled
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize * 0.75
                                        font.bold: isBusy
                                    }
                                }

                                RowLayout {
                                    id: unpairedRightActions
                                    spacing: 6
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.rightMargin: 6

                                    Rectangle {
                                        id: pairActionBtn
                                        implicitHeight: 22
                                        implicitWidth: isPairing ? 56 : 48
                                        radius: Theme.moduleEdgeRadius / 2
                                        color: isPairing ? Qt.rgba(Theme.statusRed.r, Theme.statusRed.g, Theme.statusRed.b, 0.25)
                                                         : (pairActionHover.hovered ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.25) : Qt.rgba(1, 1, 1, 0.12))
                                        border.width: 1
                                        border.color: isPairing ? Theme.statusRed : (pairActionHover.hovered ? Theme.statusBlue : Theme.divider)

                                        HoverHandler { id: pairActionHover }

                                        Text {
                                            anchors.centerIn: parent
                                            text: isPairing ? "Cancel" : "Pair"
                                            color: isPairing ? Theme.statusRed : (pairActionHover.hovered ? Theme.statusBlue : Theme.textPrimary)
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize * 0.75
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: (mouse) => {
                                                mouse.accepted = true;
                                                if (isPairing) doCancelPair();
                                                else doPair();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: !connectionsModule.btPowered || pairedDeviceRepeater.count === 0
                        text: connectionsModule.btPowered ? "No devices" : "disabled"
                        color: !connectionsModule.btPowered ? Theme.statusDisabled : Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: connectionsModule.btPowered
                        font.italic: !connectionsModule.btPowered
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.topMargin: 5
                        Layout.bottomMargin: 5
                    }
                }
            }

            // ── Headset ──────────────────────────────────
            BaseCard {
                id: headsetModule
                visible: connectionsModule.contentVisible && connectionsModule.currentPage === 1
                Layout.fillWidth: true
                implicitWidth: connectionsModule.cardWidth
                implicitHeight: headerBar.height + headsetContentCol.implicitHeight + 20
                hasHeader: true

                headerContent: [
                    Text {
                        id: headsetIcon
                        text: ""
                        color: connectionsModule.headsetBatteryAvailable ? Theme.palettePaper : Theme.statusDisabled
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 2
                        anchors.left: parent.left
                        anchors.leftMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                    },

                    Text {
                        id: headsetTitle
                        text: "Headset"
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 1
                        font.bold: true
                        anchors.centerIn: parent
                    },

                    ModuleButton {
                        id: headsetBatteryBtn
                        variant: "neutral"
                        visible: connectionsModule.headsetBatteryAvailable
                        label: connectionsModule.headsetBatteryPercentLabel
                        implicitHeight: 24
                        implicitWidth: label.length * (Theme.fontSize * 0.6) + 14
                        radius: Theme.cardButtonRadius
                        color: connectionsModule.headsetBatteryPercent > 20 ? Theme.statusGreen : Theme.statusRed
                        anchors.right: parent.right
                        anchors.rightMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                ]

                ColumnLayout {
                    id: headsetContentCol
                    anchors {
                        top: headsetModule.headerBar.bottom
                        left: parent.left
                        right: parent.right
                        margins: 15
                        topMargin: 10
                    }
                    spacing: 4

                    HoverMarqueeText {
                        text: connectionsModule.headsetBatteryLabel
                        textMaxWidth: connectionsModule.cardWidth - 30
                        Layout.fillWidth: true
                    }

                    Text {
                        color: Theme.textPrimary
                        opacity: 0.7
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize * 0.9
                        text: connectionsModule.headsetBatteryState
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft
                    }
                }
            }

            // ── Mouse ──────────────────────────────────
            BaseCard {
                id: mouseModule
                visible: connectionsModule.contentVisible && connectionsModule.currentPage === 1
                Layout.fillWidth: true
                implicitWidth: connectionsModule.cardWidth
                implicitHeight: headerBar.height + mouseContentCol.implicitHeight + 20
                hasHeader: true

                headerContent: [
                    Text {
                        id: mouseIcon
                        text: "󰍽"
                        color: connectionsModule.mouseBatteryAvailable ? Theme.palettePaper : Theme.statusDisabled
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 2
                        anchors.left: parent.left
                        anchors.leftMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: connectionsModule.mousePollingActive ? 0.35 : 1.0

                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: connectionsModule.triggerMousePoll()
                        }
                    },

                    Text {
                        id: mouseTitle
                        text: "Mouse"
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 1
                        font.bold: true
                        anchors.centerIn: parent
                    },

                    ModuleButton {
                        id: mouseBatteryBtn
                        variant: "light"
                        visible: connectionsModule.mouseBatteryAvailable
                        cursorShape: Qt.PointingHandCursor
                        label: connectionsModule.mouseCharging
                            ? ("󱐋 " + connectionsModule.mouseBatteryPercentLabel)
                            : connectionsModule.mouseBatteryPercentLabel
                        implicitHeight: 24
                        implicitWidth: label.length * (Theme.fontSize * 0.6) + 16
                        radius: Theme.cardButtonRadius
                        color: connectionsModule.mouseCharging
                            ? Theme.statusGreen
                            : (connectionsModule.mouseBatteryPercent > 20 ? Theme.statusGreen : Theme.statusRed)
                        anchors.right: parent.right
                        anchors.rightMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: connectionsModule.triggerMousePoll()
                    }
                ]

                ColumnLayout {
                    id: mouseContentCol
                    anchors {
                        top: mouseModule.headerBar.bottom
                        left: parent.left
                        right: parent.right
                        margins: 15
                        topMargin: 10
                    }
                    spacing: 4

                    HoverMarqueeText {
                        text: connectionsModule.mouseBatteryLabel
                        textMaxWidth: connectionsModule.cardWidth - 30
                        Layout.fillWidth: true
                    }

                    // Status line with color-coded dot & timestamp
                    RowLayout {
                        spacing: 6
                        Layout.fillWidth: true

                        Rectangle {
                            width: 7
                            height: 7
                            radius: 3.5
                            color: connectionsModule.mouseCharging
                                ? Theme.statusGreen
                                : (connectionsModule.mouseStatus === "connected"
                                    ? Theme.statusGreen
                                    : (connectionsModule.mouseStatus === "idle"
                                        ? Theme.paletteYellow
                                        : (connectionsModule.mouseStatus === "off"
                                            ? Theme.paletteYellow
                                            : Theme.statusDisabled)))
                        }

                        Text {
                            color: Theme.textPrimary
                            opacity: 0.85
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize * 0.85
                            text: {
                                if (connectionsModule.mousePollingActive) {
                                    return "Polling..."
                                } else if (connectionsModule.mouseCharging) {
                                    return "Charging"
                                } else if (connectionsModule.mouseStatus === "connected") {
                                    return "Active"
                                } else if (connectionsModule.mouseStatus === "idle") {
                                    return "Idle (Standby)"
                                } else if (connectionsModule.mouseStatus === "off") {
                                    return "Dongle Connected (Mouse Off)"
                                } else {
                                    return "Dongle Disconnected"
                                }
                            }
                            elide: Text.ElideRight
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            color: Theme.textPrimary
                            opacity: 0.5
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize * 0.75
                            text: connectionsModule.mouseBatteryState
                            elide: Text.ElideRight
                        }
                    }
                }
            }

        }
        }
    }


    // ── Data refresh ───────────────────────────────────────────
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var devs = (Networking.devices && Networking.devices.values) ? Networking.devices.values : [];
            var bestDev = null;
            var bestNet = null;
            
            for (var i = 0; i < devs.length; i++) {
                var d = devs[i];
                if (d && d.connected) {
                    bestDev = d;
                    // DeviceType.Wifi is 1, DeviceType.Wired is 2
                    if (d.type === DeviceType.Wifi || d.type === 1) {
                        var nets = (d.networks && d.networks.values) ? d.networks.values : [];
                        for (var j = 0; j < nets.length; j++) {
                            var net = nets[j];
                            if (net && net.connected) {
                                bestNet = net;
                                break;
                            }
                        }
                    } else if (d.type === DeviceType.Wired || d.type === 2) {
                        bestNet = null;
                    }
                    if (bestNet) break;
                }
            }
            
            if (bestDev) {
                connectionsModule.netName  = bestNet ? bestNet.name : ((bestDev.type === DeviceType.Wired || bestDev.type === 2) ? "Ethernet" : bestDev.name);
                connectionsModule.netState = "connected";
                connectionsModule.netColor = Theme.statusGreen;
                if (bestDev.type === DeviceType.Wifi || bestDev.type === 1) {
                    connectionsModule.netIcon = "󰤨";
                } else if (bestDev.type === DeviceType.Wired || bestDev.type === 2) {
                    connectionsModule.netIcon = "󰈀";
                } else {
                    connectionsModule.netIcon = "󰈂";
                }
            } else {
                connectionsModule.netName  = "Disconnected";
                connectionsModule.netState = "disconnected";
                connectionsModule.netIcon  = "󰈂";
                connectionsModule.netColor = Theme.statusRed;
            }
        }
    }

    Process {
        id: netOpen
        // Try nm-connection-editor first, fall back to gnome control center network
        command: ["bash", "-c", "nm-connection-editor || gnome-control-center network || true"]
    }

    Process {
        id: btOpen
        // Try blueman-manager first, fall back to gnome control center bluetooth
        command: ["bash", "-c", " overskride || blueman-manager || gnome-control-center bluetooth || true"]
    }

    Process {
        id: mousePollProcess
        command: ["sh", "-c", "mouse_monitor poll || ~/.nix-profile/bin/mouse_monitor poll"]
        onRunningChanged: {
            if (!running) {
                connectionsModule.mousePollingActive = false;
                peripheralsFile.reload();
                updatePeripherals();
            }
        }
    }

    Timer {
        id: mousePollSafetyTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (connectionsModule.mousePollingActive) {
                connectionsModule.mousePollingActive = false;
                peripheralsFile.reload();
                updatePeripherals();
            }
        }
    }

    function triggerMousePoll() {
        if (mousePollingActive) return;
        mousePollingActive = true;
        mousePollSafetyTimer.restart();
        mousePollProcess.running = true;
    }

    // Peripheral JSON reader (RAM-based, instantaneous via FileView)
    FileView {
        id: peripheralsFile
        path: "/tmp/mouse_state.json"
        blockLoading: true
        watchChanges: true
        onLoaded: updatePeripherals()
        onFileChanged: updatePeripherals()
        onTextChanged: updatePeripherals()
    }

    function updatePeripherals() {
        var txt = peripheralsFile.text()
        if (!txt || txt.trim() === "") {
            connectionsModule.mouseBatteryAvailable = false
            connectionsModule.mouseBatteryPercent = -1
            connectionsModule.mouseBatteryState = "not available"
            return
        }

        try {
            var data = JSON.parse(txt)
            if (data.name) {
                connectionsModule.mouseBatteryLabel = data.name
            } else {
                connectionsModule.mouseBatteryLabel = "Keychron M6S"
            }
            if (data.battery !== undefined && data.battery !== null && data.battery >= 0) {
                connectionsModule.mouseBatteryAvailable = true
                connectionsModule.mouseBatteryPercent = data.battery

                var timeAgo = ""
                var updatedSec = data.updated
                if (updatedSec && !isNaN(updatedSec)) {
                    var diffMins = Math.floor((Date.now() - (updatedSec * 1000)) / 60000)
                    if (diffMins <= 0) {
                        timeAgo = "just now"
                    } else {
                        var days = Math.floor(diffMins / 1440)
                        var hours = Math.floor((diffMins % 1440) / 60)
                        var mins = diffMins % 60

                        if (days > 0) timeAgo += days + "d "
                        if (hours > 0) timeAgo += hours + "h "
                        if (mins > 0 || (days === 0 && hours === 0)) timeAgo += mins + "m "
                        timeAgo += "ago"
                    }
                } else {
                    timeAgo = "recently"
                }
                connectionsModule.mouseBatteryState = timeAgo
            } else {
                connectionsModule.mouseBatteryAvailable = false
                connectionsModule.mouseBatteryPercent = -1
                connectionsModule.mouseBatteryState = "Disconnected"
            }
            connectionsModule.mouseStatus = data.status || (connectionsModule.mouseBatteryAvailable ? "connected" : "disconnected")
            connectionsModule.mouseCharging = !!data.charging
        } catch (e) {
            connectionsModule.mouseBatteryAvailable = false
            connectionsModule.mouseBatteryPercent = -1
            connectionsModule.mouseBatteryState = "not available"
            connectionsModule.mouseStatus = "disconnected"
            connectionsModule.mouseCharging = false
        }
    }

    Timer {
        id: peripheralsTimer
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            peripheralsFile.reload()
            updatePeripherals()
        }
    }

    Component.onCompleted: {
        updatePeripherals();
        if (btAdapter && btPowered) {
            try { btAdapter.pairable = true; } catch (e) {}
        }
    }
}
