// App Launcher — expands downward with search + installed app list
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Hyprland

import "../elements"

ModuleButton {
    id: launcherModule
    label: ""
    noHoverColorChange: expanded
    noPressColorChange: true
    property bool expanded: false
    property string screenName: ""


    property int  panelWidth:  400
    property int  maxVisible:  8
    property int  padding:    10

    // JS array of DesktopEntry objects matching the current search
    property var filteredApps: []

    bottomLeftRadius:  expanded ? Theme.moduleEdgeRadius + 5 : Theme.moduleRadius
    bottomRightRadius: expanded ? Theme.moduleEdgeRadius + 5 : Theme.moduleRadius
    
    clip: true

    implicitWidth:  expanded ? panelWidth : collapsedRow.implicitWidth
    implicitHeight: expanded ? dropPanel.implicitHeight : Theme.moduleHeight

    Behavior on implicitWidth  { NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: Theme.verticalDuration;   easing.type: Easing.OutCubic } }

    // ── Helpers ───────────────────────────────────────────────────
    function filterApps(query) {
        var q = query.toLowerCase()
        var all = DesktopEntries.applications.values
        var result = []
        for (var i = 0; i < all.length; i++) {
            var entry = all[i]
            if (!q || entry.name.toLowerCase().indexOf(q) >= 0)
                result.push(entry)
        }
        // sort alphabetically
        result.sort(function(a, b) { return a.name.localeCompare(b.name) })
        filteredApps = result
    }

    // ── IPC trigger (Super+R from hyprland) ──────────────────────
    Process {
        id: launcherListener
        command: ["bash", "-c",
            "rm -f /tmp/qs-launcher-" + launcherModule.screenName + "; " +
            "mkfifo /tmp/qs-launcher-" + launcherModule.screenName + "; " +
            "while true; do read -r _ < /tmp/qs-launcher-" + launcherModule.screenName + " && echo open; done"
        ]
        running: true
        stdout: SplitParser {
            onRead: _ => {
                launcherModule.expanded = true
                searchField.text = ""
                launcherModule.filterApps("")
                Qt.callLater(function() {
                    searchField.forceActiveFocus()
                    searchField.selectAll()
                })
            }
        }
    }

    // ── Expandable panel ────────────────────────────────────────────
    ModuleButton {
        id: dropPanel
        noHoverColorChange: true
        color: "transparent"
        topMarginButton: 0 // Removes default margin from ModuleButton
        anchors { left: parent.left; right: parent.right; top: parent.top }
        implicitWidth:  launcherModule.expanded ? launcherModule.panelWidth : collapsedRow.implicitWidth
        implicitHeight: expanded ? panelCol.implicitHeight + 10 : Theme.moduleHeight

        ColumnLayout {
            id: panelCol
            anchors { left: parent.left; right: parent.right; top: parent.top } // Reset layout spacing
            spacing: launcherModule.padding

            // Header row (same height as collapsed bar, keeps visual alignment)
            ModuleButton {
                id: collapsedRow
                colorOverride: !expanded
                noHoverColorChange: !expanded
                noPressColorChange: !expanded
                Layout.fillWidth: true
                implicitHeight: Theme.moduleHeight
                label: " Menu"
                textFont: Theme.fontSize + 2
                cursorShape: Qt.PointingHandCursor
                bottomLeftRadius: launcherModule.expanded ? Theme.moduleEdgeRadius : 0
                bottomRightRadius: launcherModule.expanded ? Theme.moduleEdgeRadius : 0

                onClicked: {
                    if (expanded) {
                        expanded = false
                    } else {
                        expanded = true
                        searchField.text = ""
                        filterApps("")
                        Qt.callLater(function() {
                            searchField.forceActiveFocus()
                            searchField.selectAll()
                        })
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: launcherModule.padding
                Layout.leftMargin: launcherModule.padding
                Layout.rightMargin: launcherModule.padding
            
                ModuleButton {
                    variant: "neutral"
                    Layout.fillWidth: true
                    implicitHeight: Theme.moduleHeight
                    label: "󰸉  Wallpaper"
                    cursorShape: Qt.PointingHandCursor

                    radius: Theme.moduleEdgeRadius

                    onClicked: {
                        launcherModule.expanded = false;
                        wallpaperPicker.expanded = !wallpaperPicker.expanded;
                    }
                }
            
                ModuleButton {
                    variant: "neutral"
                    Layout.fillWidth: true
                    implicitHeight: Theme.moduleHeight
                    label: "󰌆 Bitwarden"
                    cursorShape: Qt.PointingHandCursor

                    radius: Theme.moduleEdgeRadius

                    onClicked: {
                        launcherModule.expanded = false;
                        if (rbwMenu.expanded) {
                            rbwMenu.closeMenu();
                        } else {
                            rbwMenu.openMenu();
                        }
                    }
                }

                ModuleButton {
                    variant: "neutral"
                    Layout.fillWidth: true
                    implicitHeight: Theme.moduleHeight
                    label: " Clipboard"
                    cursorShape: Qt.PointingHandCursor

                    radius: Theme.moduleEdgeRadius
                    
                    onClicked: {
                        launcherModule.expanded = false;
                        if (clipboardHistory.expanded) {
                            clipboardHistory.closeMenu();
                        } else {
                            clipboardHistory.openMenu();
                        }
                    }
                }

            }

            // Search bar
            ModuleButton {
                Layout.fillWidth: true
                Layout.leftMargin: launcherModule.padding
                Layout.rightMargin: launcherModule.padding
                implicitHeight: Theme.moduleHeight
                color: Theme.dark.pressed
                radius: Theme.moduleEdgeRadius
                cursorShape: Qt.PointingHandCursor

                TextInput {
                    id: searchField
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    color: Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    verticalAlignment: TextInput.AlignVCenter
                    focus: true
                    onActiveFocusChanged: {
                        if (!activeFocus && launcherModule.expanded) {
                            launcherModule.expanded = false;
                        }
                    }

                    Text {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }
                        text: " Search apps..."
                        color: launcherModule.textColor
                        opacity: 0.5 // Make it look faded like a placeholder
                        font.family: parent.font.family
                        font.pixelSize: parent.font.pixelSize
                        
                        // The magic trick: Hide it if the user has typed anything!
                        // (You can also add `&& !replyInput.activeFocus` if you want it to hide as soon as they click the box)
                        visible: searchField.text.length === 0
                    }
                    onTextEdited: {
                        launcherModule.filterApps(text)
                        appList.currentIndex = 0
                    }
                    Keys.onEscapePressed: launcherModule.expanded = false
                    Keys.onReturnPressed: {
                        var idx = appList.currentIndex >= 0 ? appList.currentIndex : 0
                        if (launcherModule.filteredApps.length > 0) {
                            launcherModule.filteredApps[idx].execute()
                            launcherModule.expanded = false
                        }
                    }
                    Keys.onDownPressed: {
                        if (launcherModule.filteredApps.length > 0) {
                            appList.currentIndex = Math.min(
                                launcherModule.filteredApps.length - 1,
                                appList.currentIndex + 1
                            )
                            appList.positionViewAtIndex(appList.currentIndex, ListView.Visible)
                        }
                    }
                    Keys.onUpPressed: {
                        if (appList.currentIndex > 0) {
                            appList.currentIndex = appList.currentIndex - 1
                            appList.positionViewAtIndex(appList.currentIndex, ListView.Visible)
                        } else {
                            appList.currentIndex = 0
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: launcherModule.padding
                Layout.rightMargin: launcherModule.padding
                height: 5
                color: Theme.divider
                radius: Theme.moduleEdgeRadius
            }

            // App list
            Rectangle {
                id: appListRect
                Layout.fillWidth: true
                Layout.leftMargin: launcherModule.padding
                Layout.rightMargin: launcherModule.padding
                property int visibleItems: Math.min(launcherModule.filteredApps.length, launcherModule.maxVisible)
                implicitHeight: visibleItems * Theme.listHeight + (visibleItems - 1) * 5// item height + spacing
                color: "transparent"
                radius: Theme.moduleEdgeRadius
                clip: true
                layer.enabled: true
                layer.smooth: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: appListMask
                }

                Item {
                    id: appListMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Rectangle {
                        anchors.fill: parent
                        radius: appListRect.radius
                        color: "black"
                    }
                }

                ListView {
                    id: appList
                    anchors.fill: parent
                    model: launcherModule.filteredApps
                    clip: true
                    spacing: 5
                    focus: false
                    delegate: ModuleButton {
                        required property var modelData
                        required property int index

                        id: appButton
                        variant: isCurrent ? "light" : "neutral"
                        noHoverColorChange: true
                        cursorShape: Qt.PointingHandCursor
                        width: appList.width
                        height: Theme.listHeight
                        radius: Theme.moduleEdgeRadius
                        onClicked: {
                            modelData.execute()
                            launcherModule.expanded = false
                        }

                        // Visual highlight when keyboard-selected or mouse-hovered
                        property bool isCurrent: index === appList.currentIndex

                        HoverHandler {
                            onHoveredChanged: if (hovered) appList.currentIndex = index
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 10

                            IconImage {
                                implicitSize: Theme.moduleHeight - 10
                                source: modelData.icon !== "" ? Quickshell.iconPath(modelData.icon) : ""
                                visible: modelData.icon !== ""
                            }

                            Rectangle {
                                width: 4
                                height: Theme.moduleHeight - 10
                                color: appButton.textColor
                                opacity: 0.5
                                radius: 2
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: textColor
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        filterApps("")
    }
}
