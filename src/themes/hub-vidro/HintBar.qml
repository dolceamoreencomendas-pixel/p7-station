import QtQuick 2.15

// Barra de dicas dos botões do controle (✕ ○ △ □, setas, L1 R1).
// hints: [{ glyph: "cross" | "circle" | "triangle" | "square" | "left" | "right" | "leftright" | "updown" | "lr", label }]
Row {
    id: bar
    property var hints: []
    spacing: 28

    Repeater {
        model: bar.hints
        delegate: Row {
            spacing: 9
            Item {
                width: 24; height: 24
                anchors.verticalCenter: parent.verticalCenter
                visible: modelData.glyph !== "lr"
                Canvas {
                    anchors.centerIn: parent
                    width: 72; height: 72
                    scale: 1 / 3
                    renderTarget: Canvas.Image
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.scale(4, 4);       // 18 → 72
                        ctx.strokeStyle = "rgba(255,255,255,0.62)";
                        ctx.lineWidth = 1.2;
                        ctx.lineJoin = "round";
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.arc(9, 9, 8, 0, Math.PI * 2);
                        ctx.stroke();
                        ctx.strokeStyle = "rgba(255,255,255,0.9)";
                        ctx.beginPath();
                        var g = modelData.glyph;
                        if (g === "cross") {
                            ctx.moveTo(6.2, 6.2); ctx.lineTo(11.8, 11.8);
                            ctx.moveTo(11.8, 6.2); ctx.lineTo(6.2, 11.8);
                        } else if (g === "triangle") {
                            ctx.moveTo(9, 5.2); ctx.lineTo(12.6, 11.6); ctx.lineTo(5.4, 11.6); ctx.closePath();
                        } else if (g === "square") {
                            ctx.rect(5.8, 5.8, 6.4, 6.4);
                        } else if (g === "circle") {
                            ctx.arc(9, 9, 3.6, 0, Math.PI * 2);
                        } else if (g === "right") {
                            ctx.moveTo(7.5, 5.5); ctx.lineTo(11, 9); ctx.lineTo(7.5, 12.5);
                        } else if (g === "left") {
                            ctx.moveTo(10.5, 5.5); ctx.lineTo(7, 9); ctx.lineTo(10.5, 12.5);
                        } else {
                            ctx.moveTo(6.5, 6.5); ctx.lineTo(4.5, 9); ctx.lineTo(6.5, 11.5);
                            ctx.moveTo(11.5, 6.5); ctx.lineTo(13.5, 9); ctx.lineTo(11.5, 11.5);
                        }
                        ctx.stroke();
                    }
                }
            }
            Text {
                visible: modelData.glyph === "lr"
                anchors.verticalCenter: parent.verticalCenter
                text: "L1 R1"
                color: "#ccffffff"
                font.family: "Manrope"
                font.pixelSize: 13
                font.weight: Font.Bold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                color: "#a6ffffff"
                font.family: "Manrope"
                font.weight: Font.Medium
                font.pixelSize: 15
            }
        }
    }
}
