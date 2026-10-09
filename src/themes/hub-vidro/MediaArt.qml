import QtQuick 2.15
import QtGraphicalEffects 1.12

// A mídia do jogo desenhada (sem imitar nenhum produto real): cartucho, disco ou cartão,
// com a capa do jogo no rótulo. Usada atrás da caixa na vitrine e na animação de jogar.
Item {
    id: m

    property string kind: "disc"          // cart · disc · card
    property string art: ""
    property color tint: "#5a5f6b"
    property bool darkDisc: false          // disco preto (PlayStation)
    property real pixelRatio: 2

    // ---------------------------------------------------------------- disco
    Item {
        anchors.fill: parent
        visible: m.kind === "disc"

        Item {
            id: discFace
            anchors.fill: parent
            layer.enabled: m.kind === "disc"
            layer.textureSize: Qt.size(Math.round(width * m.pixelRatio), Math.round(height * m.pixelRatio))
            layer.smooth: true
            layer.effect: OpacityMask {
                maskSource: Rectangle { width: discFace.width; height: discFace.height; radius: width / 2 }
            }
            Rectangle { anchors.fill: parent; color: m.darkDisc ? "#111111" : "#cfd3da" }
            Image {
                anchors.fill: parent
                source: m.kind === "disc" ? m.art : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: Math.round(m.width * m.pixelRatio * 0.6)
            }
            // brilho de arco-íris do disco
            ConicalGradient {
                anchors.fill: parent
                angle: 30
                gradient: Gradient {
                    GradientStop { position: 0.00; color: "#00ffffff" }
                    GradientStop { position: 0.12; color: "#4dffffff" }
                    GradientStop { position: 0.22; color: "#26c9b8ff" }
                    GradientStop { position: 0.30; color: "#00ffffff" }
                    GradientStop { position: 0.55; color: "#33ffffff" }
                    GradientStop { position: 0.64; color: "#1f9fe8ff" }
                    GradientStop { position: 0.72; color: "#00ffffff" }
                    GradientStop { position: 1.00; color: "#00ffffff" }
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1, m.width * 0.006)
            border.color: "#59ffffff"
        }
        // anel prateado e furo central
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.32; height: width; radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#eef0f5" }
                GradientStop { position: 1.0; color: "#b9bdc7" }
            }
            border.width: 1; border.color: "#80ffffff"
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.15; height: width; radius: width / 2
            color: "#0b0c0f"
            border.width: 1; border.color: "#33000000"
        }
    }

    // ------------------------------------------------------------- cartucho
    Rectangle {
        anchors.fill: parent
        visible: m.kind === "cart"
        radius: m.width * 0.06
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#d6d8de" }
            GradientStop { position: 1.0; color: "#9da2ad" }
        }
        border.width: 1
        border.color: "#66ffffff"
        // sulcos da pegada
        Row {
            x: parent.width * 0.1
            y: parent.height * 0.05
            spacing: parent.width * 0.028
            Repeater {
                model: 14
                delegate: Rectangle { width: m.width * 0.012; height: m.height * 0.1; radius: 1; color: "#2e000000" }
            }
        }
        // rótulo com a capa
        Rectangle {
            x: parent.width * 0.1
            y: parent.height * 0.2
            width: parent.width * 0.8
            height: parent.height * 0.66
            radius: m.width * 0.025
            color: Qt.darker(m.tint, 1.6)
            clip: true
            Image {
                anchors.fill: parent
                source: m.kind === "cart" ? m.art : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: Math.round(m.width * m.pixelRatio * 0.8)
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: parent.radius
                border.width: 1
                border.color: "#40000000"
            }
        }
        // degrau embaixo
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.height * 0.09
            radius: parent.radius
            color: "#22000000"
        }
    }

    // ---------------------------------------------------------------- cartão
    Rectangle {
        anchors.fill: parent
        visible: m.kind === "card"
        radius: m.width * 0.08
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#3a3b42" }
            GradientStop { position: 1.0; color: "#1e1f24" }
        }
        border.width: 1
        border.color: "#40ffffff"
        // contatos no alto
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.04
            spacing: m.width * 0.04
            Repeater {
                model: 6
                delegate: Rectangle { width: m.width * 0.08; height: m.height * 0.05; radius: 1; color: "#c9a95a" }
            }
        }
        Rectangle {
            x: parent.width * 0.09
            y: parent.height * 0.14
            width: parent.width * 0.82
            height: parent.height * 0.78
            radius: m.width * 0.04
            color: Qt.darker(m.tint, 1.6)
            clip: true
            Image {
                anchors.fill: parent
                source: m.kind === "card" ? m.art : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: Math.round(m.width * m.pixelRatio)
            }
        }
    }
}
