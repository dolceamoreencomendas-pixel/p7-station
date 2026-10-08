import QtQuick 2.15

// Painel de vidro líquido.
// Lê o fundo já desfocado (uma única textura para a tela toda, refeita só quando o fundo muda),
// entorta essa imagem perto das bordas como uma lente, realça a cor e desenha um filete de luz.
// Se o shader não compilar no aparelho, cai para o vidro translúcido simples.
Rectangle {
    id: glass

    property var backdrop: null      // ShaderEffectSource com o fundo desfocado (cobre o palco)
    property var stageItem: null     // item do palco, para saber onde o painel está
    property real refraction: 14     // em px: quanto a borda entorta a imagem
    property color tint: "#14ffffff"

    radius: 24
    readonly property bool liquid: backdrop !== null && stageItem !== null && fx.status === ShaderEffect.Compiled

    color: liquid ? "transparent" : "#14ffffff"
    border.width: liquid ? 0 : 1
    border.color: "#1cffffff"

    // posição do painel no palco (normalizada); atualizada quando ele se move
    property rect area: Qt.rect(0, 0, 0, 0)
    function updateArea() {
        if (!stageItem || stageItem.width <= 0 || stageItem.height <= 0) return;
        var p = glass.mapToItem(stageItem, 0, 0);
        var r = Qt.rect(p.x / stageItem.width, p.y / stageItem.height,
                        glass.width / stageItem.width, glass.height / stageItem.height);
        if (r.x !== area.x || r.y !== area.y || r.width !== area.width || r.height !== area.height)
            area = r;
    }
    onXChanged: updateArea()
    onYChanged: updateArea()
    onWidthChanged: updateArea()
    onHeightChanged: updateArea()
    onVisibleChanged: updateArea()
    Component.onCompleted: updateArea()
    // painéis que mudam de lugar junto com o pai (troca de aba) se reposicionam aqui
    Timer { interval: 120; repeat: true; running: glass.visible && glass.liquid; onTriggered: glass.updateArea() }

    ShaderEffect {
        id: fx
        anchors.fill: parent
        visible: glass.backdrop !== null && glass.stageItem !== null
        z: -1

        property variant src: glass.backdrop
        property rect area: glass.area
        property size sizePx: Qt.size(glass.width, glass.height)
        property real radiusPx: glass.radius
        property real strength: glass.refraction
        property color tintColor: glass.tint

        fragmentShader: "
            #ifdef GL_ES
            precision highp float;
            #endif
            varying vec2 qt_TexCoord0;
            uniform float qt_Opacity;
            uniform sampler2D src;
            uniform vec4 area;
            uniform vec2 sizePx;
            uniform float radiusPx;
            uniform float strength;
            uniform vec4 tintColor;

            float sdRound(vec2 p, vec2 b, float r) {
                vec2 q = abs(p) - b + vec2(r);
                return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
            }

            void main() {
                vec2 px = qt_TexCoord0 * sizePx;
                vec2 c = px - sizePx * 0.5;
                float r = min(radiusPx, min(sizePx.x, sizePx.y) * 0.5);
                float d = sdRound(c, sizePx * 0.5, r);
                float inside = 1.0 - smoothstep(-0.75, 0.75, d);

                // perto da borda a imagem é puxada para o centro, como uma lente
                float band = max(min(sizePx.x, sizePx.y) * 0.45, 1.0);
                float edge = 1.0 - clamp(-d / band, 0.0, 1.0);
                edge = edge * edge * edge;
                vec2 n = c / max(length(c), 0.001);
                vec2 uv = qt_TexCoord0 - n * edge * strength / sizePx;
                vec2 tuv = area.xy + clamp(uv, 0.0, 1.0) * area.zw;

                vec3 col = texture2D(src, tuv).rgb;
                float l = dot(col, vec3(0.299, 0.587, 0.114));
                col = mix(vec3(l), col, 1.45) * 1.05;
                col = mix(col, tintColor.rgb, tintColor.a);

                // brilho: filete de luz na borda (mais forte em cima à esquerda) e reflexo suave no topo
                float rim = 1.0 - smoothstep(0.0, 1.6, -d);
                float lightDir = clamp(dot(-n, normalize(vec2(-0.55, -0.85))) * 0.5 + 0.5, 0.0, 1.0);
                col += rim * (0.10 + 0.45 * lightDir * lightDir);
                col += (1.0 - smoothstep(0.0, 0.55, qt_TexCoord0.y)) * 0.05;
                col -= (1.0 - smoothstep(0.0, 1.2, -d)) * step(0.5, qt_TexCoord0.y) * 0.04;

                gl_FragColor = vec4(col, 1.0) * inside * qt_Opacity;
            }"
    }

    // filete de luz no vidro simples (sem shader)
    Rectangle {
        visible: !glass.liquid
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.leftMargin: glass.radius * 0.6
        anchors.rightMargin: glass.radius * 0.6
        height: 1
        color: "#26ffffff"
    }
}
