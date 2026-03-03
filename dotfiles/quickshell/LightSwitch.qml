// Tapo Light Switch button — toggles smart bulb on/off with brightness control
import QtQuick

ModuleButton {
    id: root
    
    variant: SharedState.lightVariant
    label: SharedState.lightActive ? SharedState.lightBrightness + "% 󱩒" : " Off 󱩎"

    Timer {
        id: debounceTimer
        interval: 1000
        repeat: false
        onTriggered: {
            SharedState.setLightBrightness(SharedState.lightBrightness)
        }
    }

    onClicked: {
        SharedState.toggleLight()
    }

    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
        
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) {
                // Scroll up - increase brightness
                SharedState.lightBrightness = Math.min(100, SharedState.lightBrightness + 10)
            } else {
                // Scroll down - decrease brightness
                SharedState.lightBrightness = Math.max(1, SharedState.lightBrightness - 10)
            }
            
            // Restart debounce timer
            debounceTimer.restart()
            wheel.accepted = true
        }
    }
}
