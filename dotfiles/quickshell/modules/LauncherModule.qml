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
    noPressColorChange: expanded
    property bool expanded: false
    property string screenName: ""


    property int  panelWidth:  400
    property int  maxVisible:  5
    property int  padding:    10

    // JS array of DesktopEntry objects matching the current search
    property var filteredApps: []

    bottomLeftRadius:  expanded ? Theme.moduleEdgeRadius * 2 : 0
    bottomRightRadius: expanded ? Theme.moduleEdgeRadius * 2 : 0
    
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
    IpcHandler {
        target: "launcher-" + launcherModule.screenName
        function toggle(): void {
            if (launcherModule.expanded) {
                launcherModule.expanded = false
            } else {
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
            PillBarButton {
                id: collapsedRow
                colorOverride: !expanded
                noHoverColorChange: !expanded
                noPressColorChange: !expanded
                Layout.fillWidth: true
                implicitHeight: Theme.moduleHeight
                pillText: " Menu"
                percent: expanded ? 100 : 0
                pillVariant: "neutral"
                textFont: Theme.fontSize
                cursorShape: Qt.PointingHandCursor
                bottomLeftRadius: launcherModule.expanded ? Theme.moduleEdgeRadius : 0
                bottomRightRadius: launcherModule.expanded ? Theme.moduleEdgeRadius : 0

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton

                    onPressedChanged: {
                            if(!launcherModule.expanded) {
                                launcherModule.pressed = !launcherModule.pressed
                            }
                            else {
                                collapsedRow.pressed = !collapsedRow.pressed
                            }
                        }
                    onClicked: (mouse) => {
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
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: launcherModule.padding
                Layout.leftMargin: launcherModule.padding
                Layout.rightMargin: launcherModule.padding
            
                ModuleButton {
                    variant: "neutral"
                    Layout.fillWidth: true
                    implicitHeight: Theme.listHeight
                    label: "󰸉 Wallpaper"
                    cursorShape: Qt.PointingHandCursor

                    radius: Theme.moduleEdgeRadius
                    border.width: 2

                    onClicked: {
                        launcherModule.expanded = false;
                        wallpaperPicker.expanded = !wallpaperPicker.expanded;
                    }
                }
            
                ModuleButton {
                    variant: "neutral"
                    Layout.fillWidth: true
                    implicitHeight: Theme.listHeight
                    label: "󰌆 Bitwarden"
                    cursorShape: Qt.PointingHandCursor

                    radius: Theme.moduleEdgeRadius
                    border.width: 2
                    
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
                    implicitHeight: Theme.listHeight
                    label: " Clipboard"
                    cursorShape: Qt.PointingHandCursor

                    radius: Theme.moduleEdgeRadius
                    border.width: 2

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


            // App list
            Rectangle {
                id: appListRect
                Layout.fillWidth: true
                Layout.leftMargin: launcherModule.padding
                Layout.rightMargin: launcherModule.padding
                property int visibleItems: launcherModule.filteredApps.length > 0
                    ? Math.min(launcherModule.filteredApps.length, launcherModule.maxVisible)
                    : 0
                implicitHeight: visibleItems > 0
                    ? (visibleItems * Theme.listHeight + (visibleItems - 1) * 5) // item height + spacing
                    : 0
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

            // Search bar
            ModuleButton {
                Layout.fillWidth: true
                Layout.leftMargin: launcherModule.padding
                Layout.rightMargin: launcherModule.padding
                Layout.topMargin: - launcherModule.padding
                implicitHeight: Theme.listHeight
                color: "transparent"
                radius: Theme.moduleEdgeRadius
                cursorShape: Qt.PointingHandCursor

                TextInput {
                    id: searchField
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    color: Theme.textPrimary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize * 1.3
                    font.bold: true
                    
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter 
                    focus: true

                    // Completely hide the default cursor
                    cursorDelegate: Item {}

                    // Dynamic flashing underline bar
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        
                        // Match text width. If empty, default to a 20px dash.
                        width: searchField.text.length > 0 ? searchField.contentWidth + 8 : placeholder.contentWidth + 8
                        height: 2
                        color: Theme.textPrimary 
                        radius: 1 

                        // Smoothly animate the bar growing/shrinking as you type
                        Behavior on width {
                            NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                        }

                        // The breathing animation
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: searchField.activeFocus // Only breathe when focused
                            
                            NumberAnimation { 
                                to: 0.3
                                duration: 2000 // 1 second to exhale
                                easing.type: Easing.InOutSine 
                            }
                            NumberAnimation { 
                                to: 1.0 // Fades back to full opacity
                                duration: 1000 // 1 second to inhale
                                easing.type: Easing.InOutSine 
                            }
                        }
                    }

                    Text {
                        id: placeholder
                        anchors.centerIn: parent
                        text: "search apps" 
                        
                        color: launcherModule.textColor
                        opacity: 0.5 
                        font.family: parent.font.family
                        font.pixelSize: parent.font.pixelSize
                        font.bold: true
                        
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
        }
    }

    Component.onCompleted: {
        filterApps("")
    }
}
