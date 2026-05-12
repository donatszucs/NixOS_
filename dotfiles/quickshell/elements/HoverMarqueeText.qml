import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property string text: ""
    property real textMaxWidth: 160 // default sensible max
    property color textColor: Theme.textPrimary
    property string fontFamily: Theme.font
    property int pixelSize: Theme.fontSize
    property bool fontBold: true

    // Removed maxChars! We let text elide based on pixel width correctly.

    implicitHeight: visibleText.implicitHeight
    implicitWidth: Math.min(visibleText.implicitWidth + 10, root.textMaxWidth)
    Layout.preferredWidth: implicitWidth
    Layout.maximumWidth: root.textMaxWidth
    Layout.fillWidth: true
    clip: true

    HoverHandler { id: hover }

    Text {
        id: visibleText
        text: root.text
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: root.pixelSize
        font.bold: root.fontBold
        x: 0
        anchors.verticalCenter: parent.verticalCenter

        width: hover.hovered ? implicitWidth : root.width
        elide: hover.hovered ? Text.ElideNone : Text.ElideRight
    }
    
    SequentialAnimation {
        id: marqueeAnim
        running: hover.hovered && visibleText.implicitWidth > root.width
        loops: Animation.Infinite

        onRunningChanged: {
            if (!running) visibleText.x = 0;
        }

        PauseAnimation { duration: 250 }
        NumberAnimation {
            target: visibleText
            property: "x"
            from: 0
            to: -(visibleText.implicitWidth - root.width)
            duration: Math.max(1200, (visibleText.implicitWidth - root.width) * 30)
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 500 }
        NumberAnimation {
            target: visibleText
            property: "x"
            to: 0
            duration: 250
            easing.type: Easing.OutCubic
        }
    }
}
