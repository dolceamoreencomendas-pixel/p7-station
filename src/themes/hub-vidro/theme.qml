import QtQuick 2.15
import QtGraphicalEffects 1.12
import QtMultimedia 5.8
import "logic.js" as L
import "config.js" as Cfg

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
    property bool soundOn: true

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

    // --------------------------------------------------------------- sons
    // Sons próprios do P7 Station (sintetizados, sem amostras de terceiros).
    property bool quiet: true           // sem som durante o carregamento e as atualizações
    SoundEffect { id: sMove;    source: "sounds/move.wav";    volume: 0.55 }
    SoundEffect { id: sTab;     source: "sounds/tab.wav";     volume: 0.6 }
    SoundEffect { id: sConfirm; source: "sounds/confirm.wav"; volume: 0.6 }
    SoundEffect { id: sBack;    source: "sounds/back.wav";    volume: 0.6 }
    SoundEffect { id: sLaunch;  source: "sounds/launch.wav";  volume: 0.7 }
    function sfx(s) { if (!quiet && soundOn) s.play(); }
    onHomeIndexChanged: sfx(sMove)
    onLibIndexChanged: sfx(sMove)
    onTrophyIndexChanged: sfx(sMove)
    onFilterIndexChanged: sfx(sMove)
    onLibOnFiltersChanged: sfx(sMove)
    onAccountOpenChanged: sfx(accountOpen ? sConfirm : sBack)
    onSettingsOpenChanged: sfx(settingsOpen ? sConfirm : sBack)
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
        return {
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

    function setSound(on) {
        soundOn = on;
        api.memory.set("soundOn", on);
        if (on) sConfirm.play();
    }

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
        api.memory.set("tab", tab);
        api.memory.set("homeKey", current.key);
        if (tab === 1) {
            api.memory.set("libKey", current.key);
            api.memory.set("filterKey", filters[filterIndex].key);
        }
        if (soundOn) sLaunch.play();
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
        if (api.memory.has("soundOn")) soundOn = api.memory.get("soundOn");
        refresh();
        loadAchievements();
        unquiet.start();
    }

    // Ao voltar de um jogo, atualiza recentes e tempo jogado; troféus a cada volta também.
    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive) {
                refresh();
                loadAchievements();
            }
        }
    }

    // ------------------------------------------------------------ controle
    Keys.onPressed: {
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
                else if (api.keys.isAccept(event)) { event.accepted = true; gearFocused = false; settingsOpen = true; settingsIndex = 0; }
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Up) { event.accepted = true; }
                return;
            }
            if (event.key === Qt.Key_Left)  { event.accepted = true; homeIndex = L.clampIndex(homeIndex - 1, recents.length); }
            else if (event.key === Qt.Key_Right) { event.accepted = true; homeIndex = L.clampIndex(homeIndex + 1, recents.length); }
            else if (event.key === Qt.Key_Up) { event.accepted = true; gearFocused = true; }
            else if (event.key === Qt.Key_Down) { event.accepted = true; }
            else if (api.keys.isAccept(event)) { event.accepted = true; launchCurrent(); }
            // Círculo no Início não faz nada (o menu do sistema fica no botão Options)
            else if (api.keys.isCancel(event)) { event.accepted = true; }
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
    readonly property int settingsCount: 4
    function settingsActivate(i) {
        if (i === 0) { settingsOpen = false; accountOpen = true; }
        else if (i === 1) setSound(!soundOn);
        else if (i === 2) { settingsOpen = false; Internal.settings.reloadProviders(); }
        else if (i === 3) settingsOpen = false;
    }
    function handleSettingsKey(event) {
        if (api.keys.isCancel(event)) { event.accepted = true; settingsOpen = false; return; }
        if (event.key === Qt.Key_Up)   { event.accepted = true; settingsIndex = L.clampIndex(settingsIndex - 1, settingsCount); sfx(sMove); return; }
        if (event.key === Qt.Key_Down) { event.accepted = true; settingsIndex = L.clampIndex(settingsIndex + 1, settingsCount); sfx(sMove); return; }
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
            font.pixelSize: 12
            font.letterSpacing: 1
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 56
            anchors.verticalCenter: tabBar.verticalCenter
            spacing: 18

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
                font.pixelSize: 15
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
                MouseArea { anchors.fill: parent; onClicked: { root.gearFocused = false; root.settingsIndex = 0; root.settingsOpen = true; } }
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
                        text: "A pasta Jogos já foi criada no armazenamento interno do tablet. Para começar:"
                    }
                    Repeater {
                        model: [
                            "Coloque cada jogo na pasta do console: Jogos › snes, psx, ps2, wiiu ou switch. Não renomeie os arquivos: a capa vem pelo nome.",
                            "Instale os emuladores: RetroArch (site, versão AArch64), NetherSX2, Cemu e Eden.",
                            "No NetherSX2, no Cemu e no Eden, adicione a pasta do console e toque em Permitir.",
                            "Feche e abra o P7 Station. Seus jogos aparecem aqui."
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
                                text: root.current && L.playedTime(root.current) > 0 ? "Continuar" : "Jogar"
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
                            { title: "Conta do RetroAchievements", detail: root.raState === "off" ? "Não conectada" : root.raUser() },
                            { title: "Sons", detail: root.soundOn ? "Ligados" : "Desligados" },
                            { title: "Atualizar biblioteca", detail: "Procura jogos novos na pasta Jogos" },
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
                                visible: index === 1
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                width: 52; height: 30; radius: 15
                                color: root.soundOn ? "#e6ffffff" : "#26ffffff"
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Rectangle {
                                    width: 24; height: 24; radius: 12
                                    y: 3
                                    x: root.soundOn ? 25 : 3
                                    color: root.soundOn ? "#0b0c0f" : "#ffffff"
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
                        text: "Jogos: armazenamento interno › Jogos (snes, psx, ps2, wiiu, switch).\nPara abrir o P7 Station ao ligar o tablet: Configurações do Android › Apps › Apps padrão › Tela inicial.\nMenu do sistema: botão Options do controle."
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
                        width: 18
                        height: 18
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.glyph !== "lr"
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
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
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: "#80ffffff"
                        font.family: "Roboto"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
