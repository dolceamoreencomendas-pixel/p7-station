import QtQuick 2.15

// Anel de progresso (troféus, bateria). Só redesenha quando o valor muda.
// O desenho é feito em resolução maior e reduzido, para ficar nítido no palco ampliado.
Item {
    id: ring

    property real value: 0                 // 0 a 1
    property color color: "#ffd36a"
    property color track: "#26ffffff"
    property real lineWidth: 4
    property bool animated: true
    property real pixelRatio: 2

    property real shown: value
    Behavior on shown { enabled: ring.animated; NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

    function css(c) { return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + c.a + ")"; }

    Canvas {
        id: cv
        width: Math.max(1, Math.round(ring.width * ring.pixelRatio))
        height: Math.max(1, Math.round(ring.height * ring.pixelRatio))
        scale: 1 / ring.pixelRatio
        transformOrigin: Item.TopLeft
        renderTarget: Canvas.Image
        onPaint: {
            var c = getContext("2d");
            c.reset();
            var k = ring.pixelRatio;
            var lw = ring.lineWidth * k;
            var r = Math.min(width, height) / 2 - lw / 2 - 0.5;
            c.lineWidth = lw;
            c.lineCap = "round";
            c.strokeStyle = ring.css(ring.track);
            c.beginPath();
            c.arc(width / 2, height / 2, r, 0, Math.PI * 2);
            c.stroke();
            var v = Math.max(0, Math.min(1, ring.shown));
            if (v <= 0) return;
            c.strokeStyle = ring.css(ring.color);
            c.beginPath();
            c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * v);
            c.stroke();
        }
    }
    onShownChanged: cv.requestPaint()
    onColorChanged: cv.requestPaint()
    onTrackChanged: cv.requestPaint()
}
