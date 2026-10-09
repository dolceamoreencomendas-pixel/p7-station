import QtQuick 2.15
import QtGraphicalEffects 1.12
import "logic.js" as L

// Vitrine 3D do jogo selecionado: a caixa com lombada e, atrás dela, a mídia do console
// (cartucho, disco ou cartão). Ao jogar, a mídia sai da caixa e entra numa base desenhada
// para cada tipo (cartucho desce no encaixe, disco vai para a bandeja, cartão sobe na entrada),
// e a luz da base acende na cor do console. Nenhuma base imita um aparelho de verdade.
//
// Como o Qt Quick 2 não empilha rotações 3D, cada face é girada sozinha em torno da MESMA
// aresta (a borda esquerda da caixa). Assim a perspectiva das faces bate entre si.
// Ângulo positivo no eixo Y = lado direito se afasta (QMatrix4x4::projectedRotate).
Item {
    id: show

    property var entry: null
    property real swayAngle: 20
    property real pixelRatio: 2

    signal launchFinished()
    signal inserted()

    // largura da caixa, espessura, proporção (altura/largura sem capa) e tipo de mídia por console
    readonly property var cases: ({
        nes:       { w: 300, d: 40, ar: 1.38, media: "cart", spine: "#2a2a2e", label: "NES" },
        snes:      { w: 360, d: 46, ar: 0.72, media: "cart", spine: "#2b2b33", label: "SUPER NINTENDO" },
        n64:       { w: 360, d: 44, ar: 0.72, media: "cart", spine: "#26302a", label: "NINTENDO 64" },
        gb:        { w: 230, d: 20, ar: 1.0,  media: "cart", spine: "#3a3f2c", label: "GAME BOY" },
        gbc:       { w: 230, d: 20, ar: 1.0,  media: "cart", spine: "#3a2c4a", label: "GAME BOY COLOR" },
        gba:       { w: 230, d: 20, ar: 1.0,  media: "cart", spine: "#2c2f52", label: "GAME BOY ADVANCE" },
        nds:       { w: 240, d: 22, ar: 0.9,  media: "card", spine: "#3a3d44", label: "NINTENDO DS" },
        genesis:   { w: 260, d: 34, ar: 1.4,  media: "cart", spine: "#17181c", label: "MEGA DRIVE" },
        psx:       { w: 290, d: 24, ar: 1.0,  media: "disc", spine: "#1d1f24", label: "PlayStation" },
        ps2:       { w: 250, d: 30, ar: 1.4,  media: "disc", spine: "#141823", label: "PlayStation 2" },
        psp:       { w: 220, d: 22, ar: 1.7,  media: "disc", spine: "#15171c", label: "PSP" },
        dreamcast: { w: 290, d: 24, ar: 1.0,  media: "disc", spine: "#3a3d44", label: "Dreamcast" },
        gc:        { w: 250, d: 30, ar: 1.4,  media: "disc", spine: "#3b2f6a", label: "GAMECUBE" },
        wii:       { w: 250, d: 30, ar: 1.4,  media: "disc", spine: "#7d838c", label: "Wii" },
        wiiu:      { w: 250, d: 30, ar: 1.4,  media: "disc", spine: "#1b8fc4", label: "Wii U" },
        "switch":  { w: 230, d: 22, ar: 1.62, media: "card", spine: "#d42a20", label: "NINTENDO SWITCH" }
    })
    readonly property var spec: entry && cases[entry.sys] ? cases[entry.sys]
                               : { w: 270, d: 28, ar: 1.4, media: "disc", spine: "#2a2d33", label: "" }
    readonly property bool hasArt: coverArt.status === Image.Ready && coverArt.implicitWidth > 0
    readonly property real aspect: hasArt ? coverArt.implicitHeight / coverArt.implicitWidth : spec.ar
    // cabe na vitrine: no máximo 74% da altura e 62% da largura
    readonly property real fit: Math.min(1, height * 0.74 / (spec.w * aspect), width * 0.62 / spec.w)
    readonly property real boxW: Math.round(spec.w * fit)
    readonly property real boxH: Math.round(boxW * aspect)
    readonly property real depth: Math.round(spec.d * fit)
    readonly property var colors: entry ? L.coverColors(entry.color, entry.title) : ["#4a4f58", "#15171c"]
    readonly property color consoleColor: entry ? Qt.lighter(entry.color, 1.35) : "#9be7ff"

    // entrada suave quando troca de jogo
    property real enter: 1
    onEntryChanged: { if (!launching) { enterAnim.restart(); wake(); } }
    NumberAnimation { id: enterAnim; target: show; property: "enter"; from: 0; to: 1; duration: 460; easing.type: Easing.OutCubic }

    // O movimento dura alguns segundos depois de escolher um jogo e para: parado no menu,
    // a tela não precisa ser redesenhada (economiza bateria e não esquenta o tablet).
    property bool active: true
    property bool alive: true
    readonly property bool moving: show.visible && show.active && show.alive && !launching
    function wake() { alive = true; idleTimer.restart(); }
    Timer { id: idleTimer; interval: 5000; running: true; onTriggered: show.alive = false }
    onActiveChanged: if (active) wake()

    SequentialAnimation on swayAngle {
        loops: Animation.Infinite
        running: show.visible
        paused: show.visible && !show.moving
        NumberAnimation { from: 14; to: 30; duration: 9000; easing.type: Easing.InOutSine }
        NumberAnimation { from: 30; to: 14; duration: 9000; easing.type: Easing.InOutSine }
    }

    // ===================================================== animação de jogar
    property real lt: 0                       // progresso 0 → 1
    property string lkind: ""                 // mídia em movimento ("" = parado)
    readonly property bool launching: lkind !== ""
    property var kx: []; property var ky: []; property var kr: []; property var ks: []
    property real fw: 100; property real fh: 100           // tamanho da mídia voando
    property bool didInsert: false

    readonly property real rigOut: launching ? kf([[0, 0], [0.42, 1]], lt) : 0
    readonly property real angle: swayAngle + 58 * rigOut

    function ease(p) { return p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2; }
    // valor numa sequência de quadros-chave [[tempo, valor], ...], suavizado entre eles
    function kf(keys, t) {
        if (!keys || !keys.length) return 0;
        if (t <= keys[0][0]) return keys[0][1];
        for (var i = 1; i < keys.length; i++) {
            if (t <= keys[i][0]) {
                var a = keys[i - 1], b = keys[i];
                var p = (t - a[0]) / Math.max(0.0001, b[0] - a[0]);
                return a[1] + (b[1] - a[1]) * ease(p);
            }
        }
        return keys[keys.length - 1][1];
    }

    // medidas das bases (calculadas a partir do tamanho da vitrine e da mídia)
    readonly property real cartDockW: Math.min(width * 0.84, Math.max(420, fw + 150))
    readonly property real cartDockH: Math.max(160, fh * 0.72 + 24)
    readonly property real cartDockX: (width - cartDockW) / 2
    readonly property real cartDockY: height - cartDockH - 4
    readonly property real frontW: 180
    readonly property real frontH: Math.min(height * 0.86, 440)
    readonly property real frontX: width * 0.64
    readonly property real frontY: (height - frontH) / 2
    readonly property real trayS: Math.min(frontH - 70, width * 0.54)
    readonly property real trayOutX: frontX - trayS + 24
    readonly property real trayInX: frontX + frontW / 2 + 2
    readonly property real cardDevW: Math.min(width * 0.72, 420)
    readonly property real cardDevH: Math.max(150, fh * 0.78 + 26)
    readonly property real cardDevX: (width - cardDevW) / 2
    readonly property real cardDevY: -24

    function launch() {
        if (launching || !entry) return;
        var c = media.mapToItem(show, media.width / 2, media.height / 2);
        var sx = c.x, sy = c.y;
        var k = spec.media;
        fw = media.width;
        fh = media.height;
        var cx = width / 2;
        if (k === "cart") {
            var top = cartDockY;
            var fin = top + fh * 0.14;
            kx = [[0, sx], [0.22, sx + 70], [0.48, cx]];
            ky = [[0, sy], [0.22, sy - 40], [0.48, top - fh / 2 - 46], [0.62, top - fh / 2 - 46], [0.84, fin + 12], [0.91, fin - 6], [1, fin]];
            kr = [[0, 0], [0.22, 8], [0.48, 0]];
            ks = [[0, 1]];
        } else if (k === "disc") {
            var wx = trayOutX + trayS / 2, wy = height / 2;
            var target = (trayS - 44) * 0.94 / fw;
            kx = [[0, sx], [0.3, wx]];
            ky = [[0, sy], [0.12, sy - 30], [0.3, wy]];
            kr = [];
            ks = [[0, 1], [0.3, target]];
        } else {
            var bottom = cardDevY + cardDevH;
            var cfin = bottom - fh * 0.22;
            kx = [[0, sx], [0.25, sx + 60], [0.55, cx]];
            ky = [[0, sy], [0.25, sy + 30], [0.55, bottom + fh / 2 + 70], [0.68, bottom + fh / 2 + 70], [0.9, cfin - 12], [1, cfin]];
            kr = [[0, 0], [0.25, 12], [0.55, 0]];
            ks = [[0, 1]];
        }
        didInsert = false;
        lt = 0;
        lkind = k;
        launchAnim.duration = k === "disc" ? 1900 : (k === "card" ? 1650 : 1750);
        launchAnim.restart();
    }
    function resetLaunch() {
        launchAnim.stop();
        lkind = "";
        lt = 0;
        didInsert = false;
    }
    NumberAnimation {
        id: launchAnim
        target: show; property: "lt"; from: 0; to: 1
        easing.type: Easing.Linear
        onFinished: show.launchFinished()
    }
    readonly property real insertAt: lkind === "disc" ? 0.97 : (lkind === "card" ? 0.9 : 0.84)
    onLtChanged: if (launching && !didInsert && lt >= insertAt) { didInsert = true; inserted(); }
    readonly property bool ledOn: launching && lt >= insertAt

    // sombra no "chão"
    RadialGradient {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: parent.width * 0.7
        height: 50
        opacity: 0.9 * show.enter * (1 - show.rigOut)
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#8c000000" }
            GradientStop { position: 0.5; color: "transparent" }
        }
    }

    // ------------------------------------------------ bandeja do disco (atrás da frente)
    Item {
        id: trayClip
        x: 0; y: 0
        width: show.frontX + show.frontW / 2
        height: show.height
        clip: true
        visible: show.lkind === "disc"
        z: 3

        Rectangle {
            id: tray
            width: show.trayS
            height: show.trayS
            y: (show.height - height) / 2
            x: show.launching ? show.kf([[0, show.trayInX], [0.3, show.trayOutX], [0.62, show.trayOutX], [1, show.trayInX]], show.lt) : show.trayInX
            radius: 30
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2c2a42" }
                GradientStop { position: 1.0; color: "#15131f" }
            }
            border.width: 1
            border.color: "#26ffffff"
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 44; height: width; radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#0d0c16" }
                    GradientStop { position: 1.0; color: "#1f1d2e" }
                }
                border.width: 1
                border.color: "#14ffffff"
                Rectangle { anchors.centerIn: parent; width: parent.width * 0.16; height: width; radius: width / 2; color: "#3a3850" }
            }
            MediaArt {
                id: trayDisc
                anchors.centerIn: parent
                width: (show.trayS - 44) * 0.94
                height: width
                kind: "disc"
                art: show.entry ? show.entry.art : ""
                tint: show.entry ? show.entry.color : "#5a5f6b"
                darkDisc: show.entry !== null && show.entry.sys === "psx"
                pixelRatio: show.pixelRatio
                rotation: show.lt * 1260
                visible: show.launching && show.lt >= 0.3
            }
        }
    }

    // ------------------------------------------------ caixa
    Item {
        id: rig
        z: 2
        width: show.boxW
        height: show.boxH
        x: (show.width - width) / 2 + 18 + (1 - show.enter) * 40 - 170 * show.rigOut
        y: (show.height - height) / 2 - 8 + floatY
        opacity: show.enter * (1 - show.rigOut)
        visible: opacity > 0

        property real floatY: 0
        SequentialAnimation on floatY {
            loops: Animation.Infinite
            running: show.visible
            paused: show.visible && !show.moving
            NumberAnimation { from: -7; to: 8; duration: 6000; easing.type: Easing.InOutSine }
            NumberAnimation { from: 8; to: -7; duration: 6000; easing.type: Easing.InOutSine }
        }

        // mídia atrás da caixa, no mesmo plano inclinado
        Item {
            id: media
            readonly property string kind: show.spec.media
            width: kind === "disc" ? Math.min(show.boxH * 0.8, show.boxW * 1.05) : (kind === "cart" ? show.boxW * 0.66 : show.boxW * 0.52)
            height: kind === "disc" ? width : (kind === "cart" ? width * 0.78 : width * 1.15)
            x: kind === "disc" ? show.boxW * 0.42 : (kind === "cart" ? show.boxW * 0.55 : show.boxW * 0.7)
            y: kind === "disc" ? (show.boxH - height) / 2 - 10 : (kind === "cart" ? -height * 0.3 : show.boxH * 0.16)
            visible: !show.launching
            transform: Rotation { origin.x: -media.x; origin.y: 0; axis { x: 0; y: 1; z: 0 } angle: show.angle }

            MediaArt {
                id: rigMedia
                anchors.fill: parent
                kind: media.kind
                art: show.entry ? show.entry.art : ""
                tint: show.entry ? show.entry.color : "#5a5f6b"
                darkDisc: show.entry !== null && show.entry.sys === "psx"
                pixelRatio: show.pixelRatio
                NumberAnimation on rotation {
                    from: 0; to: 360; duration: 18000; loops: Animation.Infinite
                    running: media.kind === "disc" && show.visible
                    paused: media.kind === "disc" && show.visible && !show.moving
                }
            }
        }

        // lombada (face esquerda, girada para trás em torno da mesma aresta)
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
            transform: Rotation { origin.x: show.depth; origin.y: 0; axis { x: 0; y: 1; z: 0 } angle: show.angle - 90 }

            Text {
                anchors.centerIn: parent
                rotation: -90
                text: show.spec.label
                color: "#d9ffffff"
                font.family: "Manrope"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 2
            }
        }

        // frente da caixa
        Item {
            id: frontFace
            width: show.boxW
            height: show.boxH
            transform: Rotation { origin.x: 0; origin.y: 0; axis { x: 0; y: 1; z: 0 } angle: show.angle }

            // capa gerada (jogo sem arte): degradê, faixa do console e o nome grande
            Rectangle {
                anchors.fill: parent
                radius: 6
                visible: !show.hasArt
                gradient: Gradient {
                    GradientStop { position: 0.0; color: show.colors[0] }
                    GradientStop { position: 1.0; color: show.colors[1] }
                }
                RadialGradient {
                    anchors.fill: parent
                    horizontalOffset: -width * 0.3
                    verticalOffset: -height * 0.35
                    horizontalRadius: width
                    verticalRadius: height
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#38ffffff" }
                        GradientStop { position: 0.6; color: "#00ffffff" }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: Math.max(26, parent.height * 0.09)
                    color: "#40000000"
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 18
                        text: show.spec.label.toUpperCase()
                        color: "#e6ffffff"
                        font.family: "Manrope"
                        font.weight: Font.Bold
                        font.pixelSize: 12
                        font.letterSpacing: 2.4
                    }
                }
                Text {
                    x: 22
                    width: parent.width - 44
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 24
                    text: show.entry ? show.entry.display : ""
                    color: "#ffffff"
                    font.family: "Sora"
                    font.weight: Font.DemiBold
                    font.pixelSize: Math.max(22, Math.min(38, show.boxW * 0.11))
                    lineHeight: 1.0
                    wrapMode: Text.WordWrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    style: Text.Raised
                    styleColor: "#40000000"
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
                sourceSize.width: Math.round(Math.min(900, show.boxW * show.pixelRatio))
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

    // ------------------------------------------------ mídia voando
    MediaArt {
        id: flyer
        z: 4
        visible: show.launching && !(show.lkind === "disc" && show.lt >= 0.3)
        kind: show.lkind || "disc"
        width: show.fw
        height: show.fh
        x: show.kf(show.kx, show.lt) - width / 2
        y: show.kf(show.ky, show.lt) - height / 2
        rotation: show.lkind === "disc" ? show.lt * 1260 : show.kf(show.kr, show.lt)
        scale: show.kf(show.ks, show.lt)
        art: show.entry ? show.entry.art : ""
        tint: show.entry ? show.entry.color : "#5a5f6b"
        darkDisc: show.entry !== null && show.entry.sys === "psx"
        pixelRatio: show.pixelRatio
    }

    // ------------------------------------------------ bases (por cima da mídia: ela "entra")
    // corpo comum das bases
    component DockBody: Rectangle {
        radius: 28
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#2d2b45" }
            GradientStop { position: 1.0; color: "#13111d" }
        }
        border.width: 1
        border.color: "#29ffffff"
        Rectangle {
            anchors.top: parent.top; anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - parent.radius * 2; height: 1
            color: "#4dffffff"
        }
        Text {
            x: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            text: "P7"
            color: "#1fffffff"
            font.family: "Sora"
            font.weight: Font.DemiBold
            font.pixelSize: 15
            font.letterSpacing: 3
        }
    }
    component Led: Item {
        id: led
        property bool lit: false
        property color tint: "#5ff0a8"
        width: 12; height: 12
        RectangularGlow {
            anchors.fill: dot
            glowRadius: 10
            spread: 0.3
            cornerRadius: 16
            color: led.tint
            opacity: led.lit ? 0.9 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
        Rectangle {
            id: dot
            anchors.fill: parent
            radius: 6
            color: led.lit ? Qt.lighter(led.tint, 1.25) : "#2a2838"
            border.width: 1
            border.color: led.lit ? "#ccffffff" : "#1fffffff"
        }
    }

    // cartucho: base embaixo com o encaixe em cima
    Item {
        id: cartDock
        z: 5
        visible: show.lkind === "cart"
        x: show.cartDockX
        y: show.cartDockY + (show.launching ? show.kf([[0, 50], [0.25, 0]], show.lt) : 0)
        width: show.cartDockW
        height: show.cartDockH
        opacity: show.launching ? show.kf([[0, 0], [0.25, 1]], show.lt) : 0
        DockBody { anchors.fill: parent }
        RectangularGlow {
            anchors.fill: cartSlot
            glowRadius: 14; spread: 0.15; cornerRadius: 22
            color: show.consoleColor
            opacity: show.ledOn ? 0.75 : 0.35
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
        Rectangle {
            id: cartSlot
            anchors.horizontalCenter: parent.horizontalCenter
            y: -1
            width: show.fw + 26
            height: 14
            radius: 7
            color: "#05040b"
        }
        Led { anchors.right: parent.right; anchors.rightMargin: 34; anchors.bottom: parent.bottom; anchors.bottomMargin: 26; lit: show.ledOn; tint: show.consoleColor }
    }

    // disco: corpo da frente, a bandeja entra nele
    Item {
        id: discFront
        z: 5
        visible: show.lkind === "disc"
        x: show.frontX
        y: show.frontY + (show.launching ? show.kf([[0, 50], [0.25, 0]], show.lt) : 0)
        width: show.frontW
        height: show.frontH
        opacity: show.launching ? show.kf([[0, 0], [0.25, 1]], show.lt) : 0
        DockBody { anchors.fill: parent; radius: 32 }
        // abertura da bandeja (risco escuro com brilho na cor do console)
        RectangularGlow {
            anchors.fill: trayMouth
            glowRadius: 10; spread: 0.1; cornerRadius: 12
            color: show.consoleColor
            opacity: show.ledOn ? 0.7 : 0.3
        }
        Rectangle {
            id: trayMouth
            x: -1
            y: (parent.height - height) / 2
            width: 12
            height: show.trayS + 10
            radius: 6
            color: "#05040b"
        }
        Led { x: 30; anchors.bottom: parent.bottom; anchors.bottomMargin: 34; lit: show.ledOn; tint: show.consoleColor }
    }

    // cartão: aparelho desce do alto, entrada embaixo
    Item {
        id: cardDev
        z: 5
        visible: show.lkind === "card"
        x: show.cardDevX
        y: show.cardDevY + (show.launching ? show.kf([[0, -50], [0.25, 0]], show.lt) : 0)
        width: show.cardDevW
        height: show.cardDevH
        opacity: show.launching ? show.kf([[0, 0], [0.25, 1]], show.lt) : 0
        DockBody { anchors.fill: parent }
        RectangularGlow {
            anchors.fill: cardSlot
            glowRadius: 12; spread: 0.15; cornerRadius: 20
            color: show.consoleColor
            opacity: show.ledOn ? 0.75 : 0.35
        }
        Rectangle {
            id: cardSlot
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -1
            width: show.fw + 22
            height: 12
            radius: 6
            color: "#05040b"
        }
        Led { anchors.right: parent.right; anchors.rightMargin: 32; y: 40; lit: show.ledOn; tint: show.consoleColor }
    }
}
