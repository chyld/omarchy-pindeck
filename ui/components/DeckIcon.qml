import QtQuick
import qs.Commons

Canvas {
    id: root
    property color outline: Color.foreground
    property color highlight: Color.accent
    implicitWidth: Style.space(20)
    implicitHeight: implicitWidth
    onOutlineChanged: requestPaint()
    onHighlightChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        ctx.scale(width / 20, height / 20);
        ctx.lineWidth = 1.5;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.strokeStyle = outline;
        ctx.translate(-1.75, -1.75);
        ctx.beginPath();
        ctx.roundedRect(5, 5, 13.5, 13.5, 2, 2);
        ctx.stroke();
        ctx.fillStyle = highlight;
        for (var i = 0; i < 4; i++) {
            ctx.beginPath();
            ctx.roundedRect(8 + (i % 2) * 4.5, 8 + Math.floor(i / 2) * 4.5, 3, 3, 0.6, 0.6);
            ctx.fill();
        }
    }
}
