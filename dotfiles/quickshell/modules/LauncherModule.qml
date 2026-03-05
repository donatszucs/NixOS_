// App Launcher — expands downward with search + installed app list
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Hyprland

import "../elements"

ModuleButton {
    id: launcherModule
    label: ""
    noHoverColorChange: true

    property bool expanded: false
    property string screenName: ""

    HoverHandler {
        id: parentHover
    }
    property int  panelWidth:  320
    property int  maxVisible:  8

    // JS array of DesktopEntry objects matching the current search
    property var filteredApps: []

    bottomLeftRadius:  expanded ? Theme.moduleEdgeRadius : Theme.moduleRadius
    bottomRightRadius: expanded ? Theme.moduleEdgeRadius : Theme.moduleRadius
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
        implicitHeight: expanded ? panelCol.implicitHeight + 10 : panelCol.implicitHeight

        ColumnLayout {
            id: panelCol
            anchors { left: parent.left; right: parent.right; top: parent.top } // Reset layout spacing
            spacing: 8

            // Header row (same height as collapsed bar, keeps visual alignment)
            ModuleButton {
                id: collapsedRow
                variant: expanded ? "dark" : "transparentDark"
                Layout.fillWidth: true
                implicitHeight: Theme.moduleHeight
                label: "  Menu "
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

            ModuleButton {
                variant: "transparentDark"
                Layout.fillWidth: true
                implicitHeight: Theme.moduleHeight
                visible: launcherModule.expanded
                label: "󰸉  Wallpaper Picker"
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    launcherModule.expanded = false;
                    wallpaperPicker.expanded = !wallpaperPicker.expanded;
                }
            }

            // Search bar
            Rectangle {
                visible: launcherModule.expanded
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                implicitHeight: Theme.moduleHeight
                color: Theme.dark.hover
                radius: Theme.moduleEdgeRadius

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
                    onTextEdited: {
                        launcherModule.filterApps(text)
                        appList.currentIndex = -1
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
                            appList.currentIndex = -1
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                visible: launcherModule.expanded
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                height: 5
                color: Theme.divider
                radius: Theme.moduleEdgeRadius
            }

            // App list
            Rectangle {
                visible: launcherModule.expanded
                id: appListRect
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                implicitHeight: Math.min(launcherModule.filteredApps.length, launcherModule.maxVisible) * Theme.moduleHeight
                color: "transparent"
                Behavior on implicitHeight {
                    NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
                }

                ListView {
                    id: appList
                    anchors.fill: parent
                    model: launcherModule.filteredApps
                    clip: true
                    spacing: 0
                    focus: false
                    delegate: ModuleButton {
                        required property var modelData
                        required property int index
                        cursorShape: Qt.PointingHandCursor
                        width: appList.width
                        topLeftRadius:    0
                        topRightRadius:   0
                        bottomLeftRadius:  index === launcherModule.filteredApps.length - 1 ? Theme.moduleEdgeRadius : 0
                        bottomRightRadius: index === launcherModule.filteredApps.length - 1 ? Theme.moduleEdgeRadius : 0
                        onClicked: {
                            modelData.execute()
                            launcherModule.expanded = false
                        }

                        // Visual highlight when keyboard-selected or mouse-hovered
                        property bool isCurrent: index === appList.currentIndex
                        color: isCurrent ? Theme.dark.hover : "transparent"

                        HoverHandler {
                            onHoveredChanged: if (hovered) appList.currentIndex = index
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 8

                            IconImage {
                                implicitSize: Theme.moduleHeight - 10
                                source: modelData.icon !== "" ? "image://icon/" + modelData.icon : ""
                                visible: modelData.icon !== ""
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: Theme.textPrimary
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
