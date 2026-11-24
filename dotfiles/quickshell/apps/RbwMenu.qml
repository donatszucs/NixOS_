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
            } else if (!SharedState.vramSavingMode) {
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

                    // Search field styled like card items with left icon bay
                    ListButton {
                        id: searchBox
                        Layout.fillWidth: true
                        implicitHeight: 42
                        clickable: false
                        hoverEnabled: false
                        icon: "󰍉"
                        iconSize: Theme.fontSize + 2
                        variant: searchInput.activeFocus ? "blue" : "light"
                        active: searchInput.activeFocus

                        content: TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
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

                        trailing: HeaderButton {
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

                                delegate: ListButton {
                                    width: resultsList.width
                                    implicitWidth: resultsList.width
                                    height: Theme.listHeight
                                    implicitHeight: Theme.listHeight

                                    highlighted: index === rbwPanel.selectedIndex
                                    hoverEnabled: false
                                    icon: "󰌋"
                                    iconSize: Theme.fontSize + 3
                                    text: modelData.name
                                    subtext: modelData.user !== "" ? modelData.user : "No username"
                                    subtextOpacity: modelData.user !== "" ? 0.6 : 0.4
                                    trailingIcon: "󰌑"
                                    rightPadding: 12

                                    onEntered: rbwPanel.selectedIndex = index
                                    onClicked: rbwPanel.executeAutofill(modelData.id)
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
