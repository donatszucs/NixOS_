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
    
    // Use an exponential/squircle-like smooth bezier curve instead of a strict circular arc
    property bool smoothCurve: false
    // Values closer to 0 make the corner "sharper" but perfectly smooth. 0.15 is roughly Apple's continuous corner. 0.4477 is roughly a perfect circle.
    property real smoothTolerance: 0.15

    // Round the outer corner (the sharp vertex)
    property real outerRadius: 0

    // Ensure smooth curved edges
    antialiasing: true
    smooth: true

    onColorChanged: requestPaint()
    onCornerPositionChanged: requestPaint()
    onSmoothCurveChanged: requestPaint()
    onSmoothToleranceChanged: requestPaint()
    onOuterRadiusChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        ctx.fillStyle = color;
        ctx.beginPath();
        
        ctx.save();
        var scaleX = width > 0 ? width : 1;
        var scaleY = height > 0 ? height : 1;
        ctx.scale(scaleX, scaleY);
        
        var c = smoothCurve ? smoothTolerance : 0.447715;
        var rx = outerRadius > 0 ? Math.min(0.5, outerRadius / scaleX) : 0;
        var ry = outerRadius > 0 ? Math.min(0.5, outerRadius / scaleY) : 0;

        if (cornerPosition === "topLeft") {
            if (rx > 0) {
                ctx.moveTo(rx, 0);
                ctx.lineTo(1, 0);
                if (smoothCurve) ctx.bezierCurveTo(c, 0, 0, c, 0, 1);
                else ctx.arc(1, 1, 1, 1.5 * Math.PI, Math.PI, true);
                ctx.lineTo(0, ry);
                ctx.arc(rx, ry, rx, Math.PI, 1.5 * Math.PI, false);
                ctx.closePath();
            } else {
                ctx.moveTo(0, 0);
                ctx.lineTo(1, 0);
                if (smoothCurve) ctx.bezierCurveTo(c, 0, 0, c, 0, 1);
                else ctx.arc(1, 1, 1, 1.5 * Math.PI, Math.PI, true);
                ctx.lineTo(0, 1);
                ctx.closePath();
            }
        } else if (cornerPosition === "topRight") {
            if (rx > 0) {
                ctx.moveTo(1 - rx, 0);
                ctx.lineTo(0, 0);
                if (smoothCurve) ctx.bezierCurveTo(1 - c, 0, 1, c, 1, 1);
                else ctx.arc(0, 1, 1, 1.5 * Math.PI, 2.0 * Math.PI, false);
                ctx.lineTo(1, 1);
                ctx.lineTo(1, ry);
                ctx.arc(1 - rx, ry, rx, 0, 1.5 * Math.PI, true);
                ctx.closePath();
            } else {
                ctx.moveTo(1, 0);
                ctx.lineTo(0, 0);
                if (smoothCurve) ctx.bezierCurveTo(1 - c, 0, 1, c, 1, 1);
                else ctx.arc(0, 1, 1, 1.5 * Math.PI, 2.0 * Math.PI, false);
                ctx.lineTo(1, 1);
                ctx.closePath();
            }
        } else if (cornerPosition === "bottomLeft") {
            if (rx > 0) {
                ctx.moveTo(0, 0);
                ctx.lineTo(0, 1 - ry);
                ctx.arc(rx, 1 - ry, rx, Math.PI, 0.5 * Math.PI, true);
                ctx.lineTo(1, 1);
                if (smoothCurve) ctx.bezierCurveTo(c, 1, 0, 1 - c, 0, 0);
                else ctx.arc(1, 0, 1, 0.5 * Math.PI, Math.PI, false);
                ctx.closePath();
            } else {
                ctx.moveTo(0, 1);
                ctx.lineTo(1, 1);
                if (smoothCurve) ctx.bezierCurveTo(c, 1, 0, 1 - c, 0, 0);
                else ctx.arc(1, 0, 1, 0.5 * Math.PI, Math.PI, false);
                ctx.lineTo(0, 0);
                ctx.closePath();
            }
        } else if (cornerPosition === "bottomRight") {
            if (rx > 0) {
                ctx.moveTo(1, 0);
                ctx.lineTo(1, 1 - ry);
                ctx.arc(1 - rx, 1 - ry, rx, 0, 0.5 * Math.PI, false);
                ctx.lineTo(0, 1);
                if (smoothCurve) ctx.bezierCurveTo(1 - c, 1, 1, 1 - c, 1, 0);
                else ctx.arc(0, 0, 1, 0.5 * Math.PI, 0, true);
                ctx.closePath();
            } else {
                ctx.moveTo(1, 1);
                ctx.lineTo(0, 1);
                if (smoothCurve) ctx.bezierCurveTo(1 - c, 1, 1, 1 - c, 1, 0);
                else ctx.arc(0, 0, 1, 0.5 * Math.PI, 0, true);
                ctx.lineTo(1, 0);
                ctx.closePath();
            }
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
