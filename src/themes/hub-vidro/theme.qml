import QtQuick 2.15
import QtQuick.Window 2.15
import QtGraphicalEffects 1.12
import QtMultimedia 5.8
import "logic.js" as L
import "config.js" as Cfg
import "emulators.js" as EM

// Hub Vidro — tema do Pegasus para o Xiaomi Pad 7 com controle.
// Abas: Início (recentes + Continuar), Biblioteca (por console ou A–Z), Troféus (RetroAchievements).
FocusScope {
    id: root
    focus: true

    // ---------------------------------------------------------------- dados
    property var entries: []
    property var recents: []
    property string recentsLabel: "Jogados recentemente"
    property int homeIndex: 0

    property int tab: 0                       // 0 Início · 1 Biblioteca · 2 Troféus
    readonly property var tabNames: ["Início", "Biblioteca", "Troféus"]

    property var filters: []
    property int filterIndex: 0
    property var libraryList: []
    property int libIndex: 0
    property bool libOnFilters: false
    property int sortMode: 0                  // 0 A–Z · 1 Recentes · 2 Mais jogados
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
    property var raIndex: null
    property string raState: "off"            // off · loading · ok · error
    property int raGot: 0
    property int raTotal: 0

    // Fundo: tenta a imagem de fundo do jogo; se não existir, usa a capa.
    property bool bgUseArt: false
    onCurrentChanged: bgUseArt = false

    readonly property var current: {
        if (tab === 0) return recents.length ? recents[L.clampIndex(homeIndex, recents.length)] : null;
        if (tab === 1) return libraryList.length ? libraryList[L.clampIndex(libIndex, libraryList.length)] : null;
        return trophyList.length ? trophyList[L.clampIndex(trophyIndex, trophyList.length)].entry : null;
    }

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
    onLibIndexChanged: sfx(sMove)
    onTrophyIndexChanged: sfx(sMove)
    onFilterIndexChanged: sfx(sMove)
    onLibOnFiltersChanged: sfx(sMove)
    onAccountOpenChanged: { sfx(accountOpen ? sConfirm : sBack); bumpLayout(); }
    onSettingsOpenChanged: { sfx(settingsOpen ? sConfirm : sBack); bumpLayout(); }
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
        var bg = assets.background || assets.screenshot || L.thumbUrl(sys, base, "snap") || art;
        // emulador que vai abrir este jogo, e se ele está instalado (sem lista de apps = não dá para saber)
        var sysDef = EM.byKey(sys);
        var known = Object.keys(p7Installed).length > 0;
        var emu = sysDef ? EM.effectiveEmu(sysDef, p7Emus[sys], p7Installed) : null;
        return {
            emuOk: !emu || !known || EM.isInstalled(emu, p7Installed),
            emuName: emu ? emu.label : "",
            emuHint: emu && known ? EM.setupHint(sysDef, emu, p7Installed) : "",
            game: g,
            title: g.title,
            display: L.cleanTitle(g.title),
            mono: L.monogram(g.title),
            sys: sys,
            sysName: info.name,
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

    function refresh() {
        var wasQuiet = quiet;
        quiet = true;
        var keepHome = recents.length ? recents[L.clampIndex(homeIndex, recents.length)].key : api.memory.get("homeKey");
        var keepLib = libraryList.length ? libraryList[L.clampIndex(libIndex, libraryList.length)].key : api.memory.get("libKey");

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

        var keepFilter = filters.length > filterIndex ? filters[filterIndex].key
                       : (api.memory.has("filterKey") ? String(api.memory.get("filterKey")) : "");
        filters = L.libraryFilters(out);
        filterIndex = L.indexOfFilter(filters, keepFilter);
        libraryList = L.filterList(out, filters[filterIndex].key, sortMode);
        var li = keepLib ? indexOfKey(libraryList, keepLib) : -1;
        libIndex = li >= 0 ? li : 0;

        rebuildTrophies();
        quiet = wasQuiet;
    }

    function setFilter(i) {
        filterIndex = L.clampIndex(i, filters.length);
        libraryList = L.filterList(entries, filters[filterIndex].key, sortMode);
        libIndex = 0;
        api.memory.set("filterKey", filters[filterIndex].key);
    }

    function setSort(m) {
        sortMode = (m + 3) % 3;
        libraryList = L.filterList(entries, filters[filterIndex].key, sortMode);
        libIndex = 0;
        api.memory.set("sortMode", sortMode);
    }

    // Triângulo: favoritar/desfavoritar o jogo selecionado (o Pegasus guarda os favoritos)
    function toggleFavorite() {
        if (!current || tab === 2) return;
        var g = current.game;
        g.favorite = !g.favorite;
        sfx(g.favorite ? sConfirm : sBack);
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
                if (!padNames[n]) { toast("Controle conectado: " + n); sfx(sPadOn); }
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

    function rebuildTrophies() {
        var list = [];
        var got = 0, total = 0;
        if (raIndex) {
            for (var i = 0; i < entries.length; i++) {
                var t = L.trophiesFor(raIndex, entries[i]);
                if (t) {
                    list.push({ entry: entries[i], got: t.got, total: t.total });
                    got += t.got;
                    total += t.total;
                }
            }
            list.sort(function (a, b) {
                var da = L.playedTime(a.entry), db = L.playedTime(b.entry);
                if (da !== db) return db - da;
                return a.entry.display < b.entry.display ? -1 : 1;
            });
        }
        trophyList = list;
        raGot = got;
        raTotal = total;
        trophyIndex = L.clampIndex(trophyIndex, list.length);
    }

    // conta do RetroAchievements: digitada no próprio app (aba Troféus) ou, se vazio, a do config.js
    function raUser() { return api.memory.has("raUser") ? String(api.memory.get("raUser")) : Cfg.RA_USER; }
    function raKey()  { return api.memory.has("raKey")  ? String(api.memory.get("raKey"))  : Cfg.RA_KEY; }
    function saveAccount(u, k) {
        api.memory.set("raUser", String(u).trim());
        api.memory.set("raKey", String(k).trim());
        accountOpen = false;
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

    function trophyInfo(entry) {
        if (!entry) return { kind: "none", text: "" };
        if (!L.hasTrophySupport(entry.sys)) return { kind: "none", text: "Sem troféus neste console" };
        if (raState === "off") return { kind: "none", text: "Conecte o RetroAchievements" };
        if (raState === "loading") return { kind: "none", text: "Carregando…" };
        if (raState === "error") return { kind: "none", text: "Sem conexão com o RetroAchievements" };
        var t = L.trophiesFor(raIndex, entry);
        if (!t) return { kind: "none", text: "Sem troféus para este jogo" };
        return { kind: "progress", got: t.got, total: t.total };
    }

    function launchCurrent() {
        if (!current) return;
        if (!current.emuOk) {
            showNotice("Falta o emulador", current.emuHint || ("Instale o " + current.emuName + " para jogar " + current.sysName + "."));
            return;
        }
        api.memory.set("tab", tab);
        api.memory.set("homeKey", current.key);
        if (tab === 1) {
            api.memory.set("libKey", current.key);
            api.memory.set("filterKey", filters[filterIndex].key);
        }
        sfx(sLaunch);
        launchGuardUntil = Date.now() + 2000;   // um X segurado não abre o jogo duas vezes
        current.game.launch();
    }

    function switchTab(t) {
        var next = (t + 3) % 3;
        if (next !== tab) sfx(next === 0 && t !== 3 ? sBack : sTab);
        tab = next;
        libOnFilters = false;
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
                if (!root.accountOpen) root.forceActiveFocus();
                if (!consoles.open) syncLibrary();
                refresh();
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
        if (api.keys.isPrevPage(event)) { event.accepted = true; switchTab(tab - 1); return; }
        if (api.keys.isNextPage(event)) { event.accepted = true; switchTab(tab + 1); return; }

        if (api.keys.isFilters(event)) { event.accepted = true; toggleFavorite(); return; }

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

        if (api.keys.isCancel(event)) { event.accepted = true; switchTab(0); return; }

        if (tab === 1) {
            if (api.keys.isDetails(event)) { event.accepted = true; setSort(sortMode + 1); return; }
            var cols = libraryGrid.columns;
            if (libOnFilters) {
                if (event.key === Qt.Key_Left)  { event.accepted = true; setFilter(filterIndex - 1); }
                else if (event.key === Qt.Key_Right) { event.accepted = true; setFilter(filterIndex + 1); }
                else if (event.key === Qt.Key_Down || api.keys.isAccept(event)) { event.accepted = true; libOnFilters = false; }
                else if (event.key === Qt.Key_Up) { event.accepted = true; }
                return;
            }
            if (event.key === Qt.Key_Left)  { event.accepted = true; libIndex = L.clampIndex(libIndex - 1, libraryList.length); }
            else if (event.key === Qt.Key_Right) { event.accepted = true; libIndex = L.clampIndex(libIndex + 1, libraryList.length); }
            else if (event.key === Qt.Key_Down)  { event.accepted = true; libIndex = L.clampIndex(libIndex + cols, libraryList.length); }
            else if (event.key === Qt.Key_Up) {
                event.accepted = true;
                if (libIndex < cols) libOnFilters = true;
                else libIndex = libIndex - cols;
            }
            else if (api.keys.isAccept(event)) { event.accepted = true; launchCurrent(); }
            return;
        }

        if (tab === 2) {
            if (event.key === Qt.Key_Up)   { event.accepted = true; trophyIndex = L.clampIndex(trophyIndex - 1, trophyList.length); }
            else if (event.key === Qt.Key_Down) { event.accepted = true; trophyIndex = L.clampIndex(trophyIndex + 1, trophyList.length); }
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) { event.accepted = true; }
            else if (api.keys.isAccept(event)) { event.accepted = true; launchCurrent(); }
        }
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
        color: "#07080a"
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
        Item {
            id: backdrop
            anchors.fill: parent

            readonly property color tint: root.current ? root.current.color : "#2a2d33"

            Rectangle {
                anchors.fill: parent
                color: Qt.darker(backdrop.tint, 4.2)
                Behavior on color { ColorAnimation { duration: 500 } }
            }

            RadialGradient {
                anchors.fill: parent
                horizontalOffset: width * 0.24
                verticalOffset: -height * 0.22
                horizontalRadius: width * 0.7
                verticalRadius: height * 0.8
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(backdrop.tint.r, backdrop.tint.g, backdrop.tint.b, 0.55) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // A arte é desfocada uma única vez por troca de jogo; os painéis por cima são só translúcidos.
            Image {
                id: bgImage
                anchors.fill: parent
                source: root.current ? (root.bgUseArt ? root.current.art : root.current.bg) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 480
                visible: false
                onStatusChanged: {
                    if (status === Image.Error && !root.bgUseArt) root.bgUseArt = true;
                }
            }
            FastBlur {
                anchors.fill: parent
                source: bgImage
                radius: 48
                opacity: bgImage.status === Image.Ready ? 0.55 : 0
                Behavior on opacity { NumberAnimation { duration: 450 } }
            }

            RadialGradient {
                anchors.fill: parent
                horizontalRadius: width * 0.75
                verticalRadius: height * 0.75
                gradient: Gradient {
                    GradientStop { position: 0.55; color: "transparent" }
                    GradientStop { position: 1.0; color: "#99050608" }
                }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * 0.56
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.55; color: "#8c050608" }
                    GradientStop { position: 1.0; color: "#e0050608" }
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
            height: 46
            width: tabRow.width + 8
            radius: height / 2

            LiquidPill {
                x: tabRow.x + (target ? target.x : 0)
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
                        width: tabLabel.implicitWidth + 40
                        height: 38

                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: index === root.tab ? "#ffffff" : "#9effffff"
                            font.family: "Roboto"
                            font.pixelSize: 15
                            font.weight: index === root.tab ? Font.Medium : Font.Normal
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.switchTab(index)
                        }
                    }
                }
            }
        }

        Text {
            anchors.left: tabBar.right
            anchors.leftMargin: 16
            anchors.verticalCenter: tabBar.verticalCenter
            text: "L1  ·  R1"
            color: "#59ffffff"
            font.family: "Roboto"
            font.pixelSize: 14
            font.letterSpacing: 1
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 56
            anchors.verticalCenter: tabBar.verticalCenter
            spacing: 18

            // controles conectados e bateria (só o que o Android informa)
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16
                visible: root.pads.length > 0
                Repeater {
                    model: root.pads.slice(0, 2)
                    delegate: Row {
                        spacing: 7
                        readonly property bool low: modelData.hasBattery && modelData.level <= 15 && !modelData.charging
                        Canvas {
                            width: 28; height: 18
                            anchors.verticalCenter: parent.verticalCenter
                            onPaint: {
                                var c = getContext("2d");
                                c.reset();
                                c.strokeStyle = "rgba(255,255,255,0.8)";
                                c.lineWidth = 1.6;
                                c.beginPath();
                                c.moveTo(7, 2); c.lineTo(21, 2);
                                c.bezierCurveTo(27, 2, 28, 14, 25, 16);
                                c.bezierCurveTo(22, 18, 19, 12, 17, 11);
                                c.lineTo(11, 11);
                                c.bezierCurveTo(9, 12, 6, 18, 3, 16);
                                c.bezierCurveTo(0, 14, 1, 2, 7, 2);
                                c.closePath();
                                c.stroke();
                            }
                        }
                        Item {
                            visible: modelData.hasBattery
                            width: 26; height: 13
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                width: 23; height: 13; radius: 3
                                color: "transparent"
                                border.width: 1.4
                                border.color: low ? "#ffb74d" : "#b3ffffff"
                                Rectangle {
                                    x: 2; y: 2
                                    height: parent.height - 4
                                    width: Math.max(1.5, (parent.width - 4) * Math.max(0, Math.min(100, modelData.level)) / 100)
                                    radius: 1.5
                                    color: low ? "#ffb74d" : (modelData.charging ? "#9be7a0" : "#e6ffffff")
                                }
                            }
                            Rectangle { x: 23.5; y: 4; width: 2.2; height: 5; radius: 1; color: "#b3ffffff" }
                        }
                        Text {
                            visible: modelData.hasBattery
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.level + "%" + (modelData.charging ? "  carregando" : "")
                            color: low ? "#ffb74d" : "#b3ffffff"
                            font.family: "Roboto"
                            font.pixelSize: 15
                        }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "P7  STATION"
                color: "#59ffffff"
                font.family: "Roboto"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 3
            }
            Rectangle { width: 1; height: 14; color: "#33ffffff"; anchors.verticalCenter: parent.verticalCenter }
            Text {
                id: clock
                anchors.verticalCenter: parent.verticalCenter
                color: "#b3ffffff"
                font.family: "Roboto"
                font.pixelSize: 18
                font.letterSpacing: 0.5
            }
            Glass {
                backdrop: glassSource
                stageItem: stage
                width: 46
                height: 46
                radius: 23
                border.width: root.gearFocused ? 2 : (liquid ? 0 : 1)
                border.color: root.gearFocused ? "#ffffff" : "#1cffffff"
                anchors.verticalCenter: parent.verticalCenter
                Canvas {
                    anchors.centerIn: parent
                    width: 22; height: 22
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = "rgba(255,255,255,0.9)";
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
                Canvas {
                    id: holdRing
                    anchors.fill: parent
                    visible: root.holdProgress > 0
                    property real p: root.holdProgress
                    onPChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = "rgba(255,255,255,0.95)";
                        ctx.lineWidth = 3;
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, width / 2 - 2, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * p);
                        ctx.stroke();
                    }
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
            visible: root.tab === 0
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }

            Text {
                x: 56
                y: 112
                text: root.recentsLabel.toUpperCase()
                color: "#80ffffff"
                font.family: "Roboto"
                font.pixelSize: 12
                font.weight: Font.Medium
                font.letterSpacing: 1.8
            }

            ListView {
                id: recentRow
                x: 56
                y: 142
                width: parent.width - 56
                height: 240
                orientation: ListView.Horizontal
                spacing: 16
                model: root.recents
                currentIndex: root.homeIndex
                highlightMoveDuration: 260
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: width * 0.55
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 600

                delegate: Item {
                    width: tileItem.width
                    height: 240

                    GameTile {
                        id: tileItem
                        entry: modelData
                        selected: index === root.homeIndex
                        pixelRatio: root.pixelRatio
                        onTapped: {
                            if (index === root.homeIndex) root.launchCurrent();
                            else root.homeIndex = index;
                        }
                    }
                    Text {
                        anchors.top: tileItem.bottom
                        anchors.topMargin: 14
                        width: 320
                        text: modelData.display
                        visible: index === root.homeIndex
                        color: "#ebffffff"
                        font.family: "Roboto"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                }
            }

            Showcase {
                x: 760
                y: 250
                width: 620
                height: 430
                entry: root.current
                visible: root.current !== null
                active: !root.settingsOpen && !root.accountOpen && !consoles.open
                        && Qt.application.state === Qt.ApplicationActive
            }

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

                    Text { text: "Bem-vindo ao P7 Station"; color: "#ffffff"; font.family: "Roboto"; font.weight: Font.Light; font.pixelSize: 40; font.letterSpacing: -0.8 }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        color: "#c7ffffff"; font.family: "Roboto"; font.pixelSize: 17; lineHeight: 1.35
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
                                Text { anchors.centerIn: parent; text: index + 1; color: "#ffffff"; font.family: "Roboto"; font.pixelSize: 14; font.weight: Font.Medium }
                            }
                            Text {
                                width: parent.width - 46
                                anchors.verticalCenter: parent.verticalCenter
                                wrapMode: Text.WordWrap
                                text: modelData
                                color: "#e6ffffff"; font.family: "Roboto"; font.pixelSize: 16; lineHeight: 1.3
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
            visible: root.tab === 1
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }

            Glass {
                id: filterBar
                backdrop: glassSource
                stageItem: stage
                x: 56
                y: 104
                height: 44
                width: filterRow.width + 8
                radius: 22
                border.width: root.libOnFilters ? 2 : (liquid ? 0 : 1)
                border.color: root.libOnFilters ? "#b3ffffff" : "#1cffffff"

                LiquidPill {
                    x: filterRow.x + (target ? target.x : 0)
                    light: true
                    target: filterRepeater.added >= 0 && filterRepeater.count > root.filterIndex ? filterRepeater.itemAt(root.filterIndex) : null
                }

                Row {
                    id: filterRow
                    anchors.centerIn: parent
                    spacing: 2

                    Repeater {
                        id: filterRepeater
                        property int added: 0   // força a bolha a achar o item quando ele acaba de ser criado
                        onItemAdded: added++
                        model: root.filters
                        delegate: Item {
                            readonly property bool active: index === root.filterIndex
                            width: chipContent.width + 30
                            height: 36

                            Row {
                                id: chipContent
                                anchors.centerIn: parent
                                spacing: 7
                                Text {
                                    text: modelData.label
                                    color: active ? "#0b0c0f" : "#c7ffffff"
                                    font.family: "Roboto"
                                    font.pixelSize: 14
                                    font.weight: active ? Font.DemiBold : Font.Normal
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                Text {
                                    anchors.baseline: parent.children[0].baseline
                                    text: modelData.count
                                    color: active ? "#8c0b0c0f" : "#6bffffff"
                                    font.family: "Roboto"
                                    font.pixelSize: 12
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { root.libOnFilters = false; root.setFilter(index); }
                            }
                        }
                    }
                }
            }

            Glass {
                id: sortBar
                backdrop: glassSource
                stageItem: stage
                anchors.right: parent.right
                anchors.rightMargin: 56
                y: 104
                height: 44
                width: sortRow.width + 8
                radius: 22

                LiquidPill {
                    x: sortRow.x + (target ? target.x : 0)
                    target: sortRepeater.added >= 0 && sortRepeater.count > root.sortMode ? sortRepeater.itemAt(root.sortMode) : null
                }
                Row {
                    id: sortRow
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                        id: sortRepeater
                        property int added: 0   // força a bolha a achar o item quando ele acaba de ser criado
                        onItemAdded: added++
                        model: L.SORTS
                        delegate: Item {
                            width: sortLabel.implicitWidth + 30
                            height: 36
                            Text {
                                id: sortLabel
                                anchors.centerIn: parent
                                text: modelData
                                color: index === root.sortMode ? "#ffffff" : "#a6ffffff"
                                font.family: "Roboto"
                                font.pixelSize: 14
                                font.weight: index === root.sortMode ? Font.Medium : Font.Normal
                            }
                            MouseArea { anchors.fill: parent; onClicked: if (index !== root.sortMode) root.setSort(index) }
                        }
                    }
                }
            }

            Text {
                x: 56
                y: 166
                text: (root.filters.length > root.filterIndex ? root.filters[root.filterIndex].name : "")
                      + "  ·  " + root.libraryList.length + (root.libraryList.length === 1 ? " jogo" : " jogos")
                      + "  ·  " + L.SORTS[root.sortMode]
                color: "#80ffffff"
                font.family: "Roboto"
                font.pixelSize: 12
                font.weight: Font.Medium
                font.letterSpacing: 1.8
                font.capitalization: Font.AllUppercase
            }

            GridView {
                id: libraryGrid
                readonly property int columns: Math.max(1, Math.floor(width / cellWidth))
                x: 56
                y: 190
                width: parent.width - 112
                height: parent.height - y - 262
                cellWidth: 166
                cellHeight: 196
                clip: true
                model: root.libraryList
                currentIndex: root.libIndex
                highlightMoveDuration: 200
                highlightRangeMode: GridView.ApplyRange
                preferredHighlightBegin: cellHeight * 0.3
                preferredHighlightEnd: height - cellHeight * 1.3
                cacheBuffer: 800

                delegate: Item {
                    width: 166
                    height: 196

                    GameTile {
                        id: libTile
                        x: 8
                        y: 8
                        entry: modelData
                        baseSize: 140
                        selectedSize: 140
                        selected: index === root.libIndex && !root.libOnFilters
                        pixelRatio: root.pixelRatio
                        scale: selected ? 1.06 : 1.0
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        onTapped: {
                            root.libOnFilters = false;
                            if (index === root.libIndex) root.launchCurrent();
                            else root.libIndex = index;
                        }
                    }
                    Text {
                        anchors.top: libTile.bottom
                        anchors.topMargin: 12
                        x: 8
                        width: 140
                        text: modelData.display
                        color: libTile.selected ? "#f2ffffff" : "#8cffffff"
                        font.family: "Roboto"
                        font.pixelSize: 13
                        font.weight: libTile.selected ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                    }
                }
            }

        }

        // ============================================== ABA: TROFÉUS
        Item {
            id: trophyView
            anchors.fill: parent
            visible: root.tab === 2
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }

            Glass {
                backdrop: glassSource
                stageItem: stage
                id: trophySummary
                x: 56
                y: 108
                width: 520
                height: 96
                visible: root.raState === "ok"

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 26
                    spacing: 40

                    Column {
                        spacing: 6
                        Text { text: "CONQUISTADOS"; color: "#80ffffff"; font.family: "Roboto"; font.pixelSize: 12; font.weight: Font.Medium; font.letterSpacing: 1.4 }
                        Text { text: root.raGot + "  /  " + root.raTotal; color: "#ffffff"; font.family: "Roboto"; font.pixelSize: 26; font.weight: Font.Light }
                    }
                    Column {
                        spacing: 6
                        Text { text: "JOGOS COM TROFÉUS"; color: "#80ffffff"; font.family: "Roboto"; font.pixelSize: 12; font.weight: Font.Medium; font.letterSpacing: 1.4 }
                        Text { text: root.trophyList.length; color: "#ffffff"; font.family: "Roboto"; font.pixelSize: 26; font.weight: Font.Light }
                    }
                }
            }

            Rectangle {
                id: accountButton
                anchors.right: parent.right
                anchors.rightMargin: 56
                y: 108
                width: accountLabel.implicitWidth + 40
                height: 40
                radius: 20
                color: root.raState === "off" ? "#ebffffff" : "#14ffffff"
                border.width: 1
                border.color: "#26ffffff"
                Text {
                    id: accountLabel
                    anchors.centerIn: parent
                    text: root.raState === "off" ? "Conectar conta" : "Conta: " + root.raUser()
                    color: root.raState === "off" ? "#0b0c0f" : "#d9ffffff"
                    font.family: "Roboto"; font.pixelSize: 14
                    font.weight: root.raState === "off" ? Font.DemiBold : Font.Normal
                }
                MouseArea { anchors.fill: parent; onClicked: root.accountOpen = true }
            }

            Text {
                x: 56
                y: 120
                width: 760
                visible: root.raState !== "ok"
                wrapMode: Text.WordWrap
                color: "#c7ffffff"
                font.family: "Roboto"
                font.pixelSize: 18
                lineHeight: 1.35
                text: root.raState === "loading" ? "Carregando seus troféus…"
                    : root.raState === "error" ? "Não foi possível falar com o RetroAchievements. Confira a internet e, em Conta, o usuário e a chave."
                    : "Troféus desligados. Toque em Conectar conta e entre com seu usuário e sua chave do RetroAchievements."
            }

            Text {
                x: 56
                y: 230
                visible: root.raState === "ok" && root.trophyList.length === 0
                text: "Nenhum jogo da sua biblioteca tem troféus ainda. Jogue um de SNES, PS1 ou PS2 pelo hub."
                color: "#b3ffffff"
                font.family: "Roboto"
                font.pixelSize: 16
            }

            ListView {
                id: trophyListView
                x: 56
                y: 228
                width: 760
                height: parent.height - y - 230
                clip: true
                spacing: 8
                model: root.trophyList
                currentIndex: root.trophyIndex
                highlightMoveDuration: 200
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: height - 90

                delegate: Rectangle {
                    readonly property bool isSel: index === root.trophyIndex
                    width: 760
                    height: 80
                    radius: 18
                    color: isSel ? "#1fffffff" : "transparent"
                    border.width: isSel ? 1 : 0
                    border.color: "#33ffffff"

                    GameTile {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        entry: modelData.entry
                        baseSize: 58
                        selectedSize: 58
                        selected: true
                        pixelRatio: root.pixelRatio
                        onTapped: {
                            if (index === root.trophyIndex) root.launchCurrent();
                            else root.trophyIndex = index;
                        }
                    }
                    Column {
                        x: 86
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text {
                            width: 440
                            text: modelData.entry.display
                            color: "#f2ffffff"
                            font.family: "Roboto"
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.entry.sysName
                            color: "#80ffffff"
                            font.family: "Roboto"
                            font.pixelSize: 13
                        }
                    }
                    Column {
                        anchors.right: parent.right
                        anchors.rightMargin: 22
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Text {
                            anchors.right: parent.right
                            text: modelData.got + " / " + modelData.total
                            color: "#ebffffff"
                            font.family: "Roboto"
                            font.pixelSize: 16
                            font.weight: Font.Light
                        }
                        Rectangle {
                            width: 180
                            height: 3
                            radius: 2
                            color: "#1fffffff"
                            Rectangle {
                                height: parent.height
                                radius: 2
                                width: parent.width * (modelData.total > 0 ? modelData.got / modelData.total : 0)
                                color: "#ccffffff"
                            }
                        }
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        z: -1
                        onClicked: {
                            if (index === root.trophyIndex) root.launchCurrent();
                            else root.trophyIndex = index;
                        }
                    }
                }
            }
        }

        // ============================== DETALHES DO JOGO SELECIONADO
        // Início: grande, embaixo. Biblioteca e Troféus: coluna à direita.
        Item {
            id: details
            visible: root.current !== null && (root.tab === 0 || root.tab === 1 || root.trophyList.length > 0)
            x: root.tab === 0 ? 56 : (root.tab === 1 ? 56 : 860)
            width: root.tab === 2 ? stage.width - 860 - 56 : stage.width - 112
            height: root.tab === 2 ? 420 : 200
            y: root.tab === 2 ? 228 : stage.height - height - 96

            readonly property var tinfo: root.trophyInfo(root.current)
            readonly property bool compact: root.tab !== 0

            Column {
                id: infoCol
                // posição explícita por aba (âncoras trocadas em tempo real deixavam o layout preso)
                x: 0
                y: root.tab === 2 ? 0 : details.height - height
                width: root.tab === 2 ? parent.width : (root.tab === 0 ? 680 : parent.width - statsPanel.width - 48)
                spacing: 12

                Text {
                    text: root.current ? (root.current.sysName + "  ·  " + L.formatLastPlayed(root.current.lastPlayed)).toUpperCase() : ""
                    color: "#8cffffff"
                    font.family: "Roboto"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.letterSpacing: 1.8
                }
                Text {
                    width: parent.width
                    text: root.current ? root.current.display : ""
                    color: "#ffffff"
                    font.family: "Roboto"
                    font.weight: Font.Light
                    font.pixelSize: details.compact ? 34 : 58
                    font.letterSpacing: details.compact ? -0.5 : -1.4
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    lineHeight: 1.04
                }
                Text {
                    visible: root.current !== null && !root.current.emuOk
                    text: root.current ? "Falta instalar o " + root.current.emuName + " neste tablet" : ""
                    color: "#ffcc80"
                    font.family: "Roboto"
                    font.pixelSize: 17
                }
                Item { width: 1; height: details.compact ? 4 : 10 }
                Row {
                    spacing: 12

                    Rectangle {
                        id: playButton
                        width: playRow.implicitWidth + 60
                        height: details.compact ? 48 : 54
                        radius: height / 2
                        color: "#ebffffff"

                        Row {
                            id: playRow
                            anchors.centerIn: parent
                            spacing: 10
                            Canvas {
                                width: 14
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.fillStyle = "#0b0c0f";
                                    ctx.beginPath();
                                    ctx.moveTo(1, 1);
                                    ctx.lineTo(13, 8);
                                    ctx.lineTo(1, 15);
                                    ctx.closePath();
                                    ctx.fill();
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.current && !root.current.emuOk ? "Como jogar"
                                    : (root.current && L.playedTime(root.current) > 0 ? "Continuar" : "Jogar")
                                color: "#0b0c0f"
                                font.family: "Roboto"
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.launchCurrent()
                        }
                    }
                }
            }

            Glass {
                backdrop: glassSource
                stageItem: stage
                id: statsPanel
                x: details.width - width
                y: root.tab === 2 ? infoCol.height + 28 : details.height - height
                width: root.tab === 2 ? parent.width : 420
                height: 96
                visible: root.current !== null

                Row {
                    anchors.fill: parent

                    Item {
                        width: 180
                        height: parent.height
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 26
                            spacing: 8
                            Text { text: "TEMPO JOGADO"; color: "#80ffffff"; font.family: "Roboto"; font.pixelSize: 12; font.weight: Font.Medium; font.letterSpacing: 1.4 }
                            Text {
                                text: root.current ? L.formatPlayTime(root.current.playTime) : ""
                                color: "#ffffff"
                                font.family: "Roboto"
                                font.pixelSize: 24
                                font.weight: Font.Light
                            }
                        }
                    }
                    Rectangle {
                        width: 1
                        height: parent.height - 36
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#1fffffff"
                    }
                    Item {
                        width: statsPanel.width - 181
                        height: parent.height
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 26
                            width: parent.width - 52
                            spacing: 8
                            Text { text: "TROFÉUS"; color: "#80ffffff"; font.family: "Roboto"; font.pixelSize: 12; font.weight: Font.Medium; font.letterSpacing: 1.4 }
                            Text {
                                visible: details.tinfo.kind === "progress"
                                text: details.tinfo.kind === "progress" ? details.tinfo.got + "  /  " + details.tinfo.total : ""
                                color: "#ffffff"
                                font.family: "Roboto"
                                font.pixelSize: 24
                                font.weight: Font.Light
                            }
                            Rectangle {
                                visible: details.tinfo.kind === "progress"
                                width: parent.width
                                height: 3
                                radius: 2
                                color: "#1fffffff"
                                Rectangle {
                                    height: parent.height
                                    radius: 2
                                    color: "#ccffffff"
                                    width: details.tinfo.kind === "progress" && details.tinfo.total > 0 ? parent.width * details.tinfo.got / details.tinfo.total : 0
                                    Behavior on width { NumberAnimation { duration: 400 } }
                                }
                            }
                            Text {
                                visible: details.tinfo.kind !== "progress"
                                width: parent.width
                                text: details.tinfo.text || ""
                                color: "#a6ffffff"
                                font.family: "Roboto"
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
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
                y: 96
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

                    Text { text: "Configurações"; leftPadding: 12; bottomPadding: 12; color: "#ffffff"; font.family: "Roboto"; font.weight: Font.Light; font.pixelSize: 30 }

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
                                Text { text: modelData.title; color: "#f2ffffff"; font.family: "Roboto"; font.pixelSize: 17 }
                                Text { visible: modelData.detail !== ""; text: modelData.detail; color: "#8cffffff"; font.family: "Roboto"; font.pixelSize: 13 }
                            }
                            // chave liga/desliga dos sons
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
                        color: "#73ffffff"; font.family: "Roboto"; font.pixelSize: 13; lineHeight: 1.35
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

                    Text { text: "RetroAchievements"; color: "#ffffff"; font.family: "Roboto"; font.weight: Font.Light; font.pixelSize: 30 }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Crie a conta grátis em retroachievements.org. A chave fica em Settings › Web API Key."
                        color: "#b3ffffff"; font.family: "Roboto"; font.pixelSize: 15; lineHeight: 1.3
                    }
                    Text { text: "USUÁRIO"; color: "#80ffffff"; font.family: "Roboto"; font.pixelSize: 12; font.weight: Font.Medium; font.letterSpacing: 1.4 }
                    Rectangle {
                        width: parent.width; height: 48; radius: 14
                        color: "#14ffffff"; border.width: 1; border.color: userField.activeFocus ? "#99ffffff" : "#26ffffff"
                        TextInput {
                            id: userField
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#ffffff"; font.family: "Roboto"; font.pixelSize: 17
                            selectByMouse: true
                            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                            text: root.accountOpen ? root.raUser() : ""
                            KeyNavigation.tab: keyField
                        }
                    }
                    Text { text: "WEB API KEY"; color: "#80ffffff"; font.family: "Roboto"; font.pixelSize: 12; font.weight: Font.Medium; font.letterSpacing: 1.4 }
                    Rectangle {
                        width: parent.width; height: 48; radius: 14
                        color: "#14ffffff"; border.width: 1; border.color: keyField.activeFocus ? "#99ffffff" : "#26ffffff"
                        TextInput {
                            id: keyField
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#ffffff"; font.family: "Roboto"; font.pixelSize: 17
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
                            Text { anchors.centerIn: parent; text: "Salvar"; color: "#0b0c0f"; font.family: "Roboto"; font.pixelSize: 16; font.weight: Font.DemiBold }
                            MouseArea { anchors.fill: parent; onClicked: root.saveAccount(userField.text, keyField.text) }
                        }
                        Rectangle {
                            width: 140; height: 48; radius: 24; color: "#14ffffff"; border.width: 1; border.color: "#26ffffff"
                            Text { anchors.centerIn: parent; text: "Cancelar"; color: "#e6ffffff"; font.family: "Roboto"; font.pixelSize: 16 }
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
                    Text { text: root.noticeTitle; color: "#ffffff"; font.family: "Roboto"; font.weight: Font.Light; font.pixelSize: 32 }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: root.noticeText
                        color: "#e6ffffff"; font.family: "Roboto"; font.pixelSize: 19; lineHeight: 1.35
                    }
                    Item { width: 1; height: 4 }
                    Rectangle {
                        width: 180; height: 52; radius: 26; color: "#ebffffff"
                        Text { anchors.centerIn: parent; text: "Entendi"; color: "#0b0c0f"; font.family: "Roboto"; font.pixelSize: 18; font.weight: Font.DemiBold }
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
            anchors.bottomMargin: 34
            spacing: 26

            Repeater {
                model: {
                    var favLabel = root.current && root.current.fav ? "Desfavoritar" : "Favoritar";
                    if (root.tab === 0)
                        return [ { glyph: "cross", label: "Jogar" }, { glyph: "triangle", label: favLabel }, { glyph: "lr", label: "Trocar aba" } ];
                    if (root.tab === 1)
                        return [ { glyph: "cross", label: root.libOnFilters ? "Escolher" : "Jogar" }, { glyph: "triangle", label: favLabel },
                                 { glyph: "square", label: "Ordenar" }, { glyph: "circle", label: "Voltar" }, { glyph: "lr", label: "Trocar aba" } ];
                    return [ { glyph: "cross", label: "Jogar" }, { glyph: "circle", label: "Voltar" }, { glyph: "lr", label: "Trocar aba" } ];
                }
                delegate: Row {
                    spacing: 8
                    Canvas {
                        width: 22
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.glyph !== "lr"
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.scale(22 / 18, 22 / 18);
                            ctx.strokeStyle = "rgba(255,255,255,0.55)";
                            ctx.lineWidth = 1.3;
                            ctx.beginPath();
                            ctx.arc(9, 9, 8, 0, Math.PI * 2);
                            ctx.stroke();
                            ctx.beginPath();
                            if (modelData.glyph === "cross") {
                                ctx.moveTo(6, 6); ctx.lineTo(12, 12);
                                ctx.moveTo(12, 6); ctx.lineTo(6, 12);
                            } else if (modelData.glyph === "triangle") {
                                ctx.moveTo(9, 5.2); ctx.lineTo(12.9, 12); ctx.lineTo(5.1, 12); ctx.closePath();
                            } else if (modelData.glyph === "square") {
                                ctx.rect(5.6, 5.6, 6.8, 6.8);
                            } else {
                                ctx.arc(9, 9, 3.6, 0, Math.PI * 2);
                            }
                            ctx.stroke();
                        }
                    }
                    Text {
                        visible: modelData.glyph === "lr"
                        anchors.verticalCenter: parent.verticalCenter
                        text: "L1 R1"
                        color: "#8cffffff"
                        font.family: "Roboto"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: "#99ffffff"
                        font.family: "Roboto"
                        font.pixelSize: 16
                    }
                }
            }
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
            height: 52
            radius: 26
            tint: "#40101018"
            Text {
                id: toastLabel
                anchors.centerIn: parent
                text: root.toastShown
                color: "#ffffff"
                font.family: "Roboto"
                font.pixelSize: 18
            }
        }
            // ---------------------------------------------------- abertura
        Item {
            id: intro
            anchors.fill: parent
            visible: root.introOn
            property real glow: 0
            property real logo: 0
            property real word: 0
            property real fade: 1

            Rectangle { anchors.fill: parent; color: "#050410"; opacity: intro.fade }
            RadialGradient {
                anchors.fill: parent
                opacity: intro.glow * intro.fade
                horizontalRadius: parent.width * (0.25 + 0.35 * intro.glow)
                verticalRadius: horizontalRadius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#5a3cff" }
                    GradientStop { position: 0.45; color: "#1f1660" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Image {
                id: introLogo
                source: "p7-icon.png"
                width: 200; height: 200
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -40
                smooth: true
                mipmap: true
                opacity: intro.logo * intro.fade
                scale: 0.86 + 0.14 * intro.logo
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: introLogo.bottom
                anchors.topMargin: 34
                text: "P7  STATION"
                color: "#ffffff"
                font.family: "Roboto"
                font.pixelSize: 26
                font.weight: Font.Light
                font.letterSpacing: 4 + 10 * intro.word
                opacity: intro.word * intro.fade
            }
            MouseArea { anchors.fill: parent; onClicked: root.skipIntro() }

            SequentialAnimation {
                id: introAnim
                PropertyAction { target: intro; property: "fade"; value: 1 }
                ParallelAnimation {
                    NumberAnimation { target: intro; property: "glow"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
                    SequentialAnimation {
                        PauseAnimation { duration: 250 }
                        NumberAnimation { target: intro; property: "logo"; from: 0; to: 1; duration: 650; easing.type: Easing.OutBack }
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 550 }
                        NumberAnimation { target: intro; property: "word"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
                    }
                }
                PauseAnimation { duration: 450 }
                ScriptAction { script: introOutAnim.restart() }
            }
            SequentialAnimation {
                id: introOutAnim
                NumberAnimation { target: intro; property: "fade"; to: 0; duration: 420; easing.type: Easing.InOutQuad }
                ScriptAction { script: { root.introOn = false; intro.glow = 0; intro.logo = 0; intro.word = 0; intro.fade = 1; } }
            }
        }
    }
}
