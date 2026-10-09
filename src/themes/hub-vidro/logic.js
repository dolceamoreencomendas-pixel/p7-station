.pragma library
.import "emulators.js" as EM

// Funções puras do tema (sem dependência do Pegasus), para poderem ser testadas fora dele.

// Dados dos consoles vêm de emulators.js (uma só lista para o app inteiro).
var SYSTEMS = {};
EM.SYSTEMS.forEach(function (s) {
    SYSTEMS[s.key] = { name: s.name, short: s.short, color: s.color, thumbs: s.thumbs, ra: s.ra, media: s.media };
});

// Ordem dos filtros da Biblioteca: do mais novo para o mais antigo
var SYSTEM_ORDER = EM.SYSTEMS.map(function (s) { return s.key; }).reverse();

function systemInfo(shortName) {
    var key = (shortName || "").toLowerCase();
    if (SYSTEMS.hasOwnProperty(key)) return SYSTEMS[key];
    return { name: shortName || "Outros", short: shortName || "", color: "#5a5f6b", thumbs: "", ra: [] };
}

// "Super Mario World (USA) [!]" -> "Super Mario World"
function cleanTitle(title) {
    if (!title) return "";
    var t = String(title).replace(/\s*[\(\[][^\)\]]*[\)\]]/g, "");
    t = t.replace(/\s+/g, " ").trim();
    return t.length ? t : String(title).trim();
}

// Para comparar nomes entre o arquivo do jogo e o RetroAchievements.
function normalize(title) {
    var t = cleanTitle(title).toLowerCase();
    t = t.replace(/&/g, " and ");
    // No-Intro escreve "Legend of Zelda, The - ..."; o RetroAchievements escreve "The Legend of Zelda: ..."
    t = t.replace(/\bthe\b/g, "");
    t = t.replace(/[^a-z0-9]+/g, "");
    return t;
}

// "/storage/emulated/0/Jogos/snes/Super Mario World (USA).sfc" -> "Super Mario World (USA)"
function baseName(path) {
    if (!path) return "";
    var name = String(path).replace(/\\/g, "/").split("/").pop();
    try { name = decodeURIComponent(name); } catch (e) {}
    var dot = name.lastIndexOf(".");
    return dot > 0 ? name.substring(0, dot) : name;
}

function monogram(title) {
    var t = cleanTitle(title).replace(/^the\s+/i, "");
    var m = t.match(/[A-Za-z0-9]/);
    return m ? m[0].toUpperCase() : "?";
}

// Capas gratuitas do projeto Libretro. O nome precisa bater com o nome do arquivo (padrão No-Intro / Redump).
function thumbUrl(shortName, fileBase, kind) {
    var sys = systemInfo(shortName);
    if (!sys.thumbs || !fileBase) return "";
    var folder = kind === "snap" ? "Named_Snaps" : (kind === "title" ? "Named_Titles" : "Named_Boxarts");
    var safe = String(fileBase).replace(/[&*\/:`<>?\\|"]/g, "_");
    return "https://thumbnails.libretro.com/" + encodeURIComponent(sys.thumbs) + "/" + folder + "/" + encodeURIComponent(safe) + ".png";
}

// segundos -> "32 h 10 min" / "45 min" / "—"
function formatPlayTime(seconds) {
    var s = Number(seconds) || 0;
    if (s < 60) return s > 0 ? "menos de 1 min" : "—";
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    if (h === 0) return m + " min";
    return h + " h " + (m < 10 ? "0" : "") + m + " min";
}

function startOfDay(d) {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

// Data -> "Hoje", "Ontem", "Há 3 dias", "Semana passada", "Há 2 semanas", "12/05/2026"
function formatLastPlayed(date, now) {
    if (!date || isNaN(date.getTime()) || date.getFullYear() < 2000) return "Nunca jogado";
    now = now || new Date();
    var days = Math.round((startOfDay(now) - startOfDay(date)) / 86400000);
    if (days <= 0) return "Hoje";
    if (days === 1) return "Ontem";
    if (days < 7) return "Há " + days + " dias";
    if (days < 14) return "Semana passada";
    if (days < 31) return "Há " + Math.floor(days / 7) + " semanas";
    var dd = date.getDate(), mm = date.getMonth() + 1;
    return (dd < 10 ? "0" : "") + dd + "/" + (mm < 10 ? "0" : "") + mm + "/" + date.getFullYear();
}

function playedTime(entry) {
    var d = entry.lastPlayed;
    if (!d || isNaN(d.getTime()) || d.getFullYear() < 2000) return 0;
    return d.getTime();
}

// Fileira do Início: primeiro os jogados por último, depois o resto da biblioteca (A–Z).
function buildRecents(entries, limit) {
    var played = entries.filter(function (e) { return playedTime(e) > 0; });
    played.sort(function (a, b) { return playedTime(b) - playedTime(a); });
    var rest = sortAZ(entries.filter(function (e) { return playedTime(e) <= 0; }));
    return {
        label: played.length > 0 ? "Jogados recentemente" : "Sua biblioteca",
        played: played.length,
        list: played.concat(rest).slice(0, limit)
    };
}

var SORTS = ["A–Z", "Recentes", "Mais jogados"];

// mode 0 = A–Z · 1 = jogados por último · 2 = mais tempo jogado
function sortList(list, mode) {
    var out = sortAZ(list);
    if (mode === 1) out.sort(function (a, b) { return playedTime(b) - playedTime(a); });
    if (mode === 2) out.sort(function (a, b) { return (Number(b.playTime) || 0) - (Number(a.playTime) || 0); });
    return out;
}

function sortAZ(entries) {
    var copy = entries.slice();
    copy.sort(function (a, b) {
        var x = a.display.toLowerCase(), y = b.display.toLowerCase();
        return x < y ? -1 : (x > y ? 1 : 0);
    });
    return copy;
}

// key "" = todos · "*fav" = favoritos · senão o console
function filterList(entries, key, mode) {
    var list = entries.filter(function (e) {
        if (!key) return true;
        if (key === "*fav") return !!e.fav;
        return e.sys === key;
    });
    return sortList(list, mode || 0);
}

function filterBySystem(entries, shortName) {
    return filterList(entries, shortName, 0);
}

// Abas da Biblioteca: "Todos", "Favoritos" (se houver) e só os consoles que têm jogos, com a contagem.
function libraryFilters(entries) {
    var count = {}, favs = 0;
    entries.forEach(function (e) { count[e.sys] = (count[e.sys] || 0) + 1; if (e.fav) favs++; });
    var out = [{ key: "", label: "Todos", name: "Todos os jogos", count: entries.length }];
    if (favs > 0) out.push({ key: "*fav", label: "Favoritos", name: "Favoritos", count: favs });
    SYSTEM_ORDER.forEach(function (k) {
        if (count[k]) out.push({ key: k, label: SYSTEMS[k].short, name: SYSTEMS[k].name, count: count[k] });
    });
    Object.keys(count).forEach(function (k) {
        if (!SYSTEMS.hasOwnProperty(k)) out.push({ key: k, label: systemInfo(k).short, name: systemInfo(k).name, count: count[k] });
    });
    return out;
}

function indexOfFilter(filters, key) {
    for (var i = 0; i < filters.length; i++) if (filters[i].key === key) return i;
    return 0;
}

// Resposta do API_GetUserCompletionProgress -> índice por nome normalizado (+ console).
// Progresso do usuário (API_GetUserCompletionProgress): só jogos que ele já abriu com o RetroAchievements.
function indexAchievements(results) {
    var idx = {};
    (results || []).forEach(function (r) {
        var key = normalize(r.Title);
        if (!key) return;
        var item = {
            got: Math.max(Number(r.NumAwardedHardcore) || 0, Number(r.NumAwarded) || 0),
            total: Number(r.MaxPossible) || 0,
            consoleId: Number(r.ConsoleID) || 0
        };
        if (!idx[key]) idx[key] = [];
        idx[key].push(item);
    });
    return idx;
}

// Catálogo de um console (API_GetGameList com f=1): todos os jogos que têm troféus.
// Devolve { chave: total } sem subconjuntos, hacks e homebrews (que repetiriam o nome).
function indexCatalog(list) {
    var out = {};
    (list || []).forEach(function (g) {
        var title = String(g.Title || g.title || "");
        if (!title || title.charAt(0) === "~" || /\[subset/i.test(title)) return;
        var n = Number(g.NumAchievements || g.numAchievements) || 0;
        if (n <= 0) return;
        // títulos alternativos vêm separados por " | "
        title.split("|").forEach(function (part) {
            var key = normalize(part);
            if (key && !(key in out)) out[key] = n;
        });
    });
    return out;
}

// IDs de console do RetroAchievements que aparecem na biblioteca
function raConsolesIn(entries) {
    var ids = {};
    (entries || []).forEach(function (e) { systemInfo(e.sys).ra.forEach(function (id) { ids[id] = true; }); });
    return Object.keys(ids).map(Number);
}

// Devolve {got,total,played} ou null. Jogos que o usuário nunca abriu aparecem com 0 de N
// quando estão no catálogo. Sistemas sem RetroAchievements (Switch, Wii U) devolvem null.
function trophiesFor(idx, entry, catalogs) {
    var sys = systemInfo(entry.sys);
    if (!sys.ra.length) return null;
    var key = normalize(entry.title);
    var list = idx ? idx[key] : null;
    if (list) {
        for (var i = 0; i < list.length; i++) {
            if (sys.ra.indexOf(list[i].consoleId) !== -1 && list[i].total > 0)
                return { got: list[i].got, total: list[i].total, played: true };
        }
    }
    if (catalogs) {
        for (var j = 0; j < sys.ra.length; j++) {
            var cat = catalogs[sys.ra[j]];
            if (cat && cat[key]) return { got: 0, total: cat[key], played: false };
        }
    }
    return null;
}

function hasTrophySupport(shortName) {
    return systemInfo(shortName).ra.length > 0;
}

function clampIndex(i, count) {
    if (count <= 0) return 0;
    if (i < 0) return 0;
    if (i >= count) return count - 1;
    return i;
}
