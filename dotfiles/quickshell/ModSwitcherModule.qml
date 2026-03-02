// Mod switcher — toggles input-remapper preset, light theme like waybar
import QtQuick

ModuleButton {
    id: root
    label: SharedState.modLabel
    variant: SharedState.modVariant
    implicitWidth: 30

    onClicked: SharedState.toggleModSwitcher()
}
