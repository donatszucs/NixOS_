// App Launcher — expands downward with search + installed app list
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Hyprland

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

    implicitWidth:  expanded ? dropPanel.implicitWidth  : collapsedRow.implicitWidth
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
        anchors { left: parent.left; right: parent.right; top: parent.top }
        implicitWidth:  launcherModule.panelWidth
        implicitHeight: panelCol.implicitHeight + 10

        ColumnLayout {
            id: panelCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; topMargin: -3 }
            spacing: 8

            // Header row (same height as collapsed bar, keeps visual alignment)
            ModuleButton {
                id: collapsedRow
                Layout.alignment: Qt.AlignCenter
                color: "transparent"
                
                implicitHeight: Theme.moduleHeight
                label: "  Menu"

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

            // Search bar
            Rectangle {
                visible: launcherModule.expanded
                Layout.fillWidth: true
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
                    onTextEdited: launcherModule.filterApps(text)
                    Keys.onEscapePressed: launcherModule.expanded = false
                    Keys.onReturnPressed: {
                        if (launcherModule.filteredApps.length > 0) {
                            launcherModule.filteredApps[0].execute()
                            launcherModule.expanded = false
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                visible: launcherModule.expanded
                Layout.fillWidth: true
                height: 5
                color: Qt.rgba(1, 1, 1, 0.08)
                radius: Theme.moduleEdgeRadius
            }

            // App list
            Rectangle {
                visible: launcherModule.expanded
                id: appListRect
                Layout.fillWidth: true
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
                    delegate: ModuleButton {
                        required property var modelData
                        required property int index
                        width: appList.width
                        topLeftRadius:    0
                        topRightRadius:   0
                        bottomLeftRadius:  index === launcherModule.filteredApps.length - 1 ? Theme.moduleEdgeRadius : 0
                        bottomRightRadius: index === launcherModule.filteredApps.length - 1 ? Theme.moduleEdgeRadius : 0
                        onClicked: {
                            modelData.execute()
                            launcherModule.expanded = false
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

}
