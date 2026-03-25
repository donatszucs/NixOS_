import QtQuick

Canvas {
    id: root
    property bool expandingV: true
    property bool expandingH: true
    property int size: Theme.moduleEdgeRadius
    property int sizeH: size
    property int sizeV: size
    property int animationDuration: Theme.verticalDuration
    // Set false to disable the built-in Behavior so width/height can be bound externally
    property bool animated: true
    implicitWidth: expandingH ? sizeH : 0
    implicitHeight: expandingV ? sizeV : 0

    property color color: Theme.palette("dark").base
    // Where is the solid corner located within this block?
    // "topLeft": solid at (0,0). Empty circle at (width, height)
    // "topRight": solid at (width,0). Empty circle at (0, height)
    // "bottomLeft": solid at (0,height). Empty circle at (width, 0)
    // "bottomRight": solid at (width,height). Empty circle at (0, 0)
    property string cornerPosition: "topLeft" 
    
    // Ensure smooth curved edges
    antialiasing: true
    smooth: true
    opacity: Theme.moduleOpacity

    onColorChanged: requestPaint()
    onCornerPositionChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        ctx.fillStyle = color;
        ctx.beginPath();
        
        ctx.save();
        var scaleX = width > 0 ? width : 1;
        var scaleY = height > 0 ? height : 1;
        ctx.scale(scaleX, scaleY);
        
        if (cornerPosition === "topLeft") {
            ctx.moveTo(0, 0);
            ctx.lineTo(1, 0);
            ctx.arc(1, 1, 1, 1.5 * Math.PI, Math.PI, true);
            ctx.lineTo(0, 1);
            ctx.closePath();
        } else if (cornerPosition === "topRight") {
            ctx.moveTo(1, 0);
            ctx.lineTo(0, 0);
            ctx.arc(0, 1, 1, 1.5 * Math.PI, 2.0 * Math.PI, false);
            ctx.lineTo(1, 1);
            ctx.closePath();
        } else if (cornerPosition === "bottomLeft") {
            ctx.moveTo(0, 1);
            ctx.lineTo(1, 1);
            ctx.arc(1, 0, 1, 0.5 * Math.PI, Math.PI, false);
            ctx.lineTo(0, 0);
            ctx.closePath();
        } else if (cornerPosition === "bottomRight") {
            ctx.moveTo(1, 1);
            ctx.lineTo(0, 1);
            ctx.arc(0, 0, 1, 0.5 * Math.PI, 0, true);
            ctx.lineTo(1, 0);
            ctx.closePath();
        }
        ctx.restore();
        ctx.fill();
    }

    Behavior on implicitWidth {
        enabled: root.animated
        NumberAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on implicitHeight {
        enabled: root.animated
        NumberAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }
    }
}
