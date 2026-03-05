import QtQuick
import QtQuick.Layouts

Item {
    id: root
    // Pass the colors of the modules on either side
    property color leftColor: "transparent"
    property color rightColor: "transparent"
    
    // Pass the expanded state if the corners need to move vertically
    property bool leftExpanded: true
    property bool rightExpanded: true

    // The physical gap size between modules
    implicitWidth: 0
    implicitHeight: Theme.moduleHeight

    // 1. The Right-facing corner (attaches to the Left module)
    InverseRadius {
        cornerPosition: "topRight"
        color: root.leftColor
        expandingV: root.leftExpanded
        
        anchors {
            // Anchor to the very right edge of this gap
            right: parent.right  
            top: parent.bottom 
        }
    }

    // 2. The Left-facing corner (attaches to the Right module)
    InverseRadius {
        cornerPosition: "topLeft"
        color: root.rightColor
        expandingV: root.rightExpanded
        
        anchors {
            // Anchor to the very left edge of this gap

            left: parent.left
            top: parent.bottom // Or whatever vertical anchor you were using
        }
    }
}