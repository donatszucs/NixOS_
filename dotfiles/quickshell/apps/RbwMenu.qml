import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "../elements"

Rectangle {
    id: rbwPanel

    property real targetWidth: 400
    property real targetHeight: 480
    property bool expanded: false
    property string screenName: ""
    property int selectedIndex: -1
    property var allItems: []
    property var filteredItems: []

    // Fixed corner cap size — must not depend on animated implicitHeight
    property real cornerSize: targetHeight / 8

    focus: expanded
    color: "transparent"

    // Drop down from below the bar — animate height growth downward
    implicitHeight: expanded ? targetHeight : 0
    implicitWidth: targetWidth + cornerSize * 2
    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }

    // ── IPC trigger (keybind: echo open > /tmp/qs-rbw-<screenName>) ───────
    Process {
        id: rbwListener
        command: ["bash", "-c",
            "rm -f /tmp/qs-rbw-" + rbwPanel.screenName + "; " +
            "mkfifo /tmp/qs-rbw-" + rbwPanel.screenName + "; " +
            "while true; do read -r _ < /tmp/qs-rbw-" + rbwPanel.screenName + " && echo open; done"
        ]
        running: true
        stdout: SplitParser {
            onRead: _ => {
                if (rbwPanel.expanded) {
                    rbwPanel.closeMenu();
                } else {
                    rbwPanel.openMenu();
                }
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
        interval: 200
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
        command: ["bash", "-c", "rbw get \"$0\" | wtype -", itemId]
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
            implicitHeight: rbwPanel.cornerSize
            implicitWidth: rbwPanel.cornerSize
            opacity: Theme.moduleOpacity
            Layout.alignment: Qt.AlignBottom
            expandingV: rbwPanel.expanded
        }
        
        // ── Visual panel (drops below the bar) ────────────────────────────────
        Rectangle {
            id: containerRect
            implicitHeight: rbwPanel.implicitHeight
            Layout.fillWidth: true
            color: Theme.dark.base
            opacity: Theme.moduleOpacity
            topLeftRadius: Theme.moduleEdgeRadius
            topRightRadius: Theme.moduleEdgeRadius
            clip: true

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 20
                }
                spacing: 12

                Text {
                    text: "󰌆 Bitwarden"
                    font.family: Theme.font
                    font.pixelSize: 22
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                // Search field
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    color: Theme.dark.hover
                    radius: Theme.moduleEdgeRadius

                    TextInput {
                        id: searchInput
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 12
                        }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.textPrimary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Search..."
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
                }

                // Results list
                ListView {
                    id: resultsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 5
                    model: rbwPanel.filteredItems

                    delegate: ModuleButton {
                        width: resultsList.width
                        height: modelData.user ? 54 : 44
                        variant: "light"
                        colorOverride: index === rbwPanel.selectedIndex
                        overrideColor: "white"
                        radius: Theme.moduleEdgeRadius

                        Column {
                            anchors {
                                verticalCenter: parent.verticalCenter
                                left: parent.left
                                right: parent.right
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 2

                            Text {
                                width: parent.width
                                text: modelData.name
                                color: parent.textColor
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: modelData.user
                                color: parent.textColor
                                opacity: 0.5
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 2
                                elide: Text.ElideRight
                                visible: modelData.user !== ""
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

                ModuleButton {
                    label: "Close"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rbwPanel.closeMenu()
                    radius: Theme.moduleEdgeRadius
                }
            }
        }

        // Inverse radius caps at the bar edge (top of the dropping panel)
        InverseRadius {
            cornerPosition: "bottomLeft"
            implicitHeight: rbwPanel.cornerSize
            implicitWidth: rbwPanel.cornerSize
            color: Theme.dark.base
            opacity: Theme.moduleOpacity
            Layout.alignment: Qt.AlignBottom
            expandingV: rbwPanel.expanded
        }
}
}
