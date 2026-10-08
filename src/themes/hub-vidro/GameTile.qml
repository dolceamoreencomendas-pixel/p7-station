import QtQuick 2.15
import QtGraphicalEffects 1.12

// Capa de um jogo: arte quando existe, senão um bloco na cor do console com a inicial.
Item {
    id: tile

    property var entry: null
    property bool selected: false
    property real baseSize: 132
    property real selectedSize: 176
    property real pixelRatio: 2

    signal tapped()

    width: selected ? selectedSize : baseSize
    height: width
    opacity: selected ? 1.0 : 0.72

    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 260 } }

    readonly property color tint: entry ? entry.color : "#4a4f58"
    readonly property real cornerRadius: selected ? 28 : 22

    // Anel discreto de foco
    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: tile.cornerRadius + 6
        color: "#10ffffff"
        visible: tile.selected
    }

    Item {
        id: card
        anchors.fill: parent

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: card.width
                height: card.height
                radius: tile.cornerRadius
            }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(tile.tint, 1.15) }
                GradientStop { position: 1.0; color: Qt.darker(tile.tint, 2.8) }
            }
        }

        Text {
            anchors.centerIn: parent
            text: tile.entry ? tile.entry.mono : ""
            color: "#66ffffff"
            font.family: "Roboto"
            font.weight: Font.Light
            font.pixelSize: tile.width * 0.32
            visible: art.status !== Image.Ready
        }

        // Mesmo padrão para todos os consoles: a capa inteira dentro do quadrado (caixa deitada
        // do SNES, em pé do PS2/Switch...) e o espaço que sobra preenchido pela própria capa
        // desfocada. O "desfoque" é a capa carregada em 24 px e ampliada: não custa nada para a GPU.
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
            opacity: art.status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
        Rectangle {
            anchors.fill: parent
            color: "#66000000"
            visible: art.status === Image.Ready
        }

        Image {
            id: art
            anchors.fill: parent
            anchors.margins: parent.width * 0.07
            source: tile.entry ? tile.entry.art : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            smooth: true
            sourceSize.width: tile.selectedSize * tile.pixelRatio
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    // Borda fina; mais clara quando selecionado
    Rectangle {
        anchors.fill: parent
        radius: tile.cornerRadius
        color: "transparent"
        border.width: 1
        border.color: tile.selected ? "#8cffffff" : "#18ffffff"
    }

    // Coração dos favoritos, num selo de vidro no canto
    Rectangle {
        visible: tile.entry !== null && tile.entry.fav === true
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: tile.width * 0.06
        width: Math.round(tile.width * 0.2)
        height: width
        radius: width / 2
        color: "#99000000"
        border.width: 1
        border.color: "#40ffffff"
        Canvas {
            id: heart
            anchors.centerIn: parent
            width: Math.round(parent.width * 0.56)
            height: width
            onWidthChanged: requestPaint()
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

    MouseArea {
        anchors.fill: parent
        onClicked: tile.tapped()
    }
}
