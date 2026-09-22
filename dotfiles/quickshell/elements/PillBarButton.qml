import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

ModuleButton {
    id: root

    property real percent: 100
    property bool animatePercent: true
    property string pillText: ""
    property string pillVariant: root.variant
    property var pillPal: Theme.palette(pillVariant)
    property int pillRadius: (Theme.moduleHeight - 10) / 2
    property int pillHeight: Theme.moduleHeight - 10
    property int pillPaddingH: 10
    property real pillColorOpacity: root.colorOpacity 
    property real gradientOpacityBase: root.openBottom ? 0.4 : 1.0
    property real gradientOpacityLow: root.openBottom ? 0.0 : 1.0
    property string bgImageSource: ""

    property bool openBottom: false
    property int openBottomTopMargin: 6
    property int openBottomBottomMargin: 6

    property int pillTopLeftRadius: pillRadius
    property int pillTopRightRadius: pillRadius
    property int pillBottomLeftRadius: openBottom ? (Theme.moduleEdgeRadius + 5): pillRadius
    property int pillBottomRightRadius: openBottom ? (Theme.moduleEdgeRadius + 5): pillRadius

    Behavior on pillHeight {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    Behavior on pillRadius {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    Behavior on pillPaddingH {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    Behavior on pillTopLeftRadius {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    Behavior on pillTopRightRadius {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    Behavior on pillBottomLeftRadius {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }
    Behavior on pillBottomRightRadius {
        NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
    }

    // Smooth percentage animation
    property real animatedPercent: percent
    Behavior on animatedPercent {
        enabled: root.animatePercent
        NumberAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
    }

    label: pillText
    textColor: "transparent"

    // Outer pill background
    Rectangle {
        id: pillBg
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, parent.width - root.pillPaddingH)
        y: root.openBottom ? root.openBottomTopMargin : Math.round((parent.height - root.pillHeight) / 2)
        height: root.openBottom ? Math.max(0, parent.height - root.openBottomTopMargin - root.openBottomBottomMargin) : root.pillHeight
        clip: true

        topLeftRadius: root.pillTopLeftRadius
        topRightRadius: root.pillTopRightRadius
        bottomLeftRadius: root.pillBottomLeftRadius
        bottomRightRadius: root.pillBottomRightRadius

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0.0
                color: Qt.rgba(root.pillPal.pillTrack.r, root.pillPal.pillTrack.g, root.pillPal.pillTrack.b, root.pillPal.pillTrack.a * root.pillColorOpacity * gradientOpacityBase)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(root.pillPal.pillTrack.r, root.pillPal.pillTrack.g, root.pillPal.pillTrack.b, root.pillPal.pillTrack.a * root.pillColorOpacity * gradientOpacityLow)
                Behavior on color {
                    ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
                }
            }
        }

        // Background album art image (collapsed only)
        Item {
            id: _bgImgContainer
            anchors.fill: parent
            anchors.margins: 2
            visible: root.bgImageSource !== "" && opacity > 0
            opacity: root.openBottom ? 0.0 : 1.0

            Behavior on opacity {
                NumberAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
            }

            Image {
                id: _bgImg
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: root.bgImageSource
                sourceSize.width: 300
                asynchronous: true
                smooth: true
                visible: false
            }

            Item {
                id: _bgImgMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                layer.smooth: true

                Rectangle {
                    anchors.fill: parent
                    topLeftRadius: Math.max(0, pillBg.topLeftRadius - 2)
                    topRightRadius: Math.max(0, pillBg.topRightRadius - 2)
                    bottomLeftRadius: Math.max(0, pillBg.bottomLeftRadius - 2)
                    bottomRightRadius: Math.max(0, pillBg.bottomRightRadius - 2)
                    color: "black"
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: _bgImg
                maskEnabled: true
                maskSource: _bgImgMask
                opacity: 0.28
            }

            Rectangle {
                anchors.fill: parent
                topLeftRadius: Math.max(0, pillBg.topLeftRadius - 2)
                topRightRadius: Math.max(0, pillBg.topRightRadius - 2)
                bottomLeftRadius: Math.max(0, pillBg.bottomLeftRadius - 2)
                bottomRightRadius: Math.max(0, pillBg.bottomRightRadius - 2)
                color: Qt.rgba(Theme.paletteInk.r, Theme.paletteInk.g, Theme.paletteInk.b, 0.25)
            }
        }

        // Inner percentage fill (clipped linearly)
        Item {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: root.openBottom ? parent.width : parent.width * (Math.min(Math.max(root.animatedPercent, 0), 100) / 100)
            clip: true

            Rectangle {
                width: parent.parent.width
                height: parent.parent.height
                topLeftRadius: parent.parent.topLeftRadius
                topRightRadius: parent.parent.topRightRadius
                bottomLeftRadius: parent.parent.bottomLeftRadius
                bottomRightRadius: parent.parent.bottomRightRadius

                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(root.pillPal.pillFill.r, root.pillPal.pillFill.g, root.pillPal.pillFill.b, root.pillPal.pillFill.a * root.pillColorOpacity * gradientOpacityBase)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(root.pillPal.pillFill.r, root.pillPal.pillFill.g, root.pillPal.pillFill.b, root.pillPal.pillFill.a * root.pillColorOpacity * gradientOpacityLow)
                        Behavior on color {
                            ColorAnimation { duration: Theme.verticalDuration; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }

        // Overlay border so it displays evenly over both track and fill colors
        Rectangle {
            anchors.fill: parent
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
            color: "transparent"
            border.color: Qt.rgba(root.pillPal.pillBorder.r, root.pillPal.pillBorder.g, root.pillPal.pillBorder.b, root.pillPal.pillBorder.a * root.pillColorOpacity * gradientOpacityBase)
            border.width: root.openBottom ? 2 : 2
        }

        // Text inside the pill
        Text {
            anchors.fill: parent
            text: root.pillText
            color: root.pillPal.pillText
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: root.openBottom ? 0.0 : 1.0

            Behavior on opacity {
                NumberAnimation { duration: root.openBottom ? 0 : Theme.verticalDuration; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: Theme.horizontalDuration; easing.type: Easing.OutCubic }
            }
        }
    }
}
