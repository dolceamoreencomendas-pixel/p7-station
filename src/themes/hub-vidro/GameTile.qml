import QtQuick 2.15
import QtGraphicalEffects 1.12
import "logic.js" as L

// Capa de um jogo. Com arte: a capa inteira no quadrado, o resto preenchido por ela mesma
// desfocada. Sem arte: uma capa gerada (degradê na cor do console, sigla e nome do jogo).
// Selecionada: cresce, sobe, ganha anel branco e um brilho passa por cima uma vez.
// O tamanho no layout nunca muda (só a escala), então a fileira não "pula".
Item {
    id: tile

    property var entry: null
    property bool selected: false
    property real baseSize: 168
    property real selScale: 1.12
    property real lift: 18
    property real dimOpacity: 0.72
    property bool showRing: true
    property real pixelRatio: 2
    property real cornerRadius: Math.round(baseSize * 0.15)

    signal tapped()
    signal held()

    width: baseSize
    height: baseSize
    z: selected ? 2 : 1

    readonly property bool hasArt: art.status === Image.Ready
    readonly property var colors: entry ? L.coverColors(entry.color, entry.title) : ["#4a4f58", "#15171c"]

    // tudo que se move junto na seleção
    Item {
        id: body
        anchors.fill: parent
        transformOrigin: Item.Bottom
        scale: tile.selected ? tile.selScale : 1
        opacity: tile.selected ? 1 : tile.dimOpacity
        transform: Translate { y: tile.selected ? -tile.lift : 0; Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.3 } } }
        Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
        Behavior on opacity { NumberAnimation { duration: 260 } }

        // sombra macia (só na selecionada)
        RectangularGlow {
            anchors.fill: card
            anchors.topMargin: tile.baseSize * 0.08
            anchors.bottomMargin: -tile.baseSize * 0.06
            glowRadius: tile.baseSize * 0.14
            spread: 0.1
            cornerRadius: tile.cornerRadius + glowRadius
            color: "#a6000000"
            opacity: tile.selected ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        Item {
            id: card
            anchors.fill: parent

            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(Math.round(width * tile.pixelRatio * tile.selScale), Math.round(height * tile.pixelRatio * tile.selScale))
            layer.effect: OpacityMask {
                maskSource: Rectangle { width: card.width; height: card.height; radius: tile.cornerRadius }
            }

            // ---------------- capa gerada
            Rectangle {
                anchors.fill: parent
                visible: !tile.hasArt
                gradient: Gradient {
                    GradientStop { position: 0.0; color: tile.colors[0] }
                    GradientStop { position: 1.0; color: tile.colors[1] }
                }
            }
            RadialGradient {
                anchors.fill: parent
                visible: !tile.hasArt
                horizontalOffset: -width * 0.3
                verticalOffset: -height * 0.35
                horizontalRadius: width * 0.9
                verticalRadius: height * 0.9
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#40ffffff" }
                    GradientStop { position: 0.6; color: "#00ffffff" }
                }
            }
            Text {
                visible: !tile.hasArt
                x: tile.baseSize * 0.085
                y: tile.baseSize * 0.075
                text: tile.entry ? String(tile.entry.short || "").toUpperCase() : ""
                color: "#d9ffffff"
                font.family: "Manrope"
                font.weight: Font.Bold
                font.pixelSize: Math.max(9, tile.baseSize * 0.066)
                font.letterSpacing: tile.baseSize * 0.009
                leftPadding: tile.baseSize * 0.045
                rightPadding: leftPadding
                topPadding: tile.baseSize * 0.02
                bottomPadding: topPadding
                Rectangle { anchors.fill: parent; z: -1; radius: tile.baseSize * 0.045; color: "#47000000" }
            }
            Text {
                visible: !tile.hasArt
                x: tile.baseSize * 0.085
                width: tile.baseSize * 0.83
                anchors.bottom: parent.bottom
                anchors.bottomMargin: tile.baseSize * 0.08
                text: tile.entry ? tile.entry.display : ""
                color: "#ffffff"
                font.family: "Sora"
                font.weight: Font.DemiBold
                font.pixelSize: Math.max(10, tile.baseSize * 0.1)
                lineHeight: 0.98
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                style: Text.Raised
                styleColor: "#33000000"
            }

            // ---------------- capa de verdade
            Image {
                id: artFill
                anchors.fill: parent
                anchors.margins: -parent.width * 0.15
                source: art.source
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                sourceSize.width: 24
                sourceSize.height: 24
                visible: tile.hasArt
            }
            Rectangle {
                anchors.fill: parent
                color: "#59000000"
                visible: tile.hasArt
            }
            Image {
                id: art
                anchors.fill: parent
                anchors.margins: parent.width * 0.06
                source: tile.entry ? tile.entry.art : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                smooth: true
                sourceSize.width: Math.round(tile.baseSize * tile.selScale * tile.pixelRatio)
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            // ---------------- brilho que atravessa a capa ao selecionar
            Rectangle {
                id: shine
                width: tile.baseSize * 0.42
                height: tile.baseSize * 2
                y: -tile.baseSize * 0.5
                x: -width * 2
                rotation: 22
                visible: shineAnim.running
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#00ffffff" }
                    GradientStop { position: 0.5; color: "#66ffffff" }
                    GradientStop { position: 1.0; color: "#00ffffff" }
                }
            }
        }

        // borda fina e anel branco de foco
        Rectangle {
            anchors.fill: parent
            radius: tile.cornerRadius
            color: "transparent"
            border.width: 1
            border.color: "#26ffffff"
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: tile.cornerRadius + 4
            color: "transparent"
            border.width: 3
            border.color: "#f7ffffff"
            opacity: tile.selected && tile.showRing ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // coração dos favoritos
        Rectangle {
            visible: tile.entry !== null && tile.entry.fav === true
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: tile.baseSize * 0.06
            width: Math.round(tile.baseSize * 0.2)
            height: width
            radius: width / 2
            color: "#99000000"
            border.width: 1
            border.color: "#40ffffff"
            Canvas {
                anchors.centerIn: parent
                width: Math.round(parent.width * 0.56 * tile.pixelRatio)
                height: width
                scale: 1 / tile.pixelRatio
                renderTarget: Canvas.Image
                onPaint: {
                    var c = getContext("2d"), w = width, h = height;
                    c.reset();
                    c.fillStyle = "#ff5c8a";
                    c.beginPath();
                    c.moveTo(w * 0.5, h * 0.92);
                    c.bezierCurveTo(w * 0.05, h * 0.62, -w * 0.02, h * 0.18, w * 0.27, h * 0.1);
                    c.bezierCurveTo(w * 0.40, h * 0.06, w * 0.48, h * 0.16, w * 0.5, h * 0.26);
                    c.bezierCurveTo(w * 0.52, h * 0.16, w * 0.60, h * 0.06, w * 0.73, h * 0.1);
                    c.bezierCurveTo(w * 1.02, h * 0.18, w * 0.95, h * 0.62, w * 0.5, h * 0.92);
                    c.closePath();
                    c.fill();
                }
            }
        }
    }

    NumberAnimation {
        id: shineAnim
        target: shine
        property: "x"
        from: -shine.width * 2
        to: tile.baseSize + shine.width
        duration: 900
        easing.type: Easing.InOutQuad
    }
    Timer { id: shineDelay; interval: 160; onTriggered: shineAnim.restart() }
    onSelectedChanged: {
        if (selected) shineDelay.restart();
        else { shineDelay.stop(); shineAnim.stop(); }
    }

    MouseArea {
        anchors.fill: parent
        pressAndHoldInterval: 600
        onClicked: tile.tapped()
        onPressAndHold: tile.held()
    }
}
