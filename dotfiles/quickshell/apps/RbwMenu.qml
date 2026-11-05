import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

import "../elements"

Rectangle {
    id: rbwPanel

    property real targetWidth: 600
    property real targetHeight: 400
    property bool expanded: false
    property string screenName: ""
    property int selectedIndex: -1
    property var allItems: []
    property var filteredItems: []

    focus: expanded
    color: "transparent"

    // Drop down from below the bar — animate height growth downward
    implicitHeight: expanded ? targetHeight : 0
    implicitWidth: targetWidth
    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutQuint }
    }

    // ── IPC trigger (keybind: quickshell ipc call rbw-<screenName> toggle) ───────
    IpcHandler {
        target: "rbw-" + rbwPanel.screenName
        function toggle(): void {
            if (rbwPanel.expanded) {
                rbwPanel.closeMenu();
            } else {
                rbwPanel.openMenu();
            }
        }
    }

    // ── Fetch vault item list ──────────────────────────────────────────────
    // Each item: { id: string, name: string, user: string }
    Process {
        id: rbwLs
        command: ["rbw", "list", "--fields", "id,name,user"]
        stdout: SplitParser {
            onRead: line => {
                var l = line.trim();
                if (l === "") return;
                var parts = l.split("\t");
                var item = {
                    id:   parts[0] ? parts[0].trim() : "",
                    name: parts[1] ? parts[1].trim() : l,
                    user: parts[2] ? parts[2].trim() : ""
                };
                rbwPanel.allItems = rbwPanel.allItems.concat([item]);
            }
        }
        onExited: (code, _) => {
            if (code !== 0) return; // vault may be locked
            rbwPanel.filteredItems = rbwPanel.allItems.slice();
            rbwPanel.expanded = true;
            rbwPanel.selectedIndex = rbwPanel.filteredItems.length > 0 ? 0 : -1;
            resultsList.currentIndex = rbwPanel.selectedIndex;
            searchInput.forceActiveFocus();
        }
    }

    // ── Autofill: close panel first, then type into the previously focused window
    Timer {
        id: autofillTimer
        interval: 100
        repeat: false
        property string pendingItem: ""
        onTriggered: {
            autofillProc.itemId = pendingItem;
            autofillProc.running = true;
        }
    }

    Process {
        id: autofillProc
        property string itemId: ""
        command: ["bash", "-c", "pass=$(rbw get \"$0\") && sleep 0.1 && printf '%s' \"$pass\" | wtype -", itemId]
    }

    // ── Keyboard navigation ────────────────────────────────────────────────
    Keys.onPressed: event => {
        if (!expanded) return;
        if (event.key === Qt.Key_Down) {
            if (rbwPanel.selectedIndex < rbwPanel.filteredItems.length - 1)
                rbwPanel.selectedIndex++;
            else
                rbwPanel.selectedIndex = 0;
            resultsList.currentIndex = rbwPanel.selectedIndex;
            resultsList.positionViewAtIndex(rbwPanel.selectedIndex, ListView.Visible);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            if (rbwPanel.selectedIndex > 0)
                rbwPanel.selectedIndex--;
            else
                rbwPanel.selectedIndex = rbwPanel.filteredItems.length - 1;
            resultsList.currentIndex = rbwPanel.selectedIndex;
            resultsList.positionViewAtIndex(rbwPanel.selectedIndex, ListView.Visible);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (rbwPanel.selectedIndex >= 0 && rbwPanel.filteredItems.length > 0) {
                rbwPanel.executeAutofill(rbwPanel.filteredItems[rbwPanel.selectedIndex].id);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            rbwPanel.closeMenu();
            event.accepted = true;
        }
    }

    // ── Public API ─────────────────────────────────────────────────────────
    function openMenu() {
        rbwPanel.allItems = [];
        rbwPanel.filteredItems = [];
        searchInput.text = "";
        rbwLs.running = true;
    }

    function closeMenu() {
        rbwPanel.expanded = false;
        rbwPanel.selectedIndex = -1;
        searchInput.text = "";
    }

    function executeAutofill(itemId) {
        closeMenu();
        autofillTimer.pendingItem = itemId;
        autofillTimer.start();
    }
    RowLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: 0

        InverseRadius {
            cornerPosition: "bottomRight"
            sizeV: targetHeight / 4
            sizeH: targetWidth / 8
            color: containerRect.color
            Layout.alignment: Qt.AlignBottom
            expandingV: rbwPanel.expanded
            expandingH: rbwPanel.expanded
        }
        
        // ── Visual panel (drops below the bar) ────────────────────────────────
        Rectangle {
            id: containerRect
            implicitHeight: rbwPanel.implicitHeight
            Layout.fillWidth: true
            color: Qt.rgba(Theme.dark.base.r, Theme.dark.base.g, Theme.dark.base.b, Theme.moduleOpacity)
            topLeftRadius: Theme.expandedModuleRadius - Theme.pillExpandedMargin
            topRightRadius: Theme.expandedModuleRadius - Theme.pillExpandedMargin
            clip: true

            BaseCard {
                id: mainCard
                anchors.fill: parent
                anchors.margins: Theme.cardMargin
                hasHeader: true
                headerIcon: "󰌆"
                headerTitle: "Bitwarden"

                headerControls: [
                    Rectangle {
                        implicitHeight: 20
                        implicitWidth: vaultCountText.implicitWidth + 10
                        radius: 10
                        color: Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.2)
                        visible: rbwPanel.allItems.length > 0
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: vaultCountText
                            anchors.centerIn: parent
                            text: rbwPanel.filteredItems.length + (rbwPanel.filteredItems.length === 1 ? " login" : " logins")
                            color: Theme.statusBlue
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize * 0.7
                            font.bold: true
                        }
                    },

                    HeaderButton {
                        icon: "󰅖"
                        iconSize: Theme.fontSize + 1
                        onClicked: rbwPanel.closeMenu()
                    }
                ]

                ColumnLayout {
                    id: cardBodyCol
                    anchors {
                        top: mainCard.headerBar.bottom
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                        margins: Theme.cardPadding
                    }
                    spacing: 8

                    // Search field styled like card items with left icon box
                    Rectangle {
                        id: searchBox
                        Layout.fillWidth: true
                        implicitHeight: 42
                        color: Theme.palette("neutral").base
                        radius: Theme.cardItemRadius
                        border.width: 2
                        border.color: searchInput.activeFocus
                            ? Qt.rgba(Theme.palettePaper.r, Theme.palettePaper.g, Theme.palettePaper.b, 0.55)
                            : Theme.palette("neutral").border
                        Behavior on border.color { ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.rightMargin: 10
                            spacing: 12

                            Rectangle {
                                Layout.fillHeight: true
                                Layout.preferredWidth: 42
                                implicitWidth: 42
                                color: searchInput.activeFocus
                                    ? Qt.rgba(Theme.statusBlue.r, Theme.statusBlue.g, Theme.statusBlue.b, 0.28)
                                    : Theme.divider
                                Behavior on color { ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }
                                topLeftRadius: Math.min(height / 2, searchBox.radius)
                                bottomLeftRadius: Math.min(height / 2, searchBox.radius)

                                InverseRadius {
                                    anchors.top: parent.top
                                    anchors.left: parent.right
                                    cornerPosition: "topLeft"
                                    color: parent.color
                                    size: Theme.cardItemIconInverseRadius
                                }

                                InverseRadius {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.right
                                    cornerPosition: "bottomLeft"
                                    color: parent.color
                                    size: Theme.cardItemIconInverseRadius
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰍉"
                                    color: searchInput.activeFocus ? Theme.statusBlue : Theme.textPrimary
                                    opacity: searchInput.activeFocus ? 1.0 : 0.75
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize + 2
                                    font.bold: true
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                TextInput {
                                    id: searchInput
                                    anchors.fill: parent
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Theme.textPrimary
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                    clip: true

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: "Search vault..."
                                        color: Theme.textPrimary
                                        opacity: 0.5
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize
                                        font.bold: false
                                        visible: !searchInput.text.length
                                    }

                                    onTextChanged: {
                                        var q = text.toLowerCase();
                                        rbwPanel.filteredItems = q.length === 0
                                            ? rbwPanel.allItems.slice()
                                            : rbwPanel.allItems.filter(i =>
                                                i.name.toLowerCase().includes(q) ||
                                                i.user.toLowerCase().includes(q)
                                            );
                                        rbwPanel.selectedIndex = rbwPanel.filteredItems.length > 0 ? 0 : -1;
                                        resultsList.currentIndex = rbwPanel.selectedIndex;
                                    }

                                    // Forward arrow keys / enter / escape to the panel
                                    Keys.forwardTo: [rbwPanel]
                                }
                            }

                            HeaderButton {
                                visible: searchInput.text.length > 0
                                icon: "󰅖"
                                iconSize: 13
                                implicitWidth: 22
                                implicitHeight: 22
                                onClicked: {
                                    searchInput.text = "";
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }
                    }

                    // Results list container with rounded mask
                    Item {
                        id: resultsContainer
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Item {
                            id: resultsMask
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true
                            layer.smooth: true

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.cardItemRadius
                                color: "black"
                            }
                        }

                        Item {
                            anchors.fill: parent
                            layer.enabled: true
                            layer.smooth: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: resultsMask
                            }

                            ListView {
                                id: resultsList
                                anchors.fill: parent
                                clip: true
                                spacing: 5
                                model: rbwPanel.filteredItems

                                delegate: ModuleButton {
                                    id: parentButton
                                    width: resultsList.width
                                    implicitWidth: resultsList.width
                                    height: Theme.listHeight
                                    implicitHeight: Theme.listHeight

                                    readonly property bool isSelected: index === rbwPanel.selectedIndex
                                    variant: isSelected ? "light" : "neutral"
                                    noHoverColorChange: true
                                    radius: Theme.cardItemRadius
                                    label: ""
                                    border.width: 2

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.rightMargin: 12
                                        spacing: 12

                                        Rectangle {
                                            id: loginIconBox
                                            Layout.fillHeight: true
                                            Layout.preferredWidth: 46
                                            implicitWidth: 46
                                            color: parentButton.isSelected
                                                ? Qt.rgba(Theme.paletteInk.r, Theme.paletteInk.g, Theme.paletteInk.b, 0.14)
                                                : Theme.divider
                                            Behavior on color { ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic } }
                                            topLeftRadius: Math.min(height / 2, parentButton.radius)
                                            bottomLeftRadius: Math.min(height / 2, parentButton.radius)

                                            InverseRadius {
                                                anchors.top: parent.top
                                                anchors.left: parent.right
                                                cornerPosition: "topLeft"
                                                color: parent.color
                                                size: Theme.cardItemIconInverseRadius
                                            }

                                            InverseRadius {
                                                anchors.bottom: parent.bottom
                                                anchors.left: parent.right
                                                cornerPosition: "bottomLeft"
                                                color: parent.color
                                                size: Theme.cardItemIconInverseRadius
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰌋"
                                                color: parentButton.textColor
                                                opacity: parentButton.isSelected ? 0.95 : 0.75
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontSize + 3
                                                font.bold: true
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 2

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.name
                                                color: parentButton.textColor
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontSize
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.user !== "" ? modelData.user : "No username"
                                                color: parentButton.textColor
                                                opacity: modelData.user !== "" ? (parentButton.isSelected ? 0.75 : 0.6) : 0.4
                                                font.family: Theme.font
                                                font.pixelSize: Math.round(Theme.fontSize * 0.75)
                                                font.bold: false
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Text {
                                            text: "󰌑"
                                            color: parentButton.textColor
                                            opacity: parentButton.isSelected ? 0.8 : 0.0
                                            visible: opacity > 0
                                            Behavior on opacity { NumberAnimation { duration: 150 } }
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize + 1
                                            font.bold: true
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: rbwPanel.selectedIndex = index
                                        onClicked: rbwPanel.executeAutofill(modelData.id)
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: rbwPanel.filteredItems.length === 0 && !rbwLs.running
                            spacing: 8

                            Text {
                                text: "󰌆"
                                font.family: Theme.font
                                font.pixelSize: 32
                                color: Theme.textPrimary
                                opacity: 0.35
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: searchInput.text.length > 0 ? "No matching logins" : "Vault is empty"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                                color: Theme.textPrimary
                                opacity: 0.65
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }
        }

        // Inverse radius caps at the bar edge (top of the dropping panel)
        InverseRadius {
            cornerPosition: "bottomLeft"
            sizeV: targetHeight / 4
            sizeH: targetWidth / 8
            color: containerRect.color
            Layout.alignment: Qt.AlignBottom
            expandingV: rbwPanel.expanded
            expandingH: rbwPanel.expanded
        }
}
}
