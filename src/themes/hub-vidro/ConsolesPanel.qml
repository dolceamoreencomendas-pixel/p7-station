import QtQuick 2.15
import "emulators.js" as EM

// Consoles e emuladores: onde estão os jogos de cada console e qual emulador abre cada um.
// Três telas: lista de consoles · detalhes de um console · navegador de pastas.
Item {
    id: panel

    property var host: null            // o tema (dados e sons)
    property var backdrop: null
    property var stageItem: null

    property bool open: false
    property string mode: "list"        // list · detail · browser
    property int listIndex: 0
    property int detailIndex: 0
    property string detailKey: ""
    property int browserIndex: 0
    property string browserPath: ""
    property string browserTarget: ""   // chave do console ou "*" (pasta principal)
    property var browserDirs: []
    property var counts: ({})
    property int version: 0             // muda a cada alteração, para atualizar os textos

    signal finished()

    visible: open
    anchors.fill: parent

    // ------------------------------------------------------------ dados
    readonly property string storage: host ? host.p7Storage : ""
    function shortPath(p) {
        if (!p) return "";
        var s = String(p);
        if (storage && s.indexOf(storage) === 0) s = s.substring(storage.length);
        s = s.replace(/^\/+/, "");
        return s.length ? s.split("/").join("  ›  ") : "Armazenamento interno";
    }

    function rowsList() {
        void version;
        if (!host) return [];
        return EM.SYSTEMS.map(function (s) {
            var folder = host.p7Folders[s.key] || "";
            var off = host.p7Overrides[s.key] === "-";
            var emu = EM.effectiveEmu(s, host.p7Emus[s.key], host.p7Installed);
            var ok = EM.isInstalled(emu, host.p7Installed);
            var status = off ? "Desligado" : (!folder ? "Sem pasta" : (ok ? "Pronto" : "Falta o emulador"));
            return { sys: s, folder: folder, off: off, emu: emu, ok: ok, status: status,
                     count: folder ? (counts[s.key] || 0) : 0 };
        });
    }
    readonly property var rows: rowsList()
    readonly property int listCount: rows.length + 2      // pasta principal + consoles + Pronto

    function detailRow() {
        for (var i = 0; i < rows.length; i++) if (rows[i].sys.key === detailKey) return rows[i];
        return null;
    }
    readonly property var detail: { void version; return mode === "detail" ? detailRow() : null; }

    function show() {
        refreshCounts();
        mode = "list";
        listIndex = 0;
        open = true;
    }
    function close() {
        open = false;
        finished();
    }
    function refreshCounts() {
        if (!host) return;
        var c = {};
        EM.SYSTEMS.forEach(function (s) {
            var f = host.p7Folders[s.key];
            c[s.key] = f ? P7.countFiles(f, s.exts) : 0;
        });
        counts = c;
        version++;
    }
    function changed() {
        host.p7Save();
        host.p7Detect();
        refreshCounts();
    }

    // ------------------------------------------------------------ ações
    function activateList(i) {
        if (i === 0) { openBrowser("*", host.p7Root || storage); return; }
        if (i === listCount - 1) { close(); return; }
        detailKey = rows[i - 1].sys.key;
        detailIndex = 0;
        mode = "detail";
        host.playConfirm();
    }

    function cycleEmu(step) {
        var sys = EM.byKey(detailKey);
        var cur = EM.effectiveEmu(sys, host.p7Emus[detailKey], host.p7Installed);
        var i = sys.emus.indexOf(cur);
        var next = sys.emus[(i + step + sys.emus.length) % sys.emus.length];
        var e = Object.assign({}, host.p7Emus);
        e[detailKey] = next.id;
        host.p7Emus = e;
        host.playMove();
        changed();
    }
    function setOverride(key, value) {
        var o = Object.assign({}, host.p7Overrides);
        if (value === "") delete o[key]; else o[key] = value;
        host.p7Overrides = o;
        changed();
    }

    function activateDetail(i) {
        var d = detailRow();
        if (i === 0) { openBrowser(detailKey, d.folder || host.p7Root || storage); return; }
        if (i === 1) { cycleEmu(1); return; }
        if (i === 2) { setOverride(detailKey, d.off ? "" : "-"); host.playConfirm(); return; }
        if (i === 3) { setOverride(detailKey, ""); host.playConfirm(); return; }
        mode = "list"; host.playBack();
    }

    function openBrowser(target, start) {
        browserTarget = target;
        var p = start && P7.isDir(start) ? start : storage;
        enterDir(p);
        mode = "browser";
        host.playConfirm();
    }
    function enterDir(p) {
        browserPath = p;
        browserDirs = P7.subdirs(p);
        browserIndex = 0;
    }
    readonly property bool browserAtTop: browserPath === storage || browserPath === "/" || browserPath === ""
    function parentOf(p) { var s = String(p).replace(/\/+$/, ""); var i = s.lastIndexOf("/"); return i > 0 ? s.substring(0, i) : "/"; }
    readonly property var browserRows: {
        var r = [{ kind: "use", label: browserTarget === "*" ? "Usar esta pasta para procurar os consoles" : "Usar esta pasta" }];
        if (!browserAtTop) r.push({ kind: "up", label: "Voltar uma pasta" });
        browserDirs.forEach(function (d) { r.push({ kind: "dir", label: d }); });
        return r;
    }
    function activateBrowser(i) {
        var r = browserRows[i];
        if (!r) return;
        if (r.kind === "use") {
            if (browserTarget === "*") {
                host.p7Root = browserPath === storage ? "" : browserPath;
                changed();
                mode = "list";
            } else {
                setOverride(browserTarget, browserPath);
                mode = "detail";
            }
            host.playConfirm();
            return;
        }
        if (r.kind === "up") { enterDir(parentOf(browserPath)); host.playBack(); return; }
        enterDir(browserPath.replace(/\/+$/, "") + "/" + r.label);
        host.playMove();
    }

    // ------------------------------------------------------------ controle
    function handleKey(event) {
        var k = event.key;
        event.accepted = true;
        if (mode === "list") {
            if (api.keys.isCancel(event)) { close(); return; }
            if (k === Qt.Key_Up)   { listIndex = Math.max(0, listIndex - 1); host.playMove(); }
            else if (k === Qt.Key_Down) { listIndex = Math.min(listCount - 1, listIndex + 1); host.playMove(); }
            else if (api.keys.isAccept(event)) activateList(listIndex);
            return;
        }
        if (mode === "detail") {
            if (api.keys.isCancel(event)) { mode = "list"; host.playBack(); return; }
            if (k === Qt.Key_Up)   { detailIndex = Math.max(0, detailIndex - 1); host.playMove(); }
            else if (k === Qt.Key_Down) { detailIndex = Math.min(4, detailIndex + 1); host.playMove(); }
            else if (detailIndex === 1 && k === Qt.Key_Left)  cycleEmu(-1);
            else if (detailIndex === 1 && k === Qt.Key_Right) cycleEmu(1);
            else if (api.keys.isAccept(event)) activateDetail(detailIndex);
            return;
        }
        if (mode === "browser") {
            if (api.keys.isCancel(event)) {
                if (browserAtTop) { mode = browserTarget === "*" ? "list" : "detail"; host.playBack(); }
                else { enterDir(parentOf(browserPath)); host.playBack(); }
                return;
            }
            if (k === Qt.Key_Up)   { browserIndex = Math.max(0, browserIndex - 1); host.playMove(); }
            else if (k === Qt.Key_Down) { browserIndex = Math.min(browserRows.length - 1, browserIndex + 1); host.playMove(); }
            else if (api.keys.isAccept(event)) activateBrowser(browserIndex);
        }
    }

    // ============================================================ TELA
    Rectangle {
        anchors.fill: parent
        color: "#b3050608"
        MouseArea { anchors.fill: parent; onClicked: {} }
    }

    Glass {
        id: card
        backdrop: panel.backdrop
        stageItem: panel.stageItem
        anchors.centerIn: parent
        width: 1160
        height: Math.min(parent.height - 120, 800)
        radius: 34
        tint: "#38101018"
        MouseArea { anchors.fill: parent }

        // cabeçalho
        Column {
            id: head
            x: 44; y: 34
            width: parent.width - 88
            spacing: 6
            Text {
                text: panel.mode === "browser" ? (panel.browserTarget === "*" ? "Pasta dos jogos" : "Pasta · " + EM.byKey(panel.browserTarget).name)
                    : (panel.mode === "detail" && panel.detail ? panel.detail.sys.name : "Consoles e emuladores")
                color: "#ffffff"; font.family: "Roboto"; font.weight: Font.Light; font.pixelSize: 32
            }
            Text {
                width: parent.width
                elide: Text.ElideMiddle
                color: "#8cffffff"; font.family: "Roboto"; font.pixelSize: 14
                text: {
                    void panel.version;
                    if (panel.mode === "browser") return panel.shortPath(panel.browserPath);
                    if (!panel.host) return "";
                    var ra = EM.retroarchPackage(panel.host.p7Installed);
                    var raName = "";
                    EM.RETROARCH.forEach(function (r) { if (r.pkg === ra) raName = r.label; });
                    return ra ? "RetroArch encontrado: " + raName + "  ·  os outros emuladores são achados sozinhos"
                              : "RetroArch não encontrado neste tablet  ·  os outros emuladores são achados sozinhos";
                }
            }
        }

        // ---------------------------------------------------- lista de consoles
        ListView {
            id: list
            visible: panel.mode === "list"
            x: 28
            y: head.y + head.height + 22
            width: parent.width - 56
            height: parent.height - y - 30
            clip: true
            model: panel.listCount
            currentIndex: panel.listIndex
            highlightMoveDuration: 160
            preferredHighlightBegin: height * 0.3
            preferredHighlightEnd: height * 0.7
            highlightRangeMode: ListView.ApplyRange
            spacing: 4
            delegate: Rectangle {
                readonly property bool isSel: index === panel.listIndex
                readonly property var row: index > 0 && index <= panel.rows.length ? panel.rows[index - 1] : null
                width: list.width
                height: row ? 64 : 60
                radius: 18
                color: isSel ? "#26ffffff" : "transparent"
                border.width: isSel ? 1 : 0
                border.color: "#40ffffff"

                // pasta principal / Pronto
                Column {
                    visible: row === null
                    anchors.verticalCenter: parent.verticalCenter
                    x: 20
                    spacing: 3
                    Text {
                        text: index === 0 ? "Pasta dos jogos" : "Pronto"
                        color: "#f2ffffff"; font.family: "Roboto"; font.pixelSize: 18
                    }
                    Text {
                        visible: index === 0
                        text: {
                            void panel.version;
                            if (!panel.host) return "";
                            return panel.host.p7Root ? panel.shortPath(panel.host.p7Root)
                                 : "Automático: procura em " + (panel.host.p7Roots.length ? panel.host.p7Roots.map(panel.shortPath).join(", ") : "ROMs, Jogos, Emulation...");
                        }
                        color: "#8cffffff"; font.family: "Roboto"; font.pixelSize: 13
                    }
                }

                // um console
                Item {
                    visible: row !== null
                    anchors.fill: parent
                    Rectangle {
                        x: 20; anchors.verticalCenter: parent.verticalCenter
                        width: 10; height: 10; radius: 5
                        color: row ? row.sys.color : "transparent"
                        opacity: row && !row.off ? 1 : 0.35
                    }
                    Column {
                        x: 44; anchors.verticalCenter: parent.verticalCenter
                        width: 360
                        spacing: 3
                        Text { text: row ? row.sys.name : ""; color: row && row.off ? "#73ffffff" : "#f2ffffff"; font.family: "Roboto"; font.pixelSize: 18 }
                        Text {
                            width: parent.width; elide: Text.ElideMiddle
                            text: row ? (row.off ? "Não aparece na biblioteca" : (row.folder ? panel.shortPath(row.folder) : "Pasta não encontrada")) : ""
                            color: "#80ffffff"; font.family: "Roboto"; font.pixelSize: 13
                        }
                    }
                    Text {
                        x: 430; anchors.verticalCenter: parent.verticalCenter
                        width: 300; elide: Text.ElideRight
                        text: row ? EM.emuLabel(row.emu) : ""
                        color: row && row.ok ? "#d9ffffff" : "#80ffffff"; font.family: "Roboto"; font.pixelSize: 15
                    }
                    Text {
                        x: 760; anchors.verticalCenter: parent.verticalCenter
                        text: row && row.folder && !row.off ? row.count + (row.count === 1 ? " jogo" : " jogos") : ""
                        color: "#80ffffff"; font.family: "Roboto"; font.pixelSize: 14
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: statusText.implicitWidth + 26; height: 30; radius: 15
                        color: !row ? "transparent" : (row.status === "Pronto" ? "#2e4caf50" : (row.status === "Falta o emulador" ? "#33ffb74d" : "#14ffffff"))
                        border.width: 1
                        border.color: !row ? "transparent" : (row.status === "Pronto" ? "#804caf50" : (row.status === "Falta o emulador" ? "#80ffb74d" : "#26ffffff"))
                        Text {
                            id: statusText
                            anchors.centerIn: parent
                            text: row ? row.status : ""
                            color: "#f2ffffff"; font.family: "Roboto"; font.pixelSize: 13
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { panel.listIndex = index; panel.activateList(index); }
                }
            }
        }

        // ---------------------------------------------------- um console
        Column {
            id: detailCol
            visible: panel.mode === "detail" && panel.detail !== null
            x: 28
            y: head.y + head.height + 22
            width: parent.width - 56
            spacing: 6

            Repeater {
                model: {
                    var d = panel.detail;
                    if (!d) return [];
                    var emuText = EM.emuLabel(d.emu) + (d.emu.note ? "  ·  " + d.emu.note : "") + (d.ok ? "" : "  ·  não instalado");
                    return [
                        { title: "Pasta dos jogos", detail: d.folder ? panel.shortPath(d.folder) + (panel.host.p7Overrides[d.sys.key] && panel.host.p7Overrides[d.sys.key] !== "-" ? "" : "  ·  achada sozinha") : "Nenhuma pasta encontrada. Aperte X para escolher." },
                        { title: "Emulador", detail: emuText, arrows: true },
                        { title: d.off ? "Mostrar este console" : "Não mostrar este console", detail: d.off ? "Ele volta para a biblioteca" : "Esconde da biblioteca sem apagar nada" },
                        { title: "Achar a pasta sozinho", detail: "Esquece a pasta escolhida e procura de novo" },
                        { title: "Voltar", detail: "" }
                    ];
                }
                delegate: Rectangle {
                    readonly property bool isSel: index === panel.detailIndex
                    width: detailCol.width
                    height: modelData.detail ? 70 : 56
                    radius: 18
                    color: isSel ? "#26ffffff" : "transparent"
                    border.width: isSel ? 1 : 0
                    border.color: "#40ffffff"
                    Column {
                        x: 20; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 120
                        spacing: 4
                        Text { text: modelData.title; color: "#f2ffffff"; font.family: "Roboto"; font.pixelSize: 18 }
                        Text { visible: modelData.detail !== ""; width: parent.width; elide: Text.ElideMiddle; text: modelData.detail; color: "#99ffffff"; font.family: "Roboto"; font.pixelSize: 14 }
                    }
                    Text {
                        visible: modelData.arrows === true
                        anchors.right: parent.right; anchors.rightMargin: 22
                        anchors.verticalCenter: parent.verticalCenter
                        text: "‹   ›"
                        color: "#b3ffffff"; font.family: "Roboto"; font.pixelSize: 22
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { panel.detailIndex = index; panel.activateDetail(index); }
                    }
                }
            }

            Item { width: 1; height: 12 }

            // o que falta
            Rectangle {
                width: parent.width
                height: hintText.implicitHeight + 32
                radius: 18
                visible: hintText.text !== ""
                color: "#1affb74d"
                border.width: 1
                border.color: "#4dffb74d"
                Text {
                    id: hintText
                    x: 20; y: 16
                    width: parent.width - 40
                    wrapMode: Text.WordWrap
                    color: "#f2ffffff"; font.family: "Roboto"; font.pixelSize: 15; lineHeight: 1.3
                    text: {
                        var d = panel.detail;
                        if (!d || d.off) return "";
                        var parts = [];
                        if (!d.folder) parts.push("Escolha a pasta onde estão os jogos de " + d.sys.name + ".");
                        var h = EM.setupHint(d.sys, d.emu, panel.host.p7Installed);
                        if (h) parts.push(h);
                        return parts.join("\n");
                    }
                }
            }

            Text {
                width: parent.width
                leftPadding: 20
                topPadding: 8
                wrapMode: Text.WordWrap
                color: "#73ffffff"; font.family: "Roboto"; font.pixelSize: 13; lineHeight: 1.3
                text: panel.detail ? "Arquivos aceitos: " + panel.detail.sys.exts.join(", ") + ".  Use ◀ ▶ no Emulador para trocar." : ""
            }
        }

        // ---------------------------------------------------- navegador de pastas
        ListView {
            id: browser
            visible: panel.mode === "browser"
            x: 28
            y: head.y + head.height + 22
            width: parent.width - 56
            height: parent.height - y - 30
            clip: true
            model: panel.browserRows
            currentIndex: panel.browserIndex
            highlightMoveDuration: 140
            preferredHighlightBegin: height * 0.3
            preferredHighlightEnd: height * 0.7
            highlightRangeMode: ListView.ApplyRange
            spacing: 3
            delegate: Rectangle {
                readonly property bool isSel: index === panel.browserIndex
                width: browser.width
                height: 54
                radius: 16
                color: isSel ? "#26ffffff" : (modelData.kind === "use" ? "#12ffffff" : "transparent")
                border.width: isSel ? 1 : 0
                border.color: "#40ffffff"
                Text {
                    x: 20; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40; elide: Text.ElideRight
                    text: modelData.kind === "use" ? "✓   " + modelData.label
                        : (modelData.kind === "up" ? "‹   " + modelData.label : "▸   " + modelData.label)
                    color: modelData.kind === "dir" ? "#e6ffffff" : "#ffffff"
                    font.family: "Roboto"; font.pixelSize: 17
                    font.weight: modelData.kind === "use" ? Font.Medium : Font.Normal
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { panel.browserIndex = index; panel.activateBrowser(index); }
                }
            }
        }
    }
}
