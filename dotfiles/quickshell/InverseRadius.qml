import QtQuick

Canvas {
    id: root
    width: Theme.moduleEdgeRadius
    height: Theme.moduleEdgeRadius

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
        
        if (cornerPosition === "topLeft") {
            ctx.moveTo(0, 0);
            ctx.lineTo(width, 0);
            ctx.arc(width, height, width, 1.5 * Math.PI, Math.PI, true);
            ctx.lineTo(0, height);
            ctx.closePath();
        } else if (cornerPosition === "topRight") {
            ctx.moveTo(width, 0);
            ctx.lineTo(0, 0);
            ctx.arc(0, height, width, 1.5 * Math.PI, 2.0 * Math.PI, false);
            ctx.lineTo(width, height);
            ctx.closePath();
        } else if (cornerPosition === "bottomLeft") {
            ctx.moveTo(0, height);
            ctx.lineTo(width, height);
            ctx.arc(width, 0, width, 0.5 * Math.PI, Math.PI, false);
            ctx.lineTo(0, 0);
            ctx.closePath();
        } else if (cornerPosition === "bottomRight") {
            ctx.moveTo(width, height);
            ctx.lineTo(0, height);
            ctx.arc(0, 0, width, 0.5 * Math.PI, 0, true);
            ctx.lineTo(width, 0);
            ctx.closePath();
        }
        ctx.fill();
    }
}
