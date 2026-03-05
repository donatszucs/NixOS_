// Mod switcher — toggles input-remapper preset, light theme like waybar
import QtQuick

import "../elements"

ModuleButton {
    id: root
    cursorShape: Qt.PointingHandCursor
    label: SharedState.modLabel
    variant: SharedState.modVariant

    onClicked: SharedState.toggleModSwitcher()
}
