import QtQuick 2.15

// Passeio pelo tema: cada passo espera um tempo, aperta botões e tira prints.
Item {
    id: top
    width: 1600
    height: 1068

    Loader {
        id: loader
        anchors.fill: parent
        focus: true
        source: "../../src/themes/hub-vidro/theme.qml"
    }

    function t() { return loader.item; }

    function fakeAch(total, got) {
        var names = ["Primeiro passo", "Moeda de ouro", "Sem perder vida", "Chefe do castelo", "Caminho secreto",
                     "Corrida contra o tempo", "Colecionador", "Mestre do salto", "Mundo completo", "Final verdadeiro"];
        var list = [];
        var pts = 0, ptsGot = 0;
        for (var i = 0; i < total; i++) {
            var earned = i < got;
            var p = [5, 10, 25, 50][i % 4];
            pts += p;
            if (earned) ptsGot += p;
            var day = 1 + (i * 3) % 27;
            var date = earned ? "2026-09-" + (day < 10 ? "0" : "") + day : "";
            list.push({ title: names[i % names.length] + (i >= names.length ? " " + (Math.floor(i / names.length) + 1) : ""),
                        desc: "Descrição da conquista número " + (i + 1) + ", do jeito que vem do RetroAchievements.",
                        points: p, badge: String(10000 + i * 97), earned: earned, date: date, when: date + " 10:00:00", order: i });
        }
        return { state: "ok", list: list, got: got, total: total, points: pts, pointsGot: ptsGot };
    }

    function injectRA() {
        var th = t();
        th.raIndex = {
            "supermarioworld": [{ got: 33, total: 96, consoleId: 3, gameId: 228 }],
            "kirbysuperstar": [{ got: 12, total: 66, consoleId: 3, gameId: 357 }],
            "pokemonemeraldversion": [{ got: 20, total: 70, consoleId: 5, gameId: 515 }]
        };
        th.raCatalogs = { 12: { "crashbandicoot": [30, 11240], "spyrodragon": [36, 11255] }, 2: { "supermario64": [120, 10003] } };
        th.raState = "ok";
        th.rebuildTrophies();
        th.achCache = { 228: fakeAch(96, 33), 357: fakeAch(66, 12), 11240: fakeAch(30, 0) };
    }

    property var steps: [
        [4500, function () { driver.shot("01-inicio"); }],
        [0,    function () { driver.key(Qt.Key_Right); }],
        [1300, function () { driver.shot("02-inicio-segundo"); }],
        [0,    function () { driver.key(Qt.Key_Left); }],
        // cartucho
        [1500, function () { driver.key(Qt.Key_Return); }],
        "frames:10-cartucho:20:140",
        [1200, function () { driver.shot("13-abrindo"); t().resetLaunch(); }],
        // disco
        [600,  function () { driver.key(Qt.Key_Right); driver.key(Qt.Key_Right); }],
        [1500, function () { driver.shot("19-disco-antes"); driver.key(Qt.Key_Return); }],
        "frames:20-disco:22:140",
        [1200, function () { t().resetLaunch(); }],
        // cartão
        [600,  function () { driver.key(Qt.Key_Right); }],
        [1500, function () { driver.shot("29-cartao-antes"); driver.key(Qt.Key_Return); }],
        "frames:30-cartao:20:140",
        [1200, function () { t().resetLaunch(); }],
        // PS2 sem emulador
        [600,  function () { driver.key(Qt.Key_Right); }],
        [1500, function () { driver.shot("40-ps2-sem-emulador"); driver.key(Qt.Key_Return); }],
        [900,  function () { driver.shot("41-aviso"); driver.key(Qt.Key_Return); }],
        // jogo sem capa (capa gerada) na fileira
        [600,  function () { driver.key(Qt.Key_Right); driver.key(Qt.Key_Right); driver.key(Qt.Key_Right); driver.key(Qt.Key_Right); }],
        [1500, function () { driver.shot("42-capa-gerada"); }],
        // página do jogo
        [0,    function () { driver.key(Qt.Key_Left); driver.key(Qt.Key_Left); driver.key(Qt.Key_Left); driver.key(Qt.Key_Left); driver.key(Qt.Key_Left); driver.key(Qt.Key_Left); driver.key(Qt.Key_Left); driver.key(Qt.Key_Left); }],
        [1200, function () { injectRA(); }],
        [800,  function () { driver.key(Qt.Key_I); }],
        [900,  function () { driver.shot("50-detalhes"); driver.key(Qt.Key_Right); }],
        [500,  function () { driver.shot("51-detalhes-favoritar"); driver.key(Qt.Key_Escape); }],
        [700,  function () { driver.shot("52-inicio-com-trofeus"); }],
        // biblioteca
        [0,    function () { driver.key(Qt.Key_E); }],
        [1600, function () { driver.shot("60-biblioteca"); driver.key(Qt.Key_Down); }],
        [900,  function () { driver.shot("61-biblioteca-desce"); driver.key(Qt.Key_Down); driver.key(Qt.Key_Down); driver.key(Qt.Key_Right); }],
        [900,  function () { driver.shot("62-biblioteca-mais"); driver.key(Qt.Key_Up); driver.key(Qt.Key_Up); driver.key(Qt.Key_Up); driver.key(Qt.Key_Up); driver.key(Qt.Key_Up); }],
        [900,  function () { driver.shot("63-ordem"); driver.key(Qt.Key_Right); }],
        [900,  function () { driver.shot("64-ordem-recentes"); driver.key(Qt.Key_Down); }],
        [700,  function () { driver.key(Qt.Key_I); }],
        [900,  function () { driver.shot("65-detalhes-biblioteca"); driver.key(Qt.Key_Escape); }],
        [600,  function () { driver.key(Qt.Key_Return); }],
        "frames:66-abrir-biblioteca:12:140",
        [1200, function () { t().resetLaunch(); }],
        // troféus
        [600,  function () { driver.key(Qt.Key_E); }],
        [1800, function () { driver.shot("70-trofeus"); driver.key(Qt.Key_Right); }],
        [900,  function () { driver.shot("71-conquistas"); driver.key(Qt.Key_Right); driver.key(Qt.Key_Right); driver.key(Qt.Key_Down); }],
        [900,  function () { driver.shot("72-conquista-escolhida"); driver.key(Qt.Key_Escape); driver.key(Qt.Key_Down); }],
        [1300, function () { driver.shot("73-segundo-jogo"); driver.key(Qt.Key_Down); driver.key(Qt.Key_Down); }],
        [1300, function () { driver.shot("74-jogo-sem-progresso"); }],
        // volta ao Início e fica parado (o registro mostra quantos quadros foram desenhados)
        [0,    function () { driver.key(Qt.Key_Q); driver.key(Qt.Key_Q); }],
        [22000, function () { driver.shot("80-parado"); }],
        [500,  function () { driver.quit(); }]
    ]

    property int stepIndex: -1
    property int frameLeft: 0
    property string frameName: ""
    property int frameNo: 0
    Timer {
        id: tick
        repeat: false
        onTriggered: top.next()
    }
    function next() {
        if (frameLeft > 0) {
            driver.shot(frameName + "-" + (frameNo < 10 ? "0" : "") + frameNo);
            frameNo++;
            frameLeft--;
            tick.restart();
            return;
        }
        stepIndex++;
        if (stepIndex >= steps.length) return;
        var s = steps[stepIndex];
        if (typeof s === "string") {
            var p = s.split(":");
            frameName = p[1];
            frameLeft = Number(p[2]);
            frameNo = 0;
            tick.interval = Number(p[3]);
            tick.restart();
            return;
        }
        tick.interval = Math.max(1, s[0]);
        pending = s[1];
        delayed.interval = Math.max(1, s[0]);
        delayed.restart();
    }
    property var pending: null
    Timer {
        id: delayed
        onTriggered: { if (top.pending) top.pending(); top.next(); }
    }
    Component.onCompleted: next()
}
