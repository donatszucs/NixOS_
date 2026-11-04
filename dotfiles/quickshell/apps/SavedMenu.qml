import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

import "../elements"

Rectangle {
    id: savedPanel

    property real targetHeight: 48
    property bool expanded: false
    property string screenName: ""
    property var slots: []
    property int selectedIndex: -1

    focus: expanded
    color: "transparent"

    // Drops up from the bottom screen edge — animate height growth upward
    implicitHeight: expanded ? targetHeight : 0
    implicitWidth: mainLayout.implicitWidth

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    // ── IPC trigger (keybind: quickshell ipc call savedmenu-<screenName> toggle) ──
    IpcHandler {
        target: "savedmenu-" + savedPanel.screenName
        function toggle(): void {
            if (savedPanel.expanded) {
                savedPanel.closeMenu();
            } else {
                savedPanel.openMenu();
            }
        }
        function add(): void {
            savedPanel.triggerAddClipboard();
        }
    }

    // ── Keyboard handling ──────────────────────────────────────────────────
    Keys.onPressed: event => {
        if (!expanded) return;

        if (event.key === Qt.Key_Escape) {
            savedPanel.closeMenu();
            event.accepted = true;
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            var slotNum = event.key - Qt.Key_1;
            if (slotNum < savedPanel.slots.length) {
                var itm = savedPanel.slots[slotNum];
                savedPanel.pasteSlot(typeof itm === "string" ? itm : itm.text);
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
            savedPanel.triggerAddClipboard();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            if (savedPanel.slots.length > 0) {
                if (savedPanel.selectedIndex <= 0) savedPanel.selectedIndex = savedPanel.slots.length - 1;
                else savedPanel.selectedIndex--;
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            if (savedPanel.slots.length > 0) {
                if (savedPanel.selectedIndex >= savedPanel.slots.length - 1) savedPanel.selectedIndex = 0;
                else savedPanel.selectedIndex++;
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (savedPanel.selectedIndex >= 0 && savedPanel.selectedIndex < savedPanel.slots.length) {
                var selItem = savedPanel.slots[savedPanel.selectedIndex];
                savedPanel.pasteSlot(typeof selItem === "string" ? selItem : selItem.text);
            }
            event.accepted = true;
        }
    }

    // ── Public API ─────────────────────────────────────────────────────────
    function openMenu() {
        savedPanel.loadSlots();
        savedPanel.expanded = true;
        savedPanel.selectedIndex = -1;
        savedPanel.forceActiveFocus();
    }

    function closeMenu() {
        savedPanel.expanded = false;
        savedPanel.selectedIndex = -1;
    }

    function pasteSlot(textToPaste) {
        if (!textToPaste) return;
        savedPanel.closeMenu();
        applyPasteProc.targetText = textToPaste;
        applyPasteTimer.start();
    }

    function removeSlot(index) {
        if (index >= 0 && index < savedPanel.slots.length) {
            var list = savedPanel.slots.slice();
            list.splice(index, 1);
            savedPanel.slots = list;
            savedPanel.saveSlots();
        }
    }

    function triggerAddClipboard() {
        savedPanel.clipboardAccumulator = "";
        readClipboardProc.running = true;
    }

    function addSlot(newText) {
        if (!newText || newText.trim() === "") {
            return;
        }

        var list = savedPanel.slots.slice();
        var filtered = list.filter(function(item) {
            var existing = typeof item === "string" ? item : item.text;
            return existing !== newText;
        });

        filtered.push({
            "text": newText,
            "label": newText
        });

        savedPanel.slots = filtered;
        savedPanel.saveSlots();
    }

    // ── Persistence: Load & Save ───────────────────────────────────────────
    property string loadAccumulator: ""

    Process {
        id: loadProc
        command: [
            "bash",
            "-c",
            "if [ -f \"$HOME/.local/state/quickshell/saved_slots.json\" ]; then cat \"$HOME/.local/state/quickshell/saved_slots.json\"; else echo '[]'; fi"
        ]
        stdout: SplitParser {
            onRead: line => {
                savedPanel.loadAccumulator += line + "\n";
            }
        }
        onExited: (code, status) => {
            if (code === 0 && savedPanel.loadAccumulator.trim().length > 0) {
                try {
                    var parsed = JSON.parse(savedPanel.loadAccumulator);
                    if (Array.isArray(parsed)) {
                        savedPanel.slots = parsed.map(function(item) {
                            if (typeof item === "string") {
                                return { text: item, label: item };
                            }
                            return item;
                        });
                    }
                } catch(e) {
                    console.log("Error reading saved_slots.json:", e);
                }
            }
            savedPanel.loadAccumulator = "";
        }
    }

    function loadSlots() {
        savedPanel.loadAccumulator = "";
        loadProc.running = true;
    }

    Process {
        id: saveProc
        property string jsonData: "[]"
        command: [
            "bash",
            "-c",
            "mkdir -p \"$HOME/.local/state/quickshell\" && printf '%s' \"$0\" > \"$HOME/.local/state/quickshell/saved_slots.json\"",
            jsonData
        ]
    }

    function saveSlots() {
        saveProc.jsonData = JSON.stringify(savedPanel.slots, null, 2);
        saveProc.running = true;
    }

    // ── Clipboard capture ──────────────────────────────────────────────────
    property string clipboardAccumulator: ""

    Process {
        id: readClipboardProc
        command: ["wl-paste", "--no-newline"]
        stdout: SplitParser {
            onRead: line => {
                if (savedPanel.clipboardAccumulator.length > 0) savedPanel.clipboardAccumulator += "\n";
                savedPanel.clipboardAccumulator += line;
            }
        }
        onExited: (code, status) => {
            if (code === 0 && savedPanel.clipboardAccumulator.length > 0) {
                savedPanel.addSlot(savedPanel.clipboardAccumulator);
            }
            savedPanel.clipboardAccumulator = "";
        }
    }

    // ── Paste execution ────────────────────────────────────────────────────
    Timer {
        id: applyPasteTimer
        interval: 60
        repeat: false
        onTriggered: {
            applyPasteProc.running = true;
        }
    }

    Process {
        id: applyPasteProc
        property string targetText: ""
        command: [
            "bash",
            "-c",
            "printf '%s' \"$0\" | wl-copy && sleep 0.08 && wtype -M ctrl -k v -m ctrl",
            targetText
        ]
    }

    Component.onCompleted: {
        savedPanel.loadSlots();
    }

    // ── Main Layout with InverseRadius Wings (Attached to Bottom Screen Edge) ──
    RowLayout {
        id: mainLayout
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        height: savedPanel.implicitHeight
        spacing: 0

        // Left inverse radius wing (joining bottom screen edge to panel)
        InverseRadius {
            id: leftWing
            cornerPosition: "bottomRight"
            size: Math.round(savedPanel.targetHeight / 2)
            color: containerRect.color
            Layout.alignment: Qt.AlignBottom
            expandingV: savedPanel.expanded
            expandingH: savedPanel.expanded
        }

        // ── Visual panel with solid/translucent background & borderless ────
        Rectangle {
            id: containerRect
            implicitHeight: savedPanel.implicitHeight
            implicitWidth: contentRow.implicitWidth + 24
            color: Qt.rgba(Theme.dark.base.r, Theme.dark.base.g, Theme.dark.base.b, Theme.moduleOpacity)
            topLeftRadius: Theme.expandedModuleRadius - Theme.pillExpandedMargin
            topRightRadius: Theme.expandedModuleRadius - Theme.pillExpandedMargin
            bottomLeftRadius: 0
            bottomRightRadius: 0
            border.width: 0
            clip: true

            Behavior on implicitWidth {
                NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }

            RowLayout {
                id: contentRow
                anchors.centerIn: parent
                spacing: 6

                // Empty state hint
                Text {
                    visible: savedPanel.slots.length === 0
                    text: "No saved items (click + to add clipboard)"
                    color: Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    opacity: 0.55
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 6
                    Layout.rightMargin: 4
                }

                // Saved slots horizontal list using basic ModuleButtons
                Row {
                    id: slotsRow
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter
                    visible: savedPanel.slots.length > 0

                    Repeater {
                        model: savedPanel.slots

                        delegate: ModuleButton {
                            id: slotBtn
                            required property int index
                            required property var modelData

                            readonly property string itemText: typeof modelData === "string" ? modelData : modelData.text
                            readonly property bool isEmoji: itemText.length <= 2
                            readonly property bool isSelected: savedPanel.selectedIndex === index

                            variant: isSelected ? "light" : "neutral"
                            radius: height / 2
                            border.width: 0

                            implicitHeight: 32
                            implicitWidth: isEmoji ? 38 : Math.min(180, Math.max(52, marqueeItem.implicitWidth + 24))
                            label: isEmoji ? itemText : ""
                            textFont: 18
                            cursorShape: Qt.PointingHandCursor
                            Layout.alignment: Qt.AlignVCenter

                            // Marquee scrolling text for longer snippets
                            HoverMarqueeText {
                                id: marqueeItem
                                visible: !slotBtn.isEmoji
                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, slotBtn.width - 20)

                                text: slotBtn.itemText
                                textMaxWidth: 156
                                textColor: slotBtn.textColor
                                fontFamily: Theme.font
                                pixelSize: Theme.fontSize - 1
                                fontBold: true
                                forceHovered: slotBtn.hovered
                                horizontalAlignment: Text.AlignHCenter
                            }

                            onClicked: {
                                savedPanel.pasteSlot(itemText)
                            }

                            TapHandler {
                                acceptedButtons: Qt.RightButton
                                onTapped: {
                                    savedPanel.removeSlot(index)
                                }
                            }
                        }
                    }
                }

                // ── Plus (+) Button using basic ModuleButton ───────────────
                ModuleButton {
                    id: addBtn
                    variant: "light"
                    radius: height / 2
                    border.width: 0
                    implicitHeight: 32
                    implicitWidth: 36
                    label: "󰐕"
                    textFont: Theme.fontSize + 2
                    cursorShape: Qt.PointingHandCursor
                    Layout.alignment: Qt.AlignVCenter

                    onClicked: {
                        savedPanel.triggerAddClipboard()
                    }
                }
            }
        }

        // Right inverse radius wing (joining bottom screen edge to panel)
        InverseRadius {
            id: rightWing
            cornerPosition: "bottomLeft"
            size: Math.round(savedPanel.targetHeight / 2)
            color: containerRect.color
            Layout.alignment: Qt.AlignBottom
            expandingV: savedPanel.expanded
            expandingH: savedPanel.expanded
        }
    }
}
