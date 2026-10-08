import QtQuick 2.15
import QtGraphicalEffects 1.12

// Vitrine 3D do jogo selecionado: a caixa com lombada e, atrás dela, a mídia do console
// (cartucho do SNES, CD/DVD dos PlayStation e Wii U, cartão do Switch).
//
// Como o Qt Quick 2 não empilha rotações 3D, cada face é girada sozinha em torno da MESMA
// aresta (a borda esquerda da caixa). Assim a perspectiva das faces bate entre si.
// Ângulo positivo no eixo Y = lado direito se afasta (QMatrix4x4::projectedRotate).
Item {
    id: show

    property var entry: null
    property real swayAngle: 20

    // largura da caixa, espessura e tipo de mídia por console
    readonly property var cases: ({
        snes:   { w: 330, d: 46, media: "cart", spine: "#2b2b33", label: "SUPER NINTENDO" },
        psx:    { w: 270, d: 24, media: "disc", spine: "#1d1f24", label: "PlayStation" },
        ps2:    { w: 228, d: 30, media: "disc", spine: "#141823", label: "PlayStation 2" },
        wiiu:   { w: 228, d: 30, media: "disc", spine: "#1b8fc4", label: "Wii U" },
        "switch": { w: 210, d: 22, media: "card", spine: "#d42a20", label: "NINTENDO SWITCH" }
    })
    readonly property var spec: entry && cases[entry.sys] ? cases[entry.sys]
                               : { w: 260, d: 28, media: "disc", spine: "#2a2d33", label: "" }

    readonly property real boxW: spec.w
    readonly property real boxH: coverArt.status === Image.Ready && coverArt.implicitWidth > 0
                                 ? Math.round(boxW * coverArt.implicitHeight / coverArt.implicitWidth)
                                 : Math.round(boxW * 1.4)
    readonly property real depth: spec.d

    // entrada suave quando troca de jogo
    property real enter: 1
    onEntryChanged: { enterAnim.restart(); }
    NumberAnimation { id: enterAnim; target: show; property: "enter"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }

    SequentialAnimation on swayAngle {
        loops: Animation.Infinite
        running: show.visible
        NumberAnimation { from: 12; to: 30; duration: 9000; easing.type: Easing.InOutSine }
        NumberAnimation { from: 30; to: 12; duration: 9000; easing.type: Easing.InOutSine }
    }

    // sombra no "chão"
    RadialGradient {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        width: parent.width * 0.7
        height: 46
        opacity: 0.9 * show.enter
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#8c000000" }
            GradientStop { position: 0.5; color: "transparent" }
        }
    }

    Item {
        id: rig
        width: show.boxW
        height: show.boxH
        x: (show.width - width) / 2 + (1 - show.enter) * 40
        y: (show.height - height) / 2 - 10 + floatY
        opacity: show.enter

        property real floatY: 0
        SequentialAnimation on floatY {
            loops: Animation.Infinite
            running: show.visible
            NumberAnimation { from: -6; to: 8; duration: 6000; easing.type: Easing.InOutSine }
            NumberAnimation { from: 8; to: -6; duration: 6000; easing.type: Easing.InOutSine }
        }

        // ---------------- mídia (atrás da caixa, no mesmo plano inclinado)
        Item {
            id: media
            readonly property string kind: show.spec.media
            width: kind === "disc" ? show.boxH * 0.78 : (kind === "cart" ? show.boxW * 0.66 : show.boxW * 0.5)
            height: kind === "disc" ? width : (kind === "cart" ? width * 0.78 : width * 1.15)
            x: kind === "disc" ? show.boxW * 0.42 : (kind === "cart" ? show.boxW * 0.55 : show.boxW * 0.72)
            y: kind === "disc" ? (show.boxH - height) / 2 - 10 : (kind === "cart" ? -height * 0.28 : show.boxH * 0.18)
            transform: Rotation { origin.x: -media.x; origin.y: 0; axis { x: 0; y: 1; z: 0 } angle: show.swayAngle }

            // disco
            Item {
                id: discSpin
                anchors.fill: parent
                visible: media.kind === "disc"
                NumberAnimation on rotation { from: 0; to: 360; duration: 18000; loops: Animation.Infinite; running: discSpin.visible && show.visible }

                Item {
                    id: discFace
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle { width: discFace.width; height: discFace.height; radius: width / 2 }
                    }
                    Rectangle { anchors.fill: parent; color: show.entry && show.entry.sys === "psx" ? "#111111" : "#cfd3da" }
                    Image {
                        anchors.fill: parent
                        source: show.entry ? show.entry.art : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 360
                    }
                    ConicalGradient {
                        anchors.fill: parent
                        angle: 30
                        gradient: Gradient {
                            GradientStop { position: 0.00; color: "#00ffffff" }
                            GradientStop { position: 0.12; color: "#40ffffff" }
                            GradientStop { position: 0.25; color: "#00ffffff" }
                            GradientStop { position: 0.55; color: "#2effffff" }
                            GradientStop { position: 0.70; color: "#00ffffff" }
                            GradientStop { position: 1.00; color: "#00ffffff" }
                        }
                    }
                }
                // anel prateado e furo central
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.32; height: width; radius: width / 2
                    color: "#d9dce3"
                    border.width: 1; border.color: "#66ffffff"
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.17; height: width; radius: width / 2
                    color: "#0b0c0f"
                }
            }

            // cartucho
            Rectangle {
                anchors.fill: parent
                visible: media.kind === "cart"
                radius: 14
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#cbc9c4" }
                    GradientStop { position: 1.0; color: "#a5a39e" }
                }
                border.width: 1
                border.color: "#55ffffff"
                Row {
                    x: parent.width * 0.08; y: 8
                    spacing: 6
                    Repeater {
                        model: Math.floor(parent.parent.width * 0.84 / 9)
                        delegate: Rectangle { width: 3; height: 22; radius: 1; color: "#26000000" }
                    }
                }
                Rectangle {
                    x: parent.width * 0.12; y: 40
                    width: parent.width * 0.76; height: parent.height - 56
                    radius: 5; color: "#222"; clip: true
                    Image {
                        anchors.fill: parent
                        source: show.entry ? show.entry.art : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 320
                    }
                }
            }

            // cartão do Switch
            Rectangle {
                anchors.fill: parent
                visible: media.kind === "card"
                radius: 10
                color: "#2a2b30"
                border.width: 1
                border.color: "#33ffffff"
                Rectangle {
                    x: parent.width * 0.08; y: parent.height * 0.12
                    width: parent.width * 0.84; height: parent.height * 0.8
                    radius: 4; color: "#3a3b40"; clip: true
                    Image {
                        anchors.fill: parent
                        source: show.entry ? show.entry.art : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 240
                    }
                }
            }
        }

        // ---------------- lombada (face esquerda, girada para trás em torno da mesma aresta)
        Rectangle {
            id: spineFace
            x: -show.depth
            width: show.depth
            height: show.boxH
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.darker(show.spec.spine, 1.8) }
                GradientStop { position: 1.0; color: show.spec.spine }
            }
            transform: Rotation { origin.x: show.depth; origin.y: 0; axis { x: 0; y: 1; z: 0 } angle: show.swayAngle - 90 }

            Text {
                anchors.centerIn: parent
                rotation: -90
                text: show.spec.label
                color: "#d9ffffff"
                font.family: "Roboto"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 2
            }
        }

        // ---------------- frente da caixa
        Item {
            id: frontFace
            width: show.boxW
            height: show.boxH
            transform: Rotation { origin.x: 0; origin.y: 0; axis { x: 0; y: 1; z: 0 } angle: show.swayAngle }

            Rectangle {
                anchors.fill: parent
                radius: 4
                gradient: Gradient {
                    GradientStop { position: 0.0; color: show.entry ? Qt.lighter(show.entry.color, 1.1) : "#4a4f58" }
                    GradientStop { position: 1.0; color: show.entry ? Qt.darker(show.entry.color, 2.6) : "#1a1c20" }
                }
                Text {
                    anchors.centerIn: parent
                    visible: coverArt.status !== Image.Ready
                    text: show.entry ? show.entry.mono : ""
                    color: "#66ffffff"
                    font.family: "Roboto"
                    font.weight: Font.Light
                    font.pixelSize: 96
                }
            }
            Image {
                id: coverArt
                anchors.fill: parent
                source: show.entry ? show.entry.art : ""
                fillMode: Image.Stretch
                asynchronous: true
                cache: true
                smooth: true
                sourceSize.width: 640
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }
            }
            // reflexo de luz no plástico
            LinearGradient {
                anchors.fill: parent
                start: Qt.point(0, 0)
                end: Qt.point(width, height * 0.6)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#38ffffff" }
                    GradientStop { position: 0.38; color: "#00ffffff" }
                    GradientStop { position: 0.75; color: "#00ffffff" }
                    GradientStop { position: 1.0; color: "#14ffffff" }
                }
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: 4
                border.width: 1
                border.color: "#1fffffff"
            }
        }
    }
}
