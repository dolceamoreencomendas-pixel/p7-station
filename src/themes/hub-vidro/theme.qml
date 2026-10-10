import QtQuick 2.15
import QtQuick.Window 2.15
import QtGraphicalEffects 1.12
import QtMultimedia 5.8
import "logic.js" as L
import "config.js" as Cfg
import "emulators.js" as EM

// Hub Vidro — tema do Pegasus para o Xiaomi Pad 7 com controle.
// Abas: Início (o jogo em destaque + recentes), Biblioteca (prateleiras por console),
// Troféus (RetroAchievements, com as conquistas de cada jogo). Quadrado abre a página do jogo.
FocusScope {
    id: root
    focus: true

    // fontes do P7 Station (Sora nos títulos, Manrope no resto; licença OFL, junto dos arquivos)
    FontLoader { source: "fonts/Sora-Light.ttf" }
    FontLoader { source: "fonts/Sora-Regular.ttf" }
    FontLoader { source: "fonts/Sora-SemiBold.ttf" }
    FontLoader { source: "fonts/Manrope-Regular.ttf" }
    FontLoader { source: "fonts/Manrope-Medium.ttf" }
    FontLoader { source: "fonts/Manrope-Bold.ttf" }

    // ---------------------------------------------------------------- dados
    property var entries: []
    property var recents: []
    property string recentsLabel: "Jogados recentemente"
    property int homeIndex: 0

    property int tab: 0                       // 0 Início · 1 Biblioteca · 2 Troféus
    readonly property var tabNames: ["Início", "Biblioteca", "Troféus"]

    // Biblioteca em prateleiras: uma por console; cada prateleira lembra a coluna escolhida
    property var shelves: []
    property int libShelf: 0
    property int libCol: 0
    property var shelfCols: ({})
    property bool libOnSort: false
    property int sortMode: 0                  // 0 A–Z · 1 Recentes · 2 Mais jogados
    readonly property int libCount: entries.length

    property bool settingsOpen: false
    property bool gearFocused: false
    // sons: 0 desligados · 1 baixo · 2 médio · 3 alto
    property int soundLevel: 2
    readonly property bool soundOn: soundLevel > 0
    readonly property real soundGain: [0, 0.35, 0.65, 1.0][soundLevel]
    readonly property var soundLevelNames: ["Desligados", "Baixo", "Médio", "Alto"]
    // trava para crianças: configurações só abrem segurando o botão
    property bool kidLock: true

    property var trophyList: []
    property int trophyIndex: 0
    property int trophyFocus: 0               // 0 lista de jogos · 1 conquistas do jogo
    property int achIndex: 0
    property var raIndex: null
    property string raState: "off"            // off · loading · ok · error
    property var raCatalogs: ({})            // { consoleId: { título normalizado: [troféus, id do jogo] } }
    property int raGot: 0
    property int raTotal: 0
    property var achCache: ({})              // { id do jogo: { state, list, got, total, points, pointsGot } }

    // página do jogo
    property bool detailsOpen: false
    property int detailsBtn: 0

    // abrir jogo: "" · media (animação da vitrine) · flash · open (tela "Abrindo…")
    property string launchPhase: ""
    property var launchEntry: null

    // Fundo: tenta a imagem de fundo do jogo; se não existir, usa a capa.
    property bool bgUseArt: false
    onCurrentChanged: bgUseArt = false

    readonly property var curShelf: shelves.length ? shelves[L.clampIndex(libShelf, shelves.length)] : null
    readonly property var current: {
        if (tab === 0) return recents.length ? recents[L.clampIndex(homeIndex, recents.length)] : null;
        if (tab === 1) return curShelf && curShelf.items.length ? curShelf.items[L.clampIndex(libCol, curShelf.items.length)] : null;
        return trophyList.length ? trophyList[L.clampIndex(trophyIndex, trophyList.length)].entry : null;
    }
    readonly property var curTrophy: trophyList.length ? trophyList[L.clampIndex(trophyIndex, trophyList.length)] : null
    readonly property var curAch: curTrophy ? achFor(curTrophy.gameId) : null

    // ------------------------------------------------- consoles e emuladores
    // Escolhas guardadas no api.memory; o arquivo do Pegasus é gerado a partir delas.
    property var p7Installed: ({})
    property var p7Folders: ({})       // pasta usada de cada console
    property var p7Overrides: ({})     // pasta escolhida à mão ("-" = console desligado)
    property var p7Emus: ({})          // emulador escolhido por console
    property string p7Root: ""         // pasta principal escolhida (vazio = automático)
    property var p7Roots: []           // pastas onde a procura automática olhou
    property string p7Storage: ""

    function readJson(key) {
        if (!api.memory.has(key)) return {};
        try { var v = JSON.parse(String(api.memory.get(key))); return v && typeof v === "object" ? v : {}; }
        catch (e) { return {}; }
    }
    function p7Load() {
        p7Overrides = readJson("p7Overrides");
        p7Emus = readJson("p7Emus");
        p7Root = api.memory.has("p7Root") ? String(api.memory.get("p7Root")) : "";
    }
    function p7Save() {
        api.memory.set("p7Overrides", JSON.stringify(p7Overrides));
        api.memory.set("p7Emus", JSON.stringify(p7Emus));
        api.memory.set("p7Root", p7Root);
    }
    function p7Detect() {
        if (typeof P7 === "undefined") return;
        p7Storage = P7.storageRoot();
        p7Installed = EM.toSet(P7.installedPackages());
        // emuladores de Switch derivados do yuzu achados no tablet (Nyushu, Citron, Eden...)
        if (P7.switchEmulators) {
            var forks = EM.registerSwitchEmus(P7.switchEmulators());
            if (forks.length) console.warn("P7: emuladores de Switch achados: " + forks.map(function (f) { return f.label + " (" + f.pkgs[0] + ")"; }).join(", "));
        }
        var ls = function (p) { return P7.subdirs(p); };
        var roots = p7Root ? [p7Root] : EM.candidateRoots(p7Storage, ls);
        p7Roots = roots;
        var found = EM.detectFolders(roots, ls);
        var out = {};
        EM.SYSTEMS.forEach(function (s) {
            var o = p7Overrides[s.key];
            if (o === "-") return;
            var dir = o ? o : found[s.key];
            if (dir && P7.isDir(dir)) out[s.key] = dir;
        });
        p7Folders = out;
    }
    // Refaz o arquivo de consoles do Pegasus; só recarrega a biblioteca se algo mudou
    // (ou se pedirem). Nunca durante uma leitura em andamento: espera ela terminar.
    property bool syncPending: false
    property bool syncForce: false
    function syncLibrary(force) {
        if (typeof P7 === "undefined") return;
        if (Internal.scanner.running) {
            syncPending = true;
            syncForce = syncForce || force === true;
            return;
        }
        p7Detect();
        var text = EM.buildMetadata(p7Folders, p7Emus, p7Installed);
        var path = P7.libraryDir() + "/metadata.pegasus.txt";
        var changed = P7.readText(path) !== text;
        if (changed && !P7.writeText(path, text)) console.warn("P7: não consegui gravar " + path);
        if (changed || force === true) {
            console.warn("P7: recarregando a biblioteca (" + Object.keys(p7Folders).join(", ") + ")");
            Internal.settings.reloadProviders();
        }
    }
    Connections {
        target: Internal.scanner
        function onRunningChanged() {
            if (!Internal.scanner.running) refreshLater.restart();
            if (!Internal.scanner.running && root.introWanted) Qt.callLater(root.startIntro);
            if (!Internal.scanner.running && root.syncPending) {
                var f = root.syncForce;
                root.syncPending = false;
                root.syncForce = false;
                root.syncLibrary(f);
            }
        }
    }
    // a lista de jogos muda depois de uma leitura nova da biblioteca
    Timer { id: refreshLater; interval: 150; onTriggered: { root.quiet = true; root.refresh(); unquiet.restart(); } }
    Connections {
        target: api.allGames
        function onCountChanged() { refreshLater.restart(); }
    }

    // Medição: quantos quadros o app desenhou nos últimos 10 s (vai para o registro do Android)
    property int framesDrawn: 0
    Connections {
        target: root.Window.window
        function onFrameSwapped() { root.framesDrawn++; }
    }
    Timer {
        interval: 10000; repeat: true
        running: Qt.application.state === Qt.ApplicationActive
        onTriggered: { console.warn("P7: quadros em 10 s: " + root.framesDrawn); root.framesDrawn = 0; }
    }

    function playMove()    { sfx(sMove); }
    function playConfirm() { sfx(sConfirm); }
    function playBack()    { sfx(sBack); }

    // --------------------------------------------------------------- sons
    // Sons próprios do P7 Station (sintetizados, sem amostras de terceiros).
    property bool quiet: true           // sem som durante o carregamento e as atualizações
    SoundEffect { id: sMove;    source: "sounds/move.wav";    volume: 0.55 * root.soundGain }
    SoundEffect { id: sTab;     source: "sounds/tab.wav";     volume: 0.6 * root.soundGain }
    SoundEffect { id: sConfirm; source: "sounds/confirm.wav"; volume: 0.6 * root.soundGain }
    SoundEffect { id: sBack;    source: "sounds/back.wav";    volume: 0.6 * root.soundGain }
    SoundEffect { id: sLaunch;  source: "sounds/launch.wav";  volume: 0.75 * root.soundGain }
    SoundEffect { id: sInsert;  source: "sounds/insert.wav";  volume: 0.8 * root.soundGain }
    SoundEffect { id: sNotice;  source: "sounds/notice.wav";  volume: 0.6 * root.soundGain }
    SoundEffect { id: sPadOn;   source: "sounds/pad-on.wav";  volume: 0.6 * root.soundGain }
    SoundEffect { id: sPadOff;  source: "sounds/pad-off.wav"; volume: 0.6 * root.soundGain }
    SoundEffect { id: sBoot;    source: "sounds/boot.wav";    volume: 0.8 * root.soundGain }

    // ------------------------------------------------------------ abertura
    // Só na primeira vez desde que o app abriu (não depois de cada jogo); qualquer botão pula.
    property bool introOn: false
    property bool introWanted: false
    // a abertura começa quando a tela de carregamento sai (fim da leitura da biblioteca)
    Timer { id: introFallback; interval: 1500; onTriggered: root.startIntro() }
    function startIntro() {
        if (!introWanted || Internal.scanner.running) return;
        introFallback.stop();
        introWanted = false;
        introOn = true;
        console.warn("P7: abertura começou");
        if (P7.introDone) P7.introDone();
        introAnim.restart();
        if (soundOn) sBoot.play();
    }
    function skipIntro() {
        if (!introOn) return;
        introAnim.stop();
        introOutAnim.restart();
    }
    // segurando a seta, o clique de navegação toca no máximo a cada 70 ms (não vira zumbido)
    property double lastMoveSound: 0
    function sfx(s) {
        if (quiet || !soundOn) return;
        if (s === sMove) {
            var now = Date.now();
            if (now - lastMoveSound < 70) return;
            lastMoveSound = now;
        }
        s.play();
    }
    onHomeIndexChanged: sfx(sMove)
    onLibColChanged: sfx(sMove)
    onLibShelfChanged: sfx(sMove)
    onTrophyIndexChanged: { sfx(sMove); achIndex = 0; trophyFocus = 0; achLoadLater.restart(); }
    onAchIndexChanged: sfx(sMove)
    onTrophyFocusChanged: sfx(sMove)
    onLibOnSortChanged: sfx(sMove)
    onDetailsBtnChanged: sfx(sMove)
    onAccountOpenChanged: { sfx(accountOpen ? sConfirm : sBack); bumpLayout(); }
    onSettingsOpenChanged: { sfx(settingsOpen ? sConfirm : sBack); bumpLayout(); }
    onDetailsOpenChanged: { sfx(detailsOpen ? sConfirm : sBack); bumpLayout(); }
    onSortModeChanged: sfx(sTab)
    onGearFocusedChanged: sfx(sMove)
    Timer { id: unquiet; interval: 700; onTriggered: root.quiet = false }

    // ------------------------------------------------------------- escala
    // Desenhado em 1440 de largura; a altura acompanha a proporção da tela (Pad 7 = 3:2).
    readonly property real ui: width / 1440
    readonly property real pixelRatio: Math.max(1, ui * 1.2)

    // --------------------------------------------------------------- lógica
    function makeEntry(g) {
        var col = g.collections.count > 0 ? g.collections.get(0) : null;
        var sys = col ? String(col.shortName || col.name || "").toLowerCase() : "";
        var info = L.systemInfo(sys);
        var file = g.files.count > 0 ? g.files.get(0) : null;
        var base = L.baseName(file ? file.path : "");
        var assets = g.assets;
        var art = assets.boxFront || assets.poster || assets.tile || L.thumbUrl(sys, base, "box");
        // Switch não tem capas no Libretro: usa a imagem da eShop (pelo ID no nome do arquivo ou pelo título)
        if (!art && sys === "switch" && typeof P7 !== "undefined" && P7.switchCover)
            art = P7.switchCover(g.title, file ? file.path : "");
        var bg = assets.background || assets.screenshot || L.thumbUrl(sys, base, "snap") || art;
        // emulador que vai abrir este jogo, e se ele está instalado (sem lista de apps = não dá para saber)
        var sysDef = EM.byKey(sys);
        var known = Object.keys(p7Installed).length > 0;
        var emu = sysDef ? EM.effectiveEmu(sysDef, p7Emus[sys], p7Installed) : null;
        return {
            emuOk: !emu || !known || EM.isInstalled(emu, p7Installed),
            emuName: emu ? emu.label : "",
            emuFull: emu ? EM.emuLabel(emu) : "",
            emuHint: emu && known ? EM.setupHint(sysDef, emu, p7Installed) : "",
            game: g,
            title: g.title,
            display: L.cleanTitle(g.title),
            mono: L.monogram(g.title),
            sys: sys,
            sysName: info.name,
            short: info.short,
            color: info.color,
            art: art,
            bg: bg,
            lastPlayed: g.lastPlayed,
            playTime: g.playTime,
            fav: g.favorite,
            key: sys + "|" + g.title
        };
    }

    function indexOfKey(list, key) {
        for (var i = 0; i < list.length; i++) {
            var e = list[i].entry ? list[i].entry : list[i];
            if (e.key === key) return i;
        }
        return -1;
    }

    // posição de um jogo nas prateleiras: primeiro na prateleira preferida, depois em qualquer uma
    function locateInShelves(key, shelfKey) {
        var i, j;
        for (i = 0; i < shelves.length; i++) {
            if (shelfKey && shelves[i].key !== shelfKey) continue;
            for (j = 0; j < shelves[i].items.length; j++)
                if (shelves[i].items[j].key === key) return [i, j];
        }
        if (shelfKey) return locateInShelves(key, "");
        return null;
    }

    function refresh() {
        var wasQuiet = quiet;
        quiet = true;
        var keepHome = recents.length ? recents[L.clampIndex(homeIndex, recents.length)].key : api.memory.get("homeKey");
        var keepLib = tabLibKey();
        var keepShelf = curShelf ? curShelf.key : (api.memory.has("shelfKey") ? String(api.memory.get("shelfKey")) : "");

        var out = [];
        for (var i = 0; i < api.allGames.count; i++) {
            var e = makeEntry(api.allGames.get(i));
            if (e.sys !== "android") out.push(e);
        }
        entries = out;

        var r = L.buildRecents(out, 16);
        recentsLabel = r.label;
        recents = r.list;
        var hi = keepHome ? indexOfKey(recents, keepHome) : -1;
        homeIndex = hi >= 0 ? hi : 0;
        if (r.label === "Jogados recentemente") homeIndex = 0;   // o último jogado sempre volta para a frente

        shelves = L.buildShelves(out, sortMode);
        placeLibrary(keepLib, keepShelf);

        rebuildTrophies();
        quiet = wasQuiet;
    }
    function tabLibKey() {
        if (curShelf && curShelf.items.length) return curShelf.items[L.clampIndex(libCol, curShelf.items.length)].key;
        return api.memory.has("libKey") ? String(api.memory.get("libKey")) : "";
    }
    function placeLibrary(key, shelfKey) {
        var pos = key ? locateInShelves(key, shelfKey) : null;
        if (!pos) {
            // o jogo saiu da prateleira: fica na mesma prateleira, se ela ainda existir
            var si = 0;
            for (var i = 0; i < shelves.length; i++) if (shelves[i].key === shelfKey) si = i;
            pos = [si, shelves.length ? L.clampIndex(libCol, shelves[si].items.length) : 0];
        }
        libShelf = pos[0];
        libCol = pos[1];
        var c = Object.assign({}, shelfCols);
        if (shelves.length) c[shelves[libShelf].key] = libCol;
        shelfCols = c;
    }
    function colFor(i) {
        var s = shelves[i];
        if (!s) return 0;
        var c = shelfCols[s.key];
        return L.clampIndex(c === undefined ? 0 : c, s.items.length);
    }
    function moveShelf(d) {
        var next = L.clampIndex(libShelf + d, shelves.length);
        if (next === libShelf) return;
        var c = Object.assign({}, shelfCols);
        c[shelves[libShelf].key] = libCol;
        shelfCols = c;
        libCol = colFor(next);
        libShelf = next;
    }

    function setSort(m) {
        var key = tabLibKey();
        var shelfKey = curShelf ? curShelf.key : "";
        sortMode = (m + 3) % 3;
        api.memory.set("sortMode", sortMode);
        shelves = L.buildShelves(entries, sortMode);
        shelfCols = ({});
        placeLibrary(key, shelfKey);
    }

    // Triângulo: favoritar/desfavoritar o jogo selecionado (o Pegasus guarda os favoritos)
    function toggleFavorite() {
        if (!current) return;
        var g = current.game;
        g.favorite = !g.favorite;
        sfx(g.favorite ? sConfirm : sBack);
        toast(g.favorite ? "Adicionado aos favoritos" : "Removido dos favoritos");
        refresh();
    }

    function setSoundLevel(l) {
        soundLevel = (l + 4) % 4;
        api.memory.set("soundLevel", soundLevel);
        if (soundOn) sConfirm.play();
    }
    function setKidLock(on) {
        kidLock = on;
        api.memory.set("kidLock", on);
        sfx(on ? sConfirm : sBack);
    }

    // ------------------------------------------------- avisos rápidos (topo)
    property string toastText: ""
    property string toastShown: ""      // continua escrito enquanto o aviso sai de cena
    function toast(t) { toastText = t; toastShown = t; toastTimer.restart(); }
    Timer { id: toastTimer; interval: 3000; onTriggered: root.toastText = "" }

    // ----------------------------------------------- aviso com botão (meio)
    property bool noticeOpen: false
    property string noticeTitle: ""
    property string noticeText: ""
    function showNotice(title, text) {
        noticeTitle = title;
        noticeText = text;
        noticeOpen = true;
        sfx(sNotice);
    }

    // ------------------------------------------------- abrir configurações
    // Com a trava ligada, só abre segurando Options (ou X na engrenagem) por 1,2 s.
    property int holdKey: 0
    property real holdProgress: 0
    function openSettings() {
        holdKey = 0;
        gearFocused = false;
        settingsIndex = 0;
        settingsOpen = true;
    }
    function requestSettings(key) {
        if (!kidLock) { openSettings(); return; }
        holdKey = key;
        holdAnim.restart();
    }
    NumberAnimation {
        id: holdAnim
        target: root; property: "holdProgress"; from: 0; to: 1; duration: 1200
        onFinished: if (root.holdProgress >= 0.999) { root.holdProgress = 0; root.openSettings(); }
    }
    function cancelHold() {
        if (!holdAnim.running) return;
        holdProgress = 0;
        holdKey = 0;
        holdAnim.stop();
        toast("Segure o botão para abrir as configurações");
    }

    // ------------------------------------------------------------ controles
    // Lista e bateria vêm do Android (InputDevice.getBatteryState). Sem dado real, só o ícone.
    property var pads: []
    property var padNames: ({})
    property var padLowWarned: ({})
    property bool padsReady: false
    function refreshPads() {
        if (typeof P7 === "undefined" || !P7.controllers) return;
        var list = P7.controllers();
        var names = {};
        list.forEach(function (p) { names[p.name] = true; });
        if (padsReady) {
            Object.keys(names).forEach(function (n) {
                if (!padNames[n]) { toast("Controle conectado: " + L.padLabel(n)); sfx(sPadOn); }
            });
            Object.keys(padNames).forEach(function (n) {
                if (!names[n]) { toast("Controle desconectado"); sfx(sPadOff); }
            });
        }
        list.forEach(function (p) {
            if (p.hasBattery && p.level >= 0 && p.level <= 15 && !p.charging && !padLowWarned[p.name]) {
                padLowWarned[p.name] = true;
                toast("Bateria do controle fraca: " + p.level + "%");
                sfx(sNotice);
            }
        });
        padNames = names;
        padsReady = true;
        if (JSON.stringify(list) !== JSON.stringify(pads)) pads = list;
    }
    Timer {
        interval: 15000; repeat: true; triggeredOnStart: true
        running: Qt.application.state === Qt.ApplicationActive
        onTriggered: root.refreshPads()
    }
    Timer { id: padCheck; interval: 700; onTriggered: root.refreshPads() }
    Connections {
        target: Internal.gamepad
        function onConnected(deviceId) { padCheck.restart(); }
        function onDisconnected(deviceId) { padCheck.restart(); }
    }

    // o palco avisa os painéis de vidro quando a disposição muda (eles se reposicionam e param)
    function bumpLayout() { stage.layoutTick++; }
    onTabChanged: bumpLayout()
    onNoticeOpenChanged: bumpLayout()
    onLaunchPhaseChanged: bumpLayout()

    // ------------------------------------------------------ RetroAchievements
    // Catálogo de troféus de cada console da biblioteca (guardado por 7 dias: a lista é grande)
    function loadCatalogs() {
        var ids = L.raConsolesIn(entries);
        var cats = {};
        var pending = [];
        var now = Date.now();
        ids.forEach(function (id) {
            var mem = "raCat2_" + id;
            var cached = null;
            if (api.memory.has(mem)) {
                try { cached = JSON.parse(String(api.memory.get(mem))); } catch (e) { cached = null; }
            }
            if (cached && cached.t && now - cached.t < 7 * 24 * 3600 * 1000 && cached.m) cats[id] = cached.m;
            else pending.push(id);
        });
        raCatalogs = cats;
        rebuildTrophies();
        function next() {
            if (!pending.length) return;
            var id = pending.shift();
            var xhr = new XMLHttpRequest();
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                if (xhr.status === 200) {
                    try {
                        var m = L.indexCatalog(JSON.parse(xhr.responseText));
                        api.memory.set("raCat2_" + id, JSON.stringify({ t: Date.now(), m: m }));
                        if (api.memory.has("raCat" + id)) api.memory.unset("raCat" + id);   // formato antigo
                        var c = Object.assign({}, root.raCatalogs);
                        c[id] = m;
                        root.raCatalogs = c;
                        root.rebuildTrophies();
                    } catch (e) { console.warn("P7: catálogo " + id + ": " + e); }
                } else {
                    console.warn("P7: catálogo " + id + " respondeu " + xhr.status);
                }
                next();
            };
            xhr.open("GET", "https://retroachievements.org/API/API_GetGameList.php?f=1&i=" + id
                     + "&y=" + encodeURIComponent(raKey()));
            xhr.send();
        }
        next();
    }

    function rebuildTrophies() {
        var keep = curTrophy ? curTrophy.entry.key : "";
        var list = [];
        var got = 0, total = 0;
        if (raIndex) {
            for (var i = 0; i < entries.length; i++) {
                var t = L.trophiesFor(raIndex, entries[i], raCatalogs);
                if (t) {
                    list.push({ entry: entries[i], got: t.got, total: t.total, played: t.played, gameId: t.gameId });
                    got += t.got;
                    total += t.total;
                }
            }
            list.sort(function (a, b) {
                if (a.played !== b.played) return a.played ? -1 : 1;     // os já começados primeiro
                if ((a.got > 0) !== (b.got > 0)) return a.got > 0 ? -1 : 1;
                var da = L.playedTime(a.entry), db = L.playedTime(b.entry);
                if (da !== db) return db - da;
                return a.entry.display < b.entry.display ? -1 : 1;
            });
        }
        var wasQuiet = quiet;
        quiet = true;
        trophyList = list;
        raGot = got;
        raTotal = total;
        var ki = keep ? indexOfKey(list, keep) : -1;
        trophyIndex = ki >= 0 ? ki : L.clampIndex(trophyIndex, list.length);
        quiet = wasQuiet;
        achLoadLater.restart();
    }

    // conta do RetroAchievements: digitada no próprio app (aba Troféus) ou, se vazio, a do config.js
    function raUser() { return api.memory.has("raUser") ? String(api.memory.get("raUser")) : Cfg.RA_USER; }
    function raKey()  { return api.memory.has("raKey")  ? String(api.memory.get("raKey"))  : Cfg.RA_KEY; }
    function saveAccount(u, k) {
        api.memory.set("raUser", String(u).trim());
        api.memory.set("raKey", String(k).trim());
        accountOpen = false;
        achCache = ({});
        root.forceActiveFocus();
        loadAchievements();
    }
    property bool accountOpen: false

    function loadAchievements() {
        if (!raUser() || !raKey()) { raState = "off"; return; }
        raState = "loading";
        var xhr = new XMLHttpRequest();
        var url = "https://retroachievements.org/API/API_GetUserCompletionProgress.php"
                + "?u=" + encodeURIComponent(raUser())
                + "&y=" + encodeURIComponent(raKey())
                + "&c=500";
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    raIndex = L.indexAchievements(data.Results || data.results);
                    raState = "ok";
                    rebuildTrophies();
                    loadCatalogs();
                } catch (err) {
                    raState = "error";
                }
            } else {
                raState = "error";
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    // Conquistas de um jogo (com as datas do usuário); ficam guardadas enquanto o app está aberto
    function achFor(id) { return id && achCache[id] ? achCache[id] : null; }
    function setAch(id, v) { var c = Object.assign({}, achCache); c[id] = v; achCache = c; }
    function loadGameAch(id) {
        if (!id || raState !== "ok" || !raUser() || !raKey()) return;
        var c = achCache[id];
        if (c && (c.state === "loading" || c.state === "ok")) return;
        setAch(id, { state: "loading", list: [], got: 0, total: 0, points: 0, pointsGot: 0 });
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try {
                    var r = L.parseGameAchievements(JSON.parse(xhr.responseText));
                    r.state = "ok";
                    root.setAch(id, r);
                    return;
                } catch (e) { console.warn("P7: conquistas " + id + ": " + e); }
            }
            root.setAch(id, { state: "error", list: [], got: 0, total: 0, points: 0, pointsGot: 0 });
        };
        xhr.open("GET", "https://retroachievements.org/API/API_GetGameInfoAndUserProgress.php?g=" + id
                 + "&u=" + encodeURIComponent(raUser()) + "&y=" + encodeURIComponent(raKey()));
        xhr.send();
    }
    // espera a seta parar antes de buscar (andando rápido pela lista não dispara dezenas de pedidos)
    Timer { id: achLoadLater; interval: 260; onTriggered: if (root.curTrophy) root.loadGameAch(root.curTrophy.gameId) }

    function trophyInfo(entry) {
        if (!entry) return { kind: "none", text: "" };
        if (!L.hasTrophySupport(entry.sys)) return { kind: "none", text: "Sem troféus neste console" };
        if (raState === "off") return { kind: "none", text: "Conecte o RetroAchievements" };
        if (raState === "loading") return { kind: "none", text: "Carregando…" };
        if (raState === "error") return { kind: "none", text: "Sem conexão com o RetroAchievements" };
        var t = L.trophiesFor(raIndex, entry, raCatalogs);
        if (!t) return { kind: "none", text: "Sem troféus para este jogo" };
        return { kind: "progress", got: t.got, total: t.total, gameId: t.gameId };
    }

    // ---------------------------------------------------------- página do jogo
    readonly property int detailsGameId: detailsOpen && current ? (trophyInfo(current).gameId || 0) : 0
    readonly property var detailButtons: {
        if (!current) return [];
        var b = [ { id: "play", label: !current.emuOk ? "Como jogar" : (L.playedTime(current) > 0 ? "Continuar" : "Jogar") },
                  { id: "fav", label: current.fav ? "Favorito" : "Favoritar", on: current.fav === true } ];
        if (trophyInfo(current).kind === "progress") b.push({ id: "trophies", label: "Troféus" });
        return b;
    }
    function openDetails() {
        if (!current) return;
        detailsBtn = 0;
        detailsOpen = true;
        var id = trophyInfo(current).gameId;
        if (id) loadGameAch(id);
    }
    function detailsActivate() {
        var b = detailButtons[L.clampIndex(detailsBtn, detailButtons.length)];
        if (!b) return;
        if (b.id === "play") {
            detailsOpen = false;
            launchCurrent();
        } else if (b.id === "fav") {
            toggleFavorite();
        } else if (b.id === "trophies") {
            var key = current.key;
            detailsOpen = false;
            switchTab(2);
            var i = indexOfKey(trophyList, key);
            if (i >= 0) trophyIndex = i;
            trophyFocus = 0;
        }
    }

    // ---------------------------------------------------------- abrir o jogo
    // Início: a mídia sai da caixa e entra na base, a tela clareia e aparece "Abrindo…".
    // Outras telas: só o clarão e o "Abrindo…". X durante a animação pula para o jogo; Círculo cancela.
    function launchCurrent() {
        if (!current || launchPhase !== "") return;
        if (!current.emuOk) {
            showNotice("Falta o emulador", current.emuHint || ("Instale o " + current.emuName + " para jogar " + current.sysName + "."));
            return;
        }
        api.memory.set("tab", tab);
        api.memory.set("homeKey", current.key);
        if (tab === 1 && curShelf) {
            api.memory.set("libKey", current.key);
            api.memory.set("shelfKey", curShelf.key);
        }
        launchEntry = current;
        sfx(sLaunch);
        if (tab === 0 && showcase.visible && showcase.entry === current) {
            launchPhase = "media";
            showcase.launch();
        } else {
            startFlash();
        }
    }
    function startFlash() {
        if (launchPhase === "flash" || launchPhase === "open") return;
        launchPhase = "flash";
        flashAnim.restart();
    }
    function doLaunch() {
        if (!launchEntry) return;
        launchGuardUntil = Date.now() + 2000;   // um X segurado não abre o jogo duas vezes
        launchSafety.restart();
        console.warn("P7: abrindo " + launchEntry.title);
        launchEntry.game.launch();
    }
    function resetLaunch() {
        flashAnim.stop();
        flashLayer.opacity = 0;
        launchSafety.stop();
        showcase.resetLaunch();
        launchPhase = "";
    }
    // se o emulador não abriu (o app continua na frente), volta ao menu
    Timer {
        id: launchSafety
        interval: 9000
        onTriggered: if (Qt.application.state === Qt.ApplicationActive) root.resetLaunch()
    }

    function switchTab(t) {
        var next = (t + 3) % 3;
        if (next !== tab) sfx(next === 0 && t !== 3 ? sBack : sTab);
        tab = next;
        libOnSort = false;
        gearFocused = false;
        trophyFocus = 0;
    }

    Component.onCompleted: {
        if (api.memory.has("tab")) tab = api.memory.get("tab");
        if (api.memory.has("sortMode")) sortMode = api.memory.get("sortMode");
        if (api.memory.has("soundLevel")) soundLevel = Number(api.memory.get("soundLevel"));
        else if (api.memory.has("soundOn") && !api.memory.get("soundOn")) soundLevel = 0;
        if (api.memory.has("kidLock")) kidLock = api.memory.get("kidLock") === true;
        p7Load();
        if (typeof P7 !== "undefined" && P7.introPending && P7.introPending()) {
            introWanted = true;
            introOn = true;          // cobre o menu até a abertura começar
            introFallback.start();   // a leitura da biblioteca termina e chama a abertura; se não houver leitura, ela começa sozinha
        }
        syncLibrary();
        refresh();
        loadAchievements();
        unquiet.start();
    }

    // Ao voltar de um jogo, atualiza recentes e tempo jogado; troféus a cada volta também.
    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive) {
                // volta do jogo (ou de outro app): o controle precisa encontrar o foco aqui
                releaseAllKeys();
                if (root.launchPhase !== "") root.resetLaunch();
                if (!root.accountOpen) root.forceActiveFocus();
                if (!consoles.open) syncLibrary();
                refresh();
                achCache = ({});
                loadAchievements();
            }
        }
    }

    // ------------------------------------------------------------ controle
    // Botões de ação (X, Círculo, Triângulo, Quadrado, L1, R1) valem uma vez por aperto.
    // No Android, um botão do controle segurado chega repetido como se fosse apertado de novo,
    // sem a marca de repetição; por isso o tema guarda quais botões estão abaixados.
    // As setas continuam repetindo ao segurar, para andar rápido pela lista.
    property var heldKeys: ({})
    property double launchGuardUntil: 0
    function isActionKey(event) {
        return api.keys.isAccept(event) || api.keys.isCancel(event) || api.keys.isFilters(event)
            || api.keys.isDetails(event) || api.keys.isPrevPage(event) || api.keys.isNextPage(event);
    }
    function releaseAllKeys() { heldKeys = ({}); }
    property double lastExitHint: 0
    Keys.onReleased: {
        if (event.isAutoRepeat) return;
        if (holdKey !== 0 && event.key === holdKey) cancelHold();
        if (heldKeys[event.key]) delete heldKeys[event.key];
    }
    onActiveFocusChanged: releaseAllKeys()

    Keys.onPressed: {
        if (introOn) { event.accepted = true; skipIntro(); return; }
        // botão da trava sendo segurado: as repetições do Android não recomeçam a contagem
        if (holdKey !== 0 && event.key === holdKey) { event.accepted = true; return; }
        if (isActionKey(event)) {
            var now = Date.now();
            var since = heldKeys[event.key];
            // repetição: ignora; mas se o "solta" se perdeu (ex.: troca de app), libera depois de 2,5 s
            if (event.isAutoRepeat || (since && now - since < 2500) || now < launchGuardUntil) {
                event.accepted = true;
                return;
            }
            heldKeys[event.key] = now;
        }
        // abrindo o jogo: X pula a animação, Círculo cancela, o resto espera
        if (launchPhase !== "") {
            event.accepted = true;
            if (launchPhase === "media") {
                if (api.keys.isAccept(event)) startFlash();
                else if (api.keys.isCancel(event)) { resetLaunch(); sfx(sBack); }
            }
            return;
        }
        if (noticeOpen) {
            if (api.keys.isAccept(event) || api.keys.isCancel(event)) { noticeOpen = false; sfx(sBack); }
            event.accepted = true;
            return;
        }
        // Options/Start: configurações do P7 (nunca o menu técnico do Pegasus)
        if (api.keys.isMenu(event)) {
            event.accepted = true;
            if (settingsOpen) settingsOpen = false;
            else if (!consoles.open && !accountOpen) requestSettings(event.key);
            return;
        }
        if (consoles.open) { consoles.handleKey(event); return; }
        if (settingsOpen) { handleSettingsKey(event); return; }
        if (accountOpen) {
            if (api.keys.isCancel(event)) { event.accepted = true; accountOpen = false; root.forceActiveFocus(); }
            return;
        }
        if (detailsOpen) { handleDetailsKey(event); return; }
        if (api.keys.isPrevPage(event)) { event.accepted = true; switchTab(tab - 1); return; }
        if (api.keys.isNextPage(event)) { event.accepted = true; switchTab(tab + 1); return; }

        if (api.keys.isFilters(event)) { event.accepted = true; if (!gearFocused && !libOnSort) toggleFavorite(); return; }
        if (api.keys.isDetails(event)) { event.accepted = true; if (!gearFocused && !libOnSort) openDetails(); return; }

        if (tab === 0) {
            if (gearFocused) {
                if (event.key === Qt.Key_Down || api.keys.isCancel(event)) { event.accepted = true; gearFocused = false; }
                else if (api.keys.isAccept(event)) { event.accepted = true; requestSettings(event.key); }
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Up) { event.accepted = true; }
                return;
            }
            if (event.key === Qt.Key_Left)  { event.accepted = true; homeIndex = L.clampIndex(homeIndex - 1, recents.length); }
            else if (event.key === Qt.Key_Right) { event.accepted = true; homeIndex = L.clampIndex(homeIndex + 1, recents.length); }
            else if (event.key === Qt.Key_Up) { event.accepted = true; gearFocused = true; }
            else if (event.key === Qt.Key_Down) { event.accepted = true; }
            else if (api.keys.isAccept(event)) { event.accepted = true; if (current) launchCurrent(); else consoles.show(); }
            // Círculo no Início não fecha o app; só lembra como sair
            else if (api.keys.isCancel(event)) {
                event.accepted = true;
                var t = Date.now();
                if (t - lastExitHint > 8000) { lastExitHint = t; toast("Para sair do P7 Station, use o botão de início do tablet"); }
            }
            return;
        }

        if (tab === 1) {
            if (libOnSort) {
                if (event.key === Qt.Key_Left)  { event.accepted = true; setSort(sortMode - 1); }
                else if (event.key === Qt.Key_Right) { event.accepted = true; setSort(sortMode + 1); }
                else if (event.key === Qt.Key_Down || api.keys.isAccept(event) || api.keys.isCancel(event)) { event.accepted = true; libOnSort = false; }
                else if (event.key === Qt.Key_Up) { event.accepted = true; }
                return;
            }
            if (api.keys.isCancel(event)) { event.accepted = true; switchTab(0); return; }
            var n = curShelf ? curShelf.items.length : 0;
            if (event.key === Qt.Key_Left)  { event.accepted = true; libCol = L.clampIndex(libCol - 1, n); }
            else if (event.key === Qt.Key_Right) { event.accepted = true; libCol = L.clampIndex(libCol + 1, n); }
            else if (event.key === Qt.Key_Down)  { event.accepted = true; moveShelf(1); }
            else if (event.key === Qt.Key_Up) {
                event.accepted = true;
                if (libShelf === 0) libOnSort = true;
                else moveShelf(-1);
            }
            else if (api.keys.isAccept(event)) { event.accepted = true; launchCurrent(); }
            return;
        }

        if (tab === 2) {
            if (trophyFocus === 1) {
                var list = curAch && curAch.state === "ok" ? curAch.list : [];
                var cols = achGrid.columns;
                if (api.keys.isCancel(event)) { event.accepted = true; trophyFocus = 0; return; }
                if (event.key === Qt.Key_Left) {
                    event.accepted = true;
                    if (achIndex % cols === 0) trophyFocus = 0;
                    else achIndex = achIndex - 1;
                }
                else if (event.key === Qt.Key_Right) { event.accepted = true; if (achIndex % cols < cols - 1) achIndex = L.clampIndex(achIndex + 1, list.length); }
                else if (event.key === Qt.Key_Down)  { event.accepted = true; if (achIndex + cols < list.length) achIndex += cols; }
                else if (event.key === Qt.Key_Up)    { event.accepted = true; if (achIndex - cols >= 0) achIndex -= cols; }
                else if (api.keys.isAccept(event)) { event.accepted = true; }
                return;
            }
            if (api.keys.isCancel(event)) { event.accepted = true; switchTab(0); return; }
            if (event.key === Qt.Key_Up)   { event.accepted = true; trophyIndex = L.clampIndex(trophyIndex - 1, trophyList.length); }
            else if (event.key === Qt.Key_Down) { event.accepted = true; trophyIndex = L.clampIndex(trophyIndex + 1, trophyList.length); }
            else if (event.key === Qt.Key_Right) {
                event.accepted = true;
                if (curAch && curAch.state === "ok" && curAch.list.length > 0) { achIndex = 0; trophyFocus = 1; }
            }
            else if (event.key === Qt.Key_Left) { event.accepted = true; }
            else if (api.keys.isAccept(event)) { event.accepted = true; launchCurrent(); }
        }
    }

    function handleDetailsKey(event) {
        event.accepted = true;
        var n = detailButtons.length;
        if (api.keys.isCancel(event) || api.keys.isDetails(event)) { detailsOpen = false; return; }
        if (api.keys.isFilters(event)) { toggleFavorite(); return; }
        if (event.key === Qt.Key_Left)  { detailsBtn = L.clampIndex(detailsBtn - 1, n); return; }
        if (event.key === Qt.Key_Right) { detailsBtn = L.clampIndex(detailsBtn + 1, n); return; }
        if (api.keys.isAccept(event)) { detailsActivate(); return; }
    }

    property int settingsIndex: 0
    readonly property int settingsCount: 6
    function settingsActivate(i) {
        if (i === 0) { settingsOpen = false; consoles.show(); }
        else if (i === 1) { settingsOpen = false; accountOpen = true; }
        else if (i === 2) setSoundLevel(soundLevel + 1);
        else if (i === 3) setKidLock(!kidLock);
        else if (i === 4) { settingsOpen = false; syncLibrary(true); }
        else if (i === 5) settingsOpen = false;
    }
    function handleSettingsKey(event) {
        if (api.keys.isCancel(event)) { event.accepted = true; settingsOpen = false; return; }
        if (event.key === Qt.Key_Up)   { event.accepted = true; settingsIndex = L.clampIndex(settingsIndex - 1, settingsCount); sfx(sMove); return; }
        if (event.key === Qt.Key_Down) { event.accepted = true; settingsIndex = L.clampIndex(settingsIndex + 1, settingsCount); sfx(sMove); return; }
        if (settingsIndex === 2 && event.key === Qt.Key_Left)  { event.accepted = true; setSoundLevel(soundLevel - 1); return; }
        if (settingsIndex === 2 && event.key === Qt.Key_Right) { event.accepted = true; setSoundLevel(soundLevel + 1); return; }
        if (api.keys.isAccept(event))  { event.accepted = true; settingsActivate(settingsIndex); return; }
        event.accepted = true;
    }

    Timer {
        id: clockTimer
        interval: 20000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm")
    }

    // ============================================================== TELA
    Rectangle {
        anchors.fill: parent
        color: "#05040b"
    }

    Item {
        id: stage
        property int layoutTick: 0
        onWidthChanged: layoutTick++
        onHeightChanged: layoutTick++
        width: 1440
        height: root.height / root.ui
        scale: root.ui
        transformOrigin: Item.TopLeft

        // ---------------------------------------------------- fundo
        // A imagem do jogo, desfocada de leve, troca com uma transição cruzada (duas camadas).
        Item {
            id: backdrop
            anchors.fill: parent

            readonly property color tint: root.current ? root.current.color : "#2a2d33"
            readonly property string want: root.current ? (root.bgUseArt ? root.current.art : root.current.bg) : ""
            property int front: 0
            onWantChanged: load()
            Component.onCompleted: load()
            function load() {
                var img = front === 0 ? bgB : bgA;
                if ((front === 0 ? bgA : bgB).key === want && want !== "") return;
                img.key = want;
                img.source = want;
                if (want === "") { bgA.shown = false; bgB.shown = false; return; }
                // a mesma imagem já carregada (voltou para um jogo de antes): mostra na hora
                if (img.status === Image.Ready) ready(img);
            }
            function ready(img) {
                if (img.key !== want) return;
                front = img === bgA ? 0 : 1;
                bgA.shown = img === bgA;
                bgB.shown = img === bgB;
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.darker(backdrop.tint, 4.6)
                Behavior on color { ColorAnimation { duration: 700 } }
            }

            Item {
                id: bgPair
                anchors.fill: parent
                visible: false
                Image {
                    id: bgA
                    property bool shown: false
                    property string key: ""
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: 720
                    opacity: shown && status === Image.Ready ? 1 : 0
                    scale: shown ? 1.0 : 1.06
                    Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }
                    Behavior on scale { NumberAnimation { duration: 1400; easing.type: Easing.OutCubic } }
                    onStatusChanged: {
                        if (status === Image.Ready) backdrop.ready(bgA);
                        else if (status === Image.Error && key === backdrop.want && !root.bgUseArt) root.bgUseArt = true;
                    }
                }
                Image {
                    id: bgB
                    property bool shown: false
                    property string key: ""
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: 720
                    opacity: shown && status === Image.Ready ? 1 : 0
                    scale: shown ? 1.0 : 1.06
                    Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }
                    Behavior on scale { NumberAnimation { duration: 1400; easing.type: Easing.OutCubic } }
                    onStatusChanged: {
                        if (status === Image.Ready) backdrop.ready(bgB);
                        else if (status === Image.Error && key === backdrop.want && !root.bgUseArt) root.bgUseArt = true;
                    }
                }
            }
            FastBlur {
                anchors.fill: parent
                source: bgPair
                radius: 34
                opacity: 0.55
            }

            // Biblioteca e Troféus: fundo mais escuro (muitas capas e textos por cima)
            Rectangle {
                anchors.fill: parent
                color: "#05040b"
                opacity: root.tab === 0 ? 0 : 0.42
                Behavior on opacity { NumberAnimation { duration: 400 } }
            }

            // cor do console por cima, mais forte no alto à direita (atrás da vitrine)
            RadialGradient {
                anchors.fill: parent
                horizontalOffset: width * 0.22
                verticalOffset: -height * 0.2
                horizontalRadius: width * 0.75
                verticalRadius: height * 0.85
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(backdrop.tint.r, backdrop.tint.g, backdrop.tint.b, 0.42) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            // escurece embaixo e à esquerda, onde ficam os textos e as capas
            LinearGradient {
                anchors.fill: parent
                start: Qt.point(0, 0)
                end: Qt.point(width * 0.6, 0)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#8c05040b" }
                    GradientStop { position: 1.0; color: "#0005040b" }
                }
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#2605040b" }
                    GradientStop { position: 0.4; color: "#0005040b" }
                    GradientStop { position: 0.78; color: "#bf05040b" }
                    GradientStop { position: 1.0; color: "#f205040b" }
                }
            }
        }

        FastBlur {
            id: backdropBlur
            width: backdrop.width
            height: backdrop.height
            source: backdrop
            radius: 40
            visible: false
        }
        ShaderEffectSource {
            id: glassSource
            sourceItem: backdropBlur
            width: backdrop.width
            height: backdrop.height
            textureSize: Qt.size(Math.round(backdrop.width / 2), Math.round(backdrop.height / 2))
            smooth: true
            hideSource: false
            visible: false
        }

        // ---------------------------------------------------- topo
        Glass {
            backdrop: glassSource
            stageItem: stage
            id: tabBar
            x: 56
            y: 32
            height: 52
            width: tabRow.width + 8
            radius: height / 2

            LiquidPill {
                x: tabRow.x + (target ? target.x : 0)
                light: true
                target: tabRepeater.added >= 0 && tabRepeater.count > root.tab ? tabRepeater.itemAt(root.tab) : null
            }

            Row {
                id: tabRow
                anchors.centerIn: parent
                spacing: 2

                Repeater {
                    id: tabRepeater
                    property int added: 0   // força a bolha a achar o item quando ele acaba de ser criado
                    onItemAdded: added++
                    model: root.tabNames
                    delegate: Item {
                        width: tabLabel.implicitWidth + 44
                        height: 44

                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: index === root.tab ? "#0b0a14" : "#a6ffffff"
                            font.family: "Manrope"
                            font.pixelSize: 17
                            font.weight: index === root.tab ? Font.Bold : Font.Medium
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (root.launchPhase === "" && !root.detailsOpen) root.switchTab(index)
                        }
                    }
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 56
            anchors.verticalCenter: tabBar.verticalCenter
            spacing: 18

            // controles conectados: anel com a bateria (só o que o Android informa)
            Repeater {
                model: root.pads.slice(0, 2)
                delegate: Glass {
                    backdrop: glassSource
                    stageItem: stage
                    anchors.verticalCenter: parent.verticalCenter
                    width: padText.width + 74
                    height: 56
                    radius: 28
                    readonly property bool hasLevel: modelData.hasBattery && modelData.level >= 0
                    Ring {
                        x: 6; anchors.verticalCenter: parent.verticalCenter
                        width: 44; height: 44
                        lineWidth: 3
                        pixelRatio: root.pixelRatio
                        value: hasLevel ? modelData.level / 100 : 1
                        color: hasLevel ? L.batteryColor(modelData.level, modelData.charging) : "#59ffffff"
                        track: "#26ffffff"
                        Canvas {
                            anchors.centerIn: parent
                            width: 22 * 3; height: 16 * 3
                            scale: 1 / 3
                            renderTarget: Canvas.Image
                            onPaint: {
                                var c = getContext("2d");
                                c.reset();
                                c.scale(3, 3);
                                c.strokeStyle = "#ffffff";
                                c.lineWidth = 1.5;
                                c.lineJoin = "round";
                                c.beginPath();
                                c.moveTo(6, 2); c.lineTo(16, 2);
                                c.bezierCurveTo(20, 2, 21.5, 11, 19.5, 13.5);
                                c.bezierCurveTo(18, 15, 16, 12, 14.5, 10.5);
                                c.lineTo(7.5, 10.5);
                                c.bezierCurveTo(6, 12, 4, 15, 2.5, 13.5);
                                c.bezierCurveTo(0.5, 11, 2, 2, 6, 2);
                                c.closePath();
                                c.stroke();
                            }
                        }
                    }
                    Column {
                        id: padText
                        x: 60
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text { text: "Controle " + (index + 1); color: "#ffffff"; font.family: "Manrope"; font.weight: Font.Bold; font.pixelSize: 14 }
                        Text {
                            text: (hasLevel ? modelData.level + "%" + (modelData.charging ? " · carregando" : "") + " · " : "") + L.padLabel(modelData.name)
                            color: hasLevel && modelData.level <= 15 && !modelData.charging ? "#ff9c8f" : "#a6ffffff"
                            font.family: "Manrope"; font.weight: Font.Medium; font.pixelSize: 13
                        }
                    }
                }
            }
            Text {
                id: clock
                anchors.verticalCenter: parent.verticalCenter
                color: "#e6ffffff"
                font.family: "Sora"
                font.pixelSize: 22
            }
            Glass {
                backdrop: glassSource
                stageItem: stage
                width: 54
                height: 54
                radius: 27
                border.width: root.gearFocused ? 3 : (liquid ? 0 : 1)
                border.color: root.gearFocused ? "#ffffff" : "#1cffffff"
                anchors.verticalCenter: parent.verticalCenter
                scale: root.gearFocused ? 1.08 : 1
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                Canvas {
                    anchors.centerIn: parent
                    width: 66; height: 66
                    scale: 1 / 3
                    renderTarget: Canvas.Image
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.scale(3, 3);
                        ctx.strokeStyle = "rgba(255,255,255,0.92)";
                        ctx.lineWidth = 1.7;
                        ctx.lineJoin = "round";
                        ctx.beginPath();
                        for (var i = 0; i < 16; i++) {
                            var a = i * Math.PI / 8;
                            var r = (i % 2 === 0) ? 9.6 : 7.2;
                            var x = 11 + Math.cos(a) * r, y = 11 + Math.sin(a) * r;
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                        }
                        ctx.closePath();
                        ctx.stroke();
                        ctx.beginPath();
                        ctx.arc(11, 11, 3.2, 0, Math.PI * 2);
                        ctx.stroke();
                    }
                }
                // anel que enche enquanto o botão (ou o dedo) segura
                Ring {
                    anchors.fill: parent
                    visible: root.holdProgress > 0
                    animated: false
                    lineWidth: 3
                    color: "#ffffff"
                    track: "#00ffffff"
                    pixelRatio: root.pixelRatio
                    value: root.holdProgress
                }
                MouseArea {
                    anchors.fill: parent
                    onPressed: if (root.kidLock) { root.holdKey = -1; holdAnim.restart(); }
                    onReleased: if (root.kidLock && root.holdKey === -1) root.cancelHold()
                    onCanceled: if (root.kidLock && root.holdKey === -1) root.cancelHold()
                    onClicked: if (!root.kidLock) root.openSettings()
                }
            }
        }

        // ================================================= ABA: INÍCIO
        Item {
            id: homeView
            anchors.fill: parent
            visible: opacity > 0
            opacity: root.tab === 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 240 } }

            readonly property var tinfo: root.tab === 0 ? root.trophyInfo(root.current) : ({ kind: "none" })
            readonly property real rowTop: stage.height - 334

            // ---------------- o jogo em destaque (esquerda)
            Column {
                id: heroInfo
                x: 64
                y: 178 + Math.max(0, stage.height - 960) * 0.4
                width: 640
                spacing: 18
                visible: root.current !== null
                opacity: root.launchPhase === "" ? 1 : 0.0
                Behavior on opacity { NumberAnimation { duration: 300 } }

                // troca de jogo: o texto entra deslizando
                property real enter: 1
                Connections {
                    target: root
                    function onCurrentChanged() { if (root.tab === 0) heroEnter.restart(); }
                }
                NumberAnimation { id: heroEnter; target: heroInfo; property: "enter"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
                transform: Translate { x: (1 - heroInfo.enter) * -24 }

                Row {
                    spacing: 12
                    opacity: heroInfo.enter
                    Text {
                        text: root.current ? (root.current.sysName + (root.current.emuFull ? "  ·  " + root.current.emuFull : "")).toUpperCase() : ""
                        color: "#b3ffffff"
                        font.family: "Manrope"
                        font.weight: Font.Bold
                        font.pixelSize: 14
                        font.letterSpacing: 2.4
                    }
                }
                Text {
                    width: parent.width
                    opacity: heroInfo.enter
                    text: root.current ? root.current.display : ""
                    color: "#ffffff"
                    font.family: "Sora"
                    font.weight: Font.Light
                    // nomes longos ficam menores, sempre em até duas linhas
                    font.pixelSize: text.length > 34 ? 54 : (text.length > 22 ? 64 : 76)
                    font.letterSpacing: text.length > 22 ? -1.4 : -2
                    lineHeight: 0.92
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Row {
                    spacing: 28
                    opacity: heroInfo.enter
                    Text {
                        text: root.current ? (root.current.playTime > 0 ? L.formatPlayTime(root.current.playTime) + " jogadas" : "Ainda não jogado") : ""
                        color: "#c7ffffff"; font.family: "Manrope"; font.weight: Font.Medium; font.pixelSize: 17
                    }
                    Text {
                        visible: root.current !== null && L.playedTime(root.current) > 0
                        text: root.current ? "Último: " + L.shortLastPlayed(root.current.lastPlayed) : ""
                        color: "#c7ffffff"; font.family: "Manrope"; font.weight: Font.Medium; font.pixelSize: 17
                    }
                }
                Text {
                    visible: root.current !== null && !root.current.emuOk
                    text: root.current ? "Falta instalar o " + root.current.emuName + " neste tablet" : ""
                    color: "#ffcc80"
                    font.family: "Manrope"
                    font.weight: Font.Medium
                    font.pixelSize: 17
                }
                Item { width: 1; height: 4 }
                Row {
                    spacing: 14
                    // Jogar / Continuar
                    Rectangle {
                        id: heroPlay
                        width: heroPlayRow.implicitWidth + 62
                        height: 62
                        radius: 31
                        color: "#ffffff"
                        RectangularGlow {
                            anchors.fill: parent
                            z: -1
                            glowRadius: 18
                            spread: 0.05
                            cornerRadius: 31 + glowRadius
                            color: "#2effffff"
                        }
                        Row {
                            id: heroPlayRow
                            anchors.centerIn: parent
                            spacing: 12
                            Item {
                                width: 18; height: 20
                                anchors.verticalCenter: parent.verticalCenter
                                Canvas {
                                    anchors.centerIn: parent
                                    width: 54; height: 60
                                    scale: 1 / 3
                                    renderTarget: Canvas.Image
                                    onPaint: {
                                        var c = getContext("2d");
                                        c.reset();
                                        c.scale(3, 3);
                                        c.fillStyle = "#0b0a14";
                                        c.beginPath(); c.moveTo(2, 1.5); c.lineTo(16, 10); c.lineTo(2, 18.5); c.closePath(); c.fill();
                                    }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.current && !root.current.emuOk ? "Como jogar"
                                    : (root.current && L.playedTime(root.current) > 0 ? "Continuar" : "Jogar")
                                color: "#0b0a14"
                                font.family: "Manrope"
                                font.pixelSize: 20
                                font.weight: Font.Bold
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.launchCurrent() }
                    }
                    // troféus do jogo
                    Glass {
                        backdrop: glassSource
                        stageItem: stage
                        visible: homeView.tinfo.kind === "progress"
                        width: trophyChipRow.implicitWidth + 50
                        height: 62
                        radius: 31
                        Row {
                            id: trophyChipRow
                            anchors.centerIn: parent
                            spacing: 14
                            Item {
                                width: 22; height: 22
                                anchors.verticalCenter: parent.verticalCenter
                                Canvas {
                                    width: 66; height: 66
                                    scale: 1 / 3
                                    anchors.centerIn: parent
                                    renderTarget: Canvas.Image
                                    onPaint: {
                                        var c = getContext("2d");
                                        c.reset();
                                        c.scale(3, 3);
                                        c.strokeStyle = "#ffd36a";
                                        c.lineWidth = 1.8;
                                        c.lineJoin = "round";
                                        c.beginPath();
                                        c.moveTo(6, 3); c.lineTo(16, 3); c.lineTo(16, 8);
                                        c.bezierCurveTo(16, 11, 14, 13, 11, 13);
                                        c.bezierCurveTo(8, 13, 6, 11, 6, 8); c.closePath();
                                        c.moveTo(11, 13); c.lineTo(11, 16);
                                        c.moveTo(7, 19.5); c.lineTo(15, 19.5);
                                        c.moveTo(6, 5); c.lineTo(3, 5); c.bezierCurveTo(3, 8, 4.5, 9.5, 6.5, 9.5);
                                        c.moveTo(16, 5); c.lineTo(19, 5); c.bezierCurveTo(19, 8, 17.5, 9.5, 15.5, 9.5);
                                        c.stroke();
                                    }
                                }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 7
                                Text {
                                    text: homeView.tinfo.kind === "progress" ? homeView.tinfo.got + " de " + homeView.tinfo.total + " troféus" : ""
                                    color: "#ffffff"; font.family: "Manrope"; font.weight: Font.Bold; font.pixelSize: 16
                                }
                                Rectangle {
                                    width: 150; height: 4; radius: 2
                                    color: "#2effffff"
                                    Rectangle {
                                        height: 4; radius: 2
                                        color: "#ffd36a"
                                        width: homeView.tinfo.kind === "progress" && homeView.tinfo.total > 0 ? parent.width * homeView.tinfo.got / homeView.tinfo.total : 0
                                        Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.openDetails() }
                    }
                }
            }

            // ---------------- vitrine 3D (centro-direita)
            Showcase {
                id: showcase
                x: 736
                y: 104
                width: stage.width - 736 - 40
                height: homeView.rowTop - 104 - 8
                entry: root.tab === 0 ? root.current : null
                pixelRatio: root.pixelRatio
                visible: root.tab === 0 && root.current !== null
                active: !root.settingsOpen && !root.accountOpen && !consoles.open && !root.detailsOpen
                        && Qt.application.state === Qt.ApplicationActive
                onInserted: root.sfx(sInsert)
                onLaunchFinished: if (root.launchPhase === "media") root.startFlash()
            }

            // ---------------- fileira de jogos (embaixo)
            Text {
                x: 64
                y: homeView.rowTop
                visible: root.recents.length > 0
                text: root.recentsLabel.toUpperCase()
                color: "#99ffffff"
                font.family: "Manrope"
                font.weight: Font.Bold
                font.pixelSize: 13
                font.letterSpacing: 2.2
            }
            ListView {
                id: recentRow
                x: 64
                y: homeView.rowTop + 34
                width: stage.width - 64
                height: 250
                orientation: ListView.Horizontal
                spacing: 24
                model: root.recents
                currentIndex: root.homeIndex
                highlightMoveDuration: 420
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 2 * 192
                preferredHighlightEnd: 2 * 192 + 168
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 800
                interactive: root.launchPhase === ""
                opacity: root.launchPhase === "" ? 1 : 0.35
                Behavior on opacity { NumberAnimation { duration: 300 } }

                delegate: Item {
                    width: 168
                    height: 250
                    GameTile {
                        y: 40
                        entry: modelData
                        baseSize: 168
                        selScale: 1.14
                        lift: 20
                        selected: index === root.homeIndex && !root.gearFocused
                        pixelRatio: root.pixelRatio
                        onTapped: {
                            root.gearFocused = false;
                            if (index === root.homeIndex) root.launchCurrent();
                            else root.homeIndex = index;
                        }
                        onHeld: { root.homeIndex = index; root.openDetails(); }
                    }
                }
            }

            // ---------------- boas-vindas (sem jogos)
            Glass {
                backdrop: glassSource
                stageItem: stage
                anchors.centerIn: parent
                visible: root.entries.length === 0
                width: 760
                height: welcomeCol.implicitHeight + 72
                radius: 32

                Column {
                    id: welcomeCol
                    x: 44
                    y: 36
                    width: parent.width - 88
                    spacing: 18

                    Text { text: "Bem-vindo ao P7 Station"; color: "#ffffff"; font.family: "Sora"; font.weight: Font.Light; font.pixelSize: 40; font.letterSpacing: -0.8 }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        color: "#c7ffffff"; font.family: "Manrope"; font.pixelSize: 17; lineHeight: 1.35
                        text: "O P7 Station procura sozinho as pastas de jogos que você já tem (ROMs, Jogos, Emulation...). Para começar:"
                    }
                    Repeater {
                        model: [
                            "Deixe os jogos em uma pasta por console, por exemplo ROMs › snes, ROMs › psx. Não renomeie os arquivos: a capa vem pelo nome.",
                            "Aperte X aqui para abrir Consoles e emuladores e escolher a pasta dos seus jogos, se ela não for achada sozinha.",
                            "Instale os emuladores que quiser (RetroArch, DuckStation, NetherSX2, PPSSPP, Dolphin, Cemu, Eden...). O P7 Station acha cada um sozinho.",
                            "Seus jogos aparecem aqui assim que a pasta for encontrada."
                        ]
                        delegate: Row {
                            spacing: 16
                            width: welcomeCol.width
                            Rectangle {
                                width: 30; height: 30; radius: 15
                                color: "#1fffffff"; border.width: 1; border.color: "#33ffffff"
                                Text { anchors.centerIn: parent; text: index + 1; color: "#ffffff"; font.family: "Manrope"; font.pixelSize: 14; font.weight: Font.Bold }
                            }
                            Text {
                                width: parent.width - 46
                                anchors.verticalCenter: parent.verticalCenter
                                wrapMode: Text.WordWrap
                                text: modelData
                                color: "#e6ffffff"; font.family: "Manrope"; font.pixelSize: 16; lineHeight: 1.3
                            }
                        }
                    }
                }
            }
        }

        // =========================================== ABA: BIBLIOTECA
        Item {
            id: libraryView
            anchors.fill: parent
            visible: opacity > 0
            opacity: root.tab === 1 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 240 } }

            readonly property real infoTop: stage.height - 84 - 70

            Text {
                x: 64
                y: 112
                text: "BIBLIOTECA  ·  " + root.libCount + (root.libCount === 1 ? " JOGO" : " JOGOS")
                color: "#99ffffff"
                font.family: "Manrope"
                font.weight: Font.Bold
                font.pixelSize: 13
                font.letterSpacing: 2.2
            }

            // ordem das prateleiras (seta para cima na primeira prateleira chega aqui)
            Glass {
                id: sortBar
                backdrop: glassSource
                stageItem: stage
                anchors.right: parent.right
                anchors.rightMargin: 56
                y: 100
                height: 46
                width: sortRow.width + 8
                radius: 23
                border.width: root.libOnSort ? 3 : (liquid ? 0 : 1)
                border.color: root.libOnSort ? "#ffffff" : "#1cffffff"

                LiquidPill {
                    x: sortRow.x + (target ? target.x : 0)
                    light: true
                    target: sortRepeater.added >= 0 && sortRepeater.count > root.sortMode ? sortRepeater.itemAt(root.sortMode) : null
                }
                Row {
                    id: sortRow
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                        id: sortRepeater
                        property int added: 0
                        onItemAdded: added++
                        model: L.SORTS
                        delegate: Item {
                            width: sortLabel.implicitWidth + 32
                            height: 38
                            Text {
                                id: sortLabel
                                anchors.centerIn: parent
                                text: modelData
                                color: index === root.sortMode ? "#0b0a14" : "#b3ffffff"
                                font.family: "Manrope"
                                font.pixelSize: 15
                                font.weight: index === root.sortMode ? Font.Bold : Font.Medium
                            }
                            MouseArea { anchors.fill: parent; onClicked: if (index !== root.sortMode) root.setSort(index) }
                        }
                    }
                }
            }

            // sem jogos: explica o que fazer, em vez de uma tela vazia
            Column {
                x: 64
                y: 190
                width: 760
                spacing: 14
                visible: root.entries.length === 0
                Text { text: "Nenhum jogo ainda"; color: "#ffffff"; font.family: "Sora"; font.weight: Font.Light; font.pixelSize: 40 }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    lineHeight: 1.35
                    color: "#c7ffffff"; font.family: "Manrope"; font.pixelSize: 18
                    text: "Coloque os jogos numa pasta por console (por exemplo ROMs › snes) no armazenamento do tablet. Eles aparecem aqui sozinhos, em prateleiras, na próxima vez que o P7 Station abrir."
                }
            }

            ListView {
                id: shelfView
                x: 0
                y: 150
                width: stage.width
                height: libraryView.infoTop - y - 12
                clip: true
                model: root.shelves
                currentIndex: root.libShelf
                highlightMoveDuration: 380
                highlightRangeMode: ListView.ApplyRange
                // a prateleira escolhida fica no alto (a de baixo aparece pela metade, convidando a descer)
                preferredHighlightBegin: 0
                preferredHighlightEnd: 266
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 600

                delegate: Item {
                    id: shelf
                    readonly property int si: index
                    readonly property bool isCur: index === root.libShelf
                    width: shelfView.width
                    height: 266

                    Row {
                        x: 76
                        y: 6
                        spacing: 12
                        Text {
                            text: modelData.name
                            color: shelf.isCur ? "#ffffff" : "#b3ffffff"
                            font.family: "Sora"
                            font.weight: Font.DemiBold
                            font.pixelSize: 22
                        }
                        Text {
                            anchors.baseline: parent.children[0].baseline
                            text: modelData.items.length + (modelData.items.length === 1 ? " jogo" : " jogos")
                            color: "#8cffffff"
                            font.family: "Manrope"
                            font.weight: Font.Medium
                            font.pixelSize: 15
                        }
                    }

                    // a prateleira (tábua de vidro embaixo das capas)
                    Rectangle {
                        x: 56
                        y: 226
                        width: parent.width - 56
                        height: 18
                        radius: 9
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#29ffffff" }
                            GradientStop { position: 1.0; color: "#08ffffff" }
                        }
                        Rectangle {
                            anchors.top: parent.bottom
                            width: parent.width
                            height: 22
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#59000000" }
                                GradientStop { position: 1.0; color: "#00000000" }
                            }
                        }
                    }

                    ListView {
                        id: shelfRow
                        x: 76
                        y: 40
                        width: parent.width - 76
                        height: 196
                        orientation: ListView.Horizontal
                        spacing: 22
                        model: modelData.items
                        currentIndex: shelf.isCur ? root.libCol : root.colFor(shelf.si)
                        highlightMoveDuration: 320
                        highlightRangeMode: ListView.ApplyRange
                        preferredHighlightBegin: 0
                        preferredHighlightEnd: width - 260
                        boundsBehavior: Flickable.StopAtBounds
                        cacheBuffer: 600

                        delegate: Item {
                            width: 150
                            height: 196
                            GameTile {
                                y: 36
                                entry: modelData
                                baseSize: 150
                                selScale: 1.1
                                lift: 12
                                dimOpacity: shelf.isCur ? 0.9 : 0.7
                                selected: shelf.isCur && index === root.libCol && !root.libOnSort && root.tab === 1
                                pixelRatio: root.pixelRatio
                                onTapped: {
                                    root.libOnSort = false;
                                    if (shelf.isCur && index === root.libCol) { root.launchCurrent(); return; }
                                    if (!shelf.isCur) root.moveShelf(shelf.si - root.libShelf);
                                    root.libCol = index;
                                }
                                onHeld: {
                                    if (!shelf.isCur) root.moveShelf(shelf.si - root.libShelf);
                                    root.libCol = index;
                                    root.openDetails();
                                }
                            }
                        }
                    }
                }
            }

            // jogo selecionado (barra embaixo)
            Glass {
                id: libInfo
                backdrop: glassSource
                stageItem: stage
                x: 56
                y: libraryView.infoTop
                width: stage.width - 112
                height: 84
                radius: 28
                visible: root.current !== null && root.tab === 1

                GameTile {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    baseSize: 54
                    entry: root.tab === 1 ? root.current : null
                    selected: false
                    dimOpacity: 1
                    showRing: false
                    pixelRatio: root.pixelRatio
                    cornerRadius: 12
                }
                Column {
                    x: 88
                    width: parent.width - x - libButtons.width - 40
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text {
                        width: parent.width
                        text: root.current ? root.current.display : ""
                        color: "#ffffff"; font.family: "Sora"; font.weight: Font.DemiBold; font.pixelSize: 22
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: {
                            if (!root.current) return "";
                            var c = root.current;
                            if (!c.emuOk) return c.sysName + "  ·  Falta instalar o " + c.emuName;
                            var t = root.trophyInfo(c);
                            return c.sysName + (c.emuFull ? "  ·  " + c.emuFull : "")
                                 + (t.kind === "progress" ? "  ·  " + t.got + " de " + t.total + " troféus" : "")
                                 + (c.playTime > 0 ? "  ·  " + L.formatPlayTime(c.playTime) : "");
                        }
                        color: root.current && !root.current.emuOk ? "#ffcc80" : "#a6ffffff"
                        font.family: "Manrope"; font.weight: Font.Medium; font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                }
                Row {
                    id: libButtons
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Rectangle {
                        width: 120; height: 52; radius: 26
                        color: "#17ffffff"; border.width: 1; border.color: "#33ffffff"
                        Text { anchors.centerIn: parent; text: "Detalhes"; color: "#ffffff"; font.family: "Manrope"; font.weight: Font.Bold; font.pixelSize: 16 }
                        MouseArea { anchors.fill: parent; onClicked: root.openDetails() }
                    }
                    Rectangle {
                        width: libPlayText.implicitWidth + 56; height: 52; radius: 26
                        color: "#ffffff"
                        Text {
                            id: libPlayText
                            anchors.centerIn: parent
                            text: root.current && !root.current.emuOk ? "Como jogar" : (root.current && L.playedTime(root.current) > 0 ? "Continuar" : "Jogar")
                            color: "#0b0a14"; font.family: "Manrope"; font.weight: Font.Bold; font.pixelSize: 17
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.launchCurrent() }
                    }
                }
            }
        }

        // ============================================== ABA: TROFÉUS
        Item {
            id: trophyView
            anchors.fill: parent
            visible: opacity > 0
            opacity: root.tab === 2 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 240 } }

            readonly property real paneX: 650
            readonly property real bottomY: stage.height - 92

            // resumo geral
            Glass {
                backdrop: glassSource
                stageItem: stage
                x: 56
                y: 104
                width: 560
                height: 100
                radius: 28
                visible: root.raState === "ok"
                Ring {
                    x: 22
                    anchors.verticalCenter: parent.verticalCenter
                    width: 62; height: 62
                    lineWidth: 5
                    pixelRatio: root.pixelRatio
                    value: root.raTotal > 0 ? root.raGot / root.raTotal : 0
                    Text {
                        anchors.centerIn: parent
                        text: root.raTotal > 0 ? Math.round(100 * root.raGot / root.raTotal) + "%" : "0%"
                        color: "#ffffff"; font.family: "Manrope"; font.weight: Font.Bold; font.pixelSize: 14
                    }
                }
                Row {
                    x: 106
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 36
                    Column {
                        spacing: 6
                        Text { text: "CONQUISTADOS"; color: "#80ffffff"; font.family: "Manrope"; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 1.6 }
                        Text { text: root.raGot + " de " + root.raTotal; color: "#ffffff"; font.family: "Sora"; font.pixelSize: 24 }
                    }
                    Column {
                        spacing: 6
                        Text { text: "JOGOS COM TROFÉUS"; color: "#80ffffff"; font.family: "Manrope"; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 1.6 }
                        Text { text: root.trophyList.length; color: "#ffffff"; font.family: "Sora"; font.pixelSize: 24 }
                    }
                }
            }

            Rectangle {
                id: accountButton
                anchors.right: parent.right
                anchors.rightMargin: 56
                y: 104
                visible: root.raState !== "ok"
                width: accountLabel.implicitWidth + 44
                height: 48
                radius: 24
                color: root.raState === "off" ? "#ffffff" : "#17ffffff"
                border.width: 1
                border.color: "#33ffffff"
                Text {
                    id: accountLabel
                    anchors.centerIn: parent
                    text: root.raState === "off" ? "Conectar conta" : "Conta: " + root.raUser()
                    color: root.raState === "off" ? "#0b0a14" : "#e6ffffff"
                    font.family: "Manrope"; font.pixelSize: 16
                    font.weight: Font.Bold
                }
                MouseArea { anchors.fill: parent; onClicked: root.accountOpen = true }
            }

            Text {
                x: 56
                y: 116
                width: 820
                visible: root.raState !== "ok"
                wrapMode: Text.WordWrap
                color: "#d9ffffff"
                font.family: "Manrope"
                font.pixelSize: 19
                lineHeight: 1.35
                text: root.raState === "loading" ? "Carregando seus troféus…"
                    : root.raState === "error" ? "Não foi possível falar com o RetroAchievements. Confira a internet e, em Conta, o usuário e a chave."
                    : "Troféus desligados. Toque em Conectar conta e entre com seu usuário e sua chave do RetroAchievements."
            }

            Text {
                x: 56
                y: 236
                width: 560
                wrapMode: Text.WordWrap
                visible: root.raState === "ok" && root.trophyList.length === 0
                text: Object.keys(root.raCatalogs).length > 0
                      ? "Nenhum jogo da sua biblioteca está no RetroAchievements (o nome do arquivo precisa ser o nome original do jogo)."
                      : "Procurando os jogos da sua biblioteca no RetroAchievements…"
                color: "#b3ffffff"
                font.family: "Manrope"
                font.pixelSize: 17
                lineHeight: 1.3
            }

            // jogos com troféus
            ListView {
                id: trophyListView
                x: 56
                y: 224
                width: 560
                height: trophyView.bottomY - y
                clip: true
                spacing: 6
                model: root.trophyList
                currentIndex: root.trophyIndex
                highlightMoveDuration: 220
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: height - 90
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    readonly property bool isSel: index === root.trophyIndex
                    width: 560
                    height: 84
                    radius: 20
                    color: isSel ? (root.trophyFocus === 0 ? "#29ffffff" : "#14ffffff") : "transparent"
                    border.width: isSel ? (root.trophyFocus === 0 ? 2 : 1) : 0
                    border.color: root.trophyFocus === 0 ? "#e6ffffff" : "#33ffffff"
                    Behavior on color { ColorAnimation { duration: 160 } }

                    GameTile {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        entry: modelData.entry
                        baseSize: 60
                        selected: false
                        dimOpacity: 1
                        showRing: false
                        cornerRadius: 14
                        pixelRatio: root.pixelRatio
                    }
                    Column {
                        x: 88
                        width: parent.width - x - 150
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text {
                            width: parent.width
                            text: modelData.entry.display
                            color: "#ffffff"
                            font.family: "Manrope"
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.entry.sysName + "  ·  " + modelData.got + " de " + modelData.total
                            color: "#99ffffff"
                            font.family: "Manrope"
                            font.weight: Font.Medium
                            font.pixelSize: 14
                        }
                    }
                    Ring {
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: 50; height: 50
                        lineWidth: 4
                        pixelRatio: root.pixelRatio
                        value: modelData.total > 0 ? modelData.got / modelData.total : 0
                        color: modelData.total > 0 && modelData.got >= modelData.total ? "#5ff0a8" : "#ffd36a"
                        Text {
                            anchors.centerIn: parent
                            text: modelData.total > 0 ? Math.round(100 * modelData.got / modelData.total) + "%" : ""
                            color: "#ffffff"; font.family: "Manrope"; font.weight: Font.Bold; font.pixelSize: 12
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.trophyFocus = 0;
                            if (index === root.trophyIndex) root.launchCurrent();
                            else root.trophyIndex = index;
                        }
                        onPressAndHold: { root.trophyIndex = index; root.openDetails(); }
                    }
                }
            }

            // conquistas do jogo selecionado
            Glass {
                id: achPane
                backdrop: glassSource
                stageItem: stage
                x: trophyView.paneX
                y: 104
                width: stage.width - x - 56
                height: trophyView.bottomY - y
                radius: 32
                visible: root.raState === "ok" && root.curTrophy !== null

                readonly property var a: root.curAch
                readonly property var list: a && a.state === "ok" ? a.list : []
                readonly property var sel: list.length ? list[L.clampIndex(root.achIndex, list.length)] : null

                Column {
                    x: 32; y: 26
                    width: parent.width - 64
                    spacing: 6
                    Text {
                        width: parent.width
                        text: root.curTrophy ? root.curTrophy.entry.display : ""
                        color: "#ffffff"; font.family: "Sora"; font.weight: Font.Light; font.pixelSize: 32
                        elide: Text.ElideRight
                    }
                    Text {
                        text: {
                            var a = achPane.a;
                            if (!a || a.state === "loading") return "Carregando conquistas…";
                            if (a.state === "error") return "Não foi possível carregar as conquistas agora";
                            return a.got + " de " + a.total + " conquistas  ·  " + a.pointsGot + " de " + a.points + " pontos";
                        }
                        color: "#b3ffffff"; font.family: "Manrope"; font.weight: Font.Medium; font.pixelSize: 15
                    }
                }

                GridView {
                    id: achGrid
                    readonly property int columns: Math.max(1, Math.floor(width / cellWidth))
                    x: 26
                    y: 108
                    width: parent.width - 52
                    height: parent.height - y - 148
                    cellWidth: 92
                    cellHeight: 92
                    clip: true
                    model: achPane.list
                    currentIndex: root.achIndex
                    highlightMoveDuration: 200
                    highlightRangeMode: GridView.ApplyRange
                    preferredHighlightBegin: 6
                    preferredHighlightEnd: height - 6
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 400

                    delegate: Item {
                        width: 92; height: 92
                        readonly property bool isSel: index === root.achIndex && root.trophyFocus === 1
                        Item {
                            anchors.centerIn: parent
                            width: 70; height: 70
                            scale: isSel ? 1.14 : 1
                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                            Rectangle { anchors.fill: parent; radius: 16; color: "#1fffffff" }
                            Image {
                                anchors.fill: parent
                                source: modelData.badge ? "https://media.retroachievements.org/Badge/" + modelData.badge + (modelData.earned ? "" : "_lock") + ".png" : ""
                                asynchronous: true
                                cache: true
                                sourceSize.width: 128
                                opacity: modelData.earned ? 1 : 0.5
                                layer.enabled: true
                                layer.textureSize: Qt.size(128, 128)
                                layer.effect: OpacityMask { maskSource: Rectangle { width: 70; height: 70; radius: 16 } }
                            }
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: isSel ? -4 : 0
                                radius: isSel ? 20 : 16
                                color: "transparent"
                                border.width: isSel ? 3 : 1
                                border.color: isSel ? "#ffffff" : (modelData.earned ? "#66ffd36a" : "#1fffffff")
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: { root.achIndex = index; root.trophyFocus = 1; } }
                    }
                }

                // descrição da conquista escolhida
                Rectangle {
                    x: 20
                    width: parent.width - 40
                    height: 120
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 20
                    radius: 24
                    color: "#26000000"
                    border.width: 1
                    border.color: "#1affffff"
                    visible: achPane.sel !== null
                    Image {
                        x: 20
                        anchors.verticalCenter: parent.verticalCenter
                        width: 80; height: 80
                        source: achPane.sel ? "https://media.retroachievements.org/Badge/" + achPane.sel.badge + (achPane.sel.earned ? "" : "_lock") + ".png" : ""
                        asynchronous: true
                        cache: true
                        sourceSize.width: 160
                        layer.enabled: true
                        layer.textureSize: Qt.size(160, 160)
                        layer.effect: OpacityMask { maskSource: Rectangle { width: 80; height: 80; radius: 18 } }
                    }
                    Column {
                        x: 120
                        width: parent.width - x - 170
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Text {
                            width: parent.width
                            text: achPane.sel ? achPane.sel.title : ""
                            color: "#ffffff"; font.family: "Sora"; font.weight: Font.DemiBold; font.pixelSize: 20
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: achPane.sel ? achPane.sel.desc : ""
                            color: "#c7ffffff"; font.family: "Manrope"; font.pixelSize: 15
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                    Column {
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Text {
                            anchors.right: parent.right
                            text: achPane.sel ? achPane.sel.points + " pts" : ""
                            color: "#ffd36a"; font.family: "Sora"; font.weight: Font.DemiBold; font.pixelSize: 20
                        }
                        Text {
                            anchors.right: parent.right
                            text: achPane.sel ? (achPane.sel.earned ? L.formatDateBR(achPane.sel.date) : "Bloqueada") : ""
                            color: achPane.sel && achPane.sel.earned ? "#5ff0a8" : "#80ffffff"
                            font.family: "Manrope"; font.weight: Font.Bold; font.pixelSize: 14
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------- página do jogo
        DetailsPage {
            id: detailsPage
            anchors.fill: parent
            host: root
            backdrop: glassSource
            stageItem: stage
            open: root.detailsOpen
        }

        // ---------------------------------------------------- configurações
        Rectangle {
            anchors.fill: parent
            visible: root.settingsOpen
            color: "#99050608"
            MouseArea { anchors.fill: parent; onClicked: root.settingsOpen = false }

            Glass {
                backdrop: glassSource
                stageItem: stage
                anchors.right: parent.right
                anchors.rightMargin: 56
                y: 100
                width: 520
                height: settingsCol.implicitHeight + 64
                radius: 32
                tint: "#33101018"
                MouseArea { anchors.fill: parent }

                Column {
                    id: settingsCol
                    x: 28; y: 30
                    width: parent.width - 56
                    spacing: 6

                    Text { text: "Configurações"; leftPadding: 12; bottomPadding: 12; color: "#ffffff"; font.family: "Sora"; font.weight: Font.Light; font.pixelSize: 30 }

                    Repeater {
                        model: [
                            { title: "Consoles e emuladores", detail: "Pastas dos jogos e emulador de cada console" },
                            { title: "Conta do RetroAchievements", detail: root.raState === "off" ? "Não conectada" : root.raUser() },
                            { title: "Sons", detail: "Volume: " + root.soundLevelNames[root.soundLevel] + "  ·  esquerda e direita mudam" },
                            { title: "Trava para crianças", detail: root.kidLock ? "Ligada: segure Options para abrir as configurações" : "Desligada" },
                            { title: "Atualizar biblioteca", detail: "Procura jogos e emuladores novos" },
                            { title: "Fechar", detail: "" }
                        ]
                        delegate: Rectangle {
                            width: settingsCol.width
                            height: modelData.detail ? 66 : 52
                            radius: 18
                            color: index === root.settingsIndex ? "#24ffffff" : "transparent"
                            border.width: index === root.settingsIndex ? 1 : 0
                            border.color: "#40ffffff"
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 16
                                spacing: 3
                                Text { text: modelData.title; color: "#f2ffffff"; font.family: "Manrope"; font.weight: Font.Bold; font.pixelSize: 17 }
                                Text { visible: modelData.detail !== ""; text: modelData.detail; color: "#8cffffff"; font.family: "Manrope"; font.pixelSize: 13 }
                            }
                            // chave liga/desliga da trava
                            Rectangle {
                                visible: index === 3
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                width: 52; height: 30; radius: 15
                                color: root.kidLock ? "#e6ffffff" : "#26ffffff"
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Rectangle {
                                    width: 24; height: 24; radius: 12
                                    y: 3
                                    x: root.kidLock ? 25 : 3
                                    color: root.kidLock ? "#0b0c0f" : "#ffffff"
                                    Behavior on x { SpringAnimation { spring: 5; damping: 0.35 } }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { root.settingsIndex = index; root.settingsActivate(index); }
                            }
                        }
                    }

                    Item { width: 1; height: 10 }
                    Text {
                        width: parent.width
                        leftPadding: 12
                        wrapMode: Text.WordWrap
                        color: "#73ffffff"; font.family: "Manrope"; font.pixelSize: 13; lineHeight: 1.35
                        text: "Para abrir o P7 Station ao ligar o tablet: Configurações do Android › Apps › Apps padrão › Tela inicial.\nOptions (ou Start) abre esta tela; com a trava ligada, segure o botão."
                    }
                }
            }
        }

        // ------------------------------------------- conta do RetroAchievements
        Rectangle {
            anchors.fill: parent
            visible: root.accountOpen
            color: "#b3050608"
            MouseArea { anchors.fill: parent; onClicked: { root.accountOpen = false; root.forceActiveFocus(); } }

            Glass {
                backdrop: glassSource
                stageItem: stage
                anchors.centerIn: parent
                width: 560
                height: 420
                radius: 32
                color: "#2a1c1e24"
                MouseArea { anchors.fill: parent }

                Column {
                    x: 40; y: 34
                    width: parent.width - 80
                    spacing: 14

                    Text { text: "RetroAchievements"; color: "#ffffff"; font.family: "Sora"; font.weight: Font.Light; font.pixelSize: 30 }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Crie a conta grátis em retroachievements.org. A chave fica em Settings › Web API Key."
                        color: "#b3ffffff"; font.family: "Manrope"; font.pixelSize: 15; lineHeight: 1.3
                    }
                    Text { text: "USUÁRIO"; color: "#80ffffff"; font.family: "Manrope"; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 1.4 }
                    Rectangle {
                        width: parent.width; height: 48; radius: 14
                        color: "#14ffffff"; border.width: 1; border.color: userField.activeFocus ? "#99ffffff" : "#26ffffff"
                        TextInput {
                            id: userField
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#ffffff"; font.family: "Manrope"; font.pixelSize: 17
                            selectByMouse: true
                            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                            text: root.accountOpen ? root.raUser() : ""
                            KeyNavigation.tab: keyField
                        }
                    }
                    Text { text: "WEB API KEY"; color: "#80ffffff"; font.family: "Manrope"; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 1.4 }
                    Rectangle {
                        width: parent.width; height: 48; radius: 14
                        color: "#14ffffff"; border.width: 1; border.color: keyField.activeFocus ? "#99ffffff" : "#26ffffff"
                        TextInput {
                            id: keyField
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#ffffff"; font.family: "Manrope"; font.pixelSize: 17
                            selectByMouse: true
                            echoMode: TextInput.PasswordEchoOnEdit
                            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                            text: root.accountOpen ? root.raKey() : ""
                        }
                    }
                    Item { width: 1; height: 4 }
                    Row {
                        spacing: 12
                        Rectangle {
                            width: 140; height: 48; radius: 24; color: "#ebffffff"
                            Text { anchors.centerIn: parent; text: "Salvar"; color: "#0b0c0f"; font.family: "Manrope"; font.pixelSize: 16; font.weight: Font.Bold }
                            MouseArea { anchors.fill: parent; onClicked: root.saveAccount(userField.text, keyField.text) }
                        }
                        Rectangle {
                            width: 140; height: 48; radius: 24; color: "#14ffffff"; border.width: 1; border.color: "#26ffffff"
                            Text { anchors.centerIn: parent; text: "Cancelar"; color: "#e6ffffff"; font.family: "Manrope"; font.pixelSize: 16 }
                            MouseArea { anchors.fill: parent; onClicked: { root.accountOpen = false; root.forceActiveFocus(); } }
                        }
                    }
                }
            }
        }

        // ------------------------------------------- consoles e emuladores
        ConsolesPanel {
            id: consoles
            host: root
            backdrop: glassSource
            stageItem: stage
            onFinished: { root.syncLibrary(); root.refresh(); root.forceActiveFocus(); }
        }

        // ---------------------------------------------------- aviso com botão
        Rectangle {
            anchors.fill: parent
            visible: root.noticeOpen
            color: "#b3050608"
            MouseArea { anchors.fill: parent; onClicked: root.noticeOpen = false }
            Glass {
                backdrop: glassSource
                stageItem: stage
                anchors.centerIn: parent
                width: 640
                height: noticeCol.implicitHeight + 72
                radius: 32
                tint: "#38101018"
                MouseArea { anchors.fill: parent }
                Column {
                    id: noticeCol
                    x: 40; y: 36
                    width: parent.width - 80
                    spacing: 16
                    Text { text: root.noticeTitle; color: "#ffffff"; font.family: "Sora"; font.weight: Font.Light; font.pixelSize: 32 }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: root.noticeText
                        color: "#e6ffffff"; font.family: "Manrope"; font.pixelSize: 19; lineHeight: 1.35
                    }
                    Item { width: 1; height: 4 }
                    Rectangle {
                        width: 180; height: 52; radius: 26; color: "#ebffffff"
                        Text { anchors.centerIn: parent; text: "Entendi"; color: "#0b0c0f"; font.family: "Manrope"; font.pixelSize: 18; font.weight: Font.Bold }
                        MouseArea { anchors.fill: parent; onClicked: root.noticeOpen = false }
                    }
                }
            }
        }

        // ---------------------------------------------------- rodapé
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 56
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 26
            spacing: 28
            visible: !root.settingsOpen && !root.accountOpen && !consoles.open && root.launchPhase === ""

            Repeater {
                model: {
                    var favLabel = root.current && root.current.fav ? "Desfavoritar" : "Favoritar";
                    if (root.detailsOpen)
                        return [ { glyph: "cross", label: "Escolher" }, { glyph: "triangle", label: favLabel }, { glyph: "circle", label: "Voltar" } ];
                    if (root.tab === 0) {
                        if (root.gearFocused) return [ { glyph: "cross", label: root.kidLock ? "Segure: configurações" : "Configurações" }, { glyph: "circle", label: "Voltar" } ];
                        if (!root.current) return [ { glyph: "cross", label: "Consoles" }, { glyph: "lr", label: "Trocar aba" } ];
                        return [ { glyph: "cross", label: "Jogar" }, { glyph: "square", label: "Detalhes" }, { glyph: "triangle", label: favLabel }, { glyph: "lr", label: "Trocar aba" } ];
                    }
                    if (root.tab === 1) {
                        if (!root.current) return [ { glyph: "circle", label: "Voltar" }, { glyph: "lr", label: "Trocar aba" } ];
                        if (root.libOnSort) return [ { glyph: "leftright", label: "Mudar ordem" }, { glyph: "cross", label: "Pronto" } ];
                        return [ { glyph: "cross", label: "Jogar" }, { glyph: "square", label: "Detalhes" }, { glyph: "triangle", label: favLabel },
                                 { glyph: "circle", label: "Voltar" }, { glyph: "lr", label: "Trocar aba" } ];
                    }
                    if (root.trophyFocus === 1)
                        return [ { glyph: "left", label: "Jogos" }, { glyph: "circle", label: "Voltar" } ];
                    if (!root.current) return [ { glyph: "circle", label: "Voltar" }, { glyph: "lr", label: "Trocar aba" } ];
                    return [ { glyph: "cross", label: "Jogar" }, { glyph: "square", label: "Detalhes" }, { glyph: "right", label: "Conquistas" },
                             { glyph: "circle", label: "Voltar" }, { glyph: "lr", label: "Trocar aba" } ];
                }
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

        // ---------------------------------------------------- abrir o jogo
        // clarão
        RadialGradient {
            id: flashLayer
            anchors.fill: parent
            opacity: 0
            visible: opacity > 0
            horizontalOffset: root.tab === 0 && !root.detailsOpen ? width * 0.18 : 0
            horizontalRadius: width * 0.75
            verticalRadius: height * 0.95
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#ffffff" }
                GradientStop { position: 0.3; color: Qt.rgba(0.75, 0.7, 1.0, 0.92) }
                GradientStop { position: 0.75; color: "#0005040b" }
            }
        }
        // tela "Abrindo…"
        Item {
            id: opening
            anchors.fill: parent
            visible: root.launchPhase === "open"
            readonly property var e: root.launchEntry

            Rectangle { anchors.fill: parent; color: "#05040b" }
            RadialGradient {
                anchors.fill: parent
                verticalOffset: -height * 0.06
                horizontalRadius: width * 0.5
                verticalRadius: height * 0.6
                gradient: Gradient {
                    GradientStop { position: 0.0; color: opening.e ? Qt.rgba(Qt.lighter(opening.e.color, 1.2).r, Qt.lighter(opening.e.color, 1.2).g, Qt.lighter(opening.e.color, 1.2).b, 0.35) : "#22000000" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Column {
                anchors.centerIn: parent
                spacing: 20
                Item {
                    width: 150; height: 150
                    anchors.horizontalCenter: parent.horizontalCenter
                    RectangularGlow {
                        anchors.fill: parent
                        glowRadius: 40
                        spread: 0.15
                        cornerRadius: 30 + glowRadius
                        color: opening.e ? Qt.lighter(opening.e.color, 1.3) : "#6a4cff"
                        opacity: 0.45
                    }
                    GameTile {
                        anchors.fill: parent
                        baseSize: 150
                        entry: opening.e
                        selected: false
                        dimOpacity: 1
                        showRing: false
                        pixelRatio: root.pixelRatio
                    }
                }
                Item { width: 1; height: 6 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: opening.e ? opening.e.display : ""
                    color: "#ffffff"
                    font.family: "Sora"
                    font.weight: Font.Light
                    font.pixelSize: 38
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: opening.e ? "Abrindo " + (opening.e.emuFull || opening.e.emuName || "o jogo") : ""
                    color: "#a6ffffff"
                    font.family: "Manrope"
                    font.weight: Font.Medium
                    font.pixelSize: 18
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            width: 10; height: 10; radius: 5
                            color: "#ffffff"
                            opacity: 0.25
                            SequentialAnimation on opacity {
                                running: opening.visible
                                loops: Animation.Infinite
                                PauseAnimation { duration: index * 150 }
                                NumberAnimation { to: 1; duration: 300 }
                                NumberAnimation { to: 0.25; duration: 300 }
                                PauseAnimation { duration: (2 - index) * 150 + 100 }
                            }
                        }
                    }
                }
            }
        }
        SequentialAnimation {
            id: flashAnim
            NumberAnimation { target: flashLayer; property: "opacity"; from: 0; to: 1; duration: 340; easing.type: Easing.OutQuad }
            ScriptAction { script: root.launchPhase = "open" }
            NumberAnimation { target: flashLayer; property: "opacity"; to: 0; duration: 620; easing.type: Easing.InOutQuad }
            PauseAnimation { duration: 420 }
            ScriptAction { script: root.doLaunch() }
        }
        // toque na tela durante a animação: não deixa abrir outra coisa por baixo
        MouseArea {
            anchors.fill: parent
            visible: root.launchPhase !== ""
            onClicked: if (root.launchPhase === "media") root.startFlash()
        }

        // ---------------------------------------------------- aviso rápido
        Glass {
            id: toastBox
            backdrop: glassSource
            stageItem: stage
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.toastText !== "" ? 30 : -80
            Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            visible: y > -80
            width: toastLabel.implicitWidth + 56
            height: 54
            radius: 27
            tint: "#40101018"
            Text {
                id: toastLabel
                anchors.centerIn: parent
                text: root.toastShown
                color: "#ffffff"
                font.family: "Manrope"
                font.weight: Font.Medium
                font.pixelSize: 18
            }
        }

        // ---------------------------------------------------- abertura
        // Continua de onde a tela de carregamento parou (mesmo ícone, mesmo lugar): um brilho
        // se abre atrás do ícone com o som de abertura e o menu aparece. Cerca de 1,5 s.
        Item {
            id: intro
            anchors.fill: parent
            visible: root.introOn
            property real glow: 0
            property real pop: 0
            property real fade: 1
            // mesma medida e posição do ícone da tela de carregamento (que é desenhada na escala da janela)
            readonly property real logoSize: Math.min(root.width, root.height) * 0.26 / root.ui
            readonly property real ws: Math.min(root.width / 1280, root.height / 720) / root.ui   // vpx() da tela de carregamento

            Rectangle { anchors.fill: parent; color: "#08061c"; opacity: intro.fade }
            RadialGradient {
                anchors.fill: parent
                opacity: intro.glow * intro.fade
                horizontalRadius: parent.width * (0.18 + 0.42 * intro.glow)
                verticalRadius: horizontalRadius
                verticalOffset: -intro.logoSize * 0.45
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#6a4cff" }
                    GradientStop { position: 0.4; color: "#24186e" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Image {
                id: introLogo
                source: "p7-icon.png"
                width: intro.logoSize; height: width
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
                anchors.bottomMargin: 10 * intro.ws
                sourceSize.width: 512
                smooth: true
                opacity: intro.fade
                scale: 1 + 0.07 * intro.pop
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.verticalCenter
                anchors.topMargin: 28 * intro.ws
                text: "P7  STATION"
                color: "#ffffff"
                font.family: "Roboto"
                font.pixelSize: 26 * intro.ws
                font.weight: Font.Light
                font.letterSpacing: (8 + 5 * intro.pop) * intro.ws
                opacity: (0.9 + 0.1 * intro.pop) * intro.fade
            }
            MouseArea { anchors.fill: parent; onClicked: root.skipIntro() }

            SequentialAnimation {
                id: introAnim
                PropertyAction { target: intro; property: "fade"; value: 1 }
                ParallelAnimation {
                    NumberAnimation { target: intro; property: "glow"; from: 0; to: 1; duration: 750; easing.type: Easing.OutCubic }
                    NumberAnimation { target: intro; property: "pop"; from: 0; to: 1; duration: 750; easing.type: Easing.OutBack }
                }
                PauseAnimation { duration: 250 }
                ScriptAction { script: introOutAnim.restart() }
            }
            SequentialAnimation {
                id: introOutAnim
                NumberAnimation { target: intro; property: "fade"; to: 0; duration: 450; easing.type: Easing.InOutQuad }
                ScriptAction { script: { root.introOn = false; intro.glow = 0; intro.pop = 0; intro.fade = 1; } }
            }
        }
    }
}
