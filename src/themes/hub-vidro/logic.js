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
            consoleId: Number(r.ConsoleID) || 0,
            gameId: Number(r.GameID) || 0
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
        var id = Number(g.ID || g.id) || 0;
        if (n <= 0) return;
        // títulos alternativos vêm separados por " | "
        title.split("|").forEach(function (part) {
            var key = normalize(part);
            if (key && !(key in out)) out[key] = [n, id];
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
                return { got: list[i].got, total: list[i].total, played: true, gameId: list[i].gameId };
        }
    }
    if (catalogs) {
        for (var j = 0; j < sys.ra.length; j++) {
            var cat = catalogs[sys.ra[j]];
            var c = cat ? cat[key] : null;
            if (c) {
                var n = typeof c === "number" ? c : c[0];
                var gid = typeof c === "number" ? 0 : c[1];
                return { got: 0, total: n, played: false, gameId: gid };
            }
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

// Prateleiras da Biblioteca: uma por console (do mais novo ao mais antigo), favoritos primeiro.
function buildShelves(entries, sortMode) {
    var bySys = {};
    var favs = [];
    (entries || []).forEach(function (e) {
        (bySys[e.sys] = bySys[e.sys] || []).push(e);
        if (e.fav) favs.push(e);
    });
    var out = [];
    if (favs.length) out.push({ key: "*fav", name: "Favoritos", short: "♥", color: "#ff5c8a", items: sortList(favs, sortMode) });
    SYSTEM_ORDER.forEach(function (k) {
        if (bySys[k]) out.push({ key: k, name: SYSTEMS[k].name, short: SYSTEMS[k].short, color: SYSTEMS[k].color, items: sortList(bySys[k], sortMode) });
    });
    Object.keys(bySys).forEach(function (k) {
        if (!SYSTEMS.hasOwnProperty(k)) out.push({ key: k, name: systemInfo(k).name, short: systemInfo(k).short, color: "#5a5f6b", items: sortList(bySys[k], sortMode) });
    });
    return out;
}

// Conquistas de um jogo (API_GetGameInfoAndUserProgress) em lista: conquistadas primeiro, na ordem do jogo
function parseGameAchievements(data) {
    var list = [];
    var ach = data && (data.Achievements || data.achievements) || {};
    Object.keys(ach).forEach(function (k) {
        var a = ach[k];
        var date = a.DateEarnedHardcore || a.DateEarned || "";
        list.push({
            title: String(a.Title || ""),
            desc: String(a.Description || ""),
            points: Number(a.Points) || 0,
            badge: String(a.BadgeName || ""),
            earned: date !== "",
            date: date ? String(date).substring(0, 10) : "",
            when: String(date),
            order: Number(a.DisplayOrder) || 0
        });
    });
    list.sort(function (a, b) {
        if (a.earned !== b.earned) return a.earned ? -1 : 1;
        return a.order - b.order;
    });
    var got = 0, points = 0, pointsGot = 0;
    list.forEach(function (a) { points += a.points; if (a.earned) { got++; pointsGot += a.points; } });
    return { list: list, got: got, total: list.length, points: points, pointsGot: pointsGot };
}

// "2026-10-08" -> "08/10/2026"
function formatDateBR(d) {
    var m = String(d || "").match(/^(\d{4})-(\d{2})-(\d{2})/);
    return m ? m[3] + "/" + m[2] + "/" + m[1] : "";
}

// ------------------------------------------------------------ capa gerada
// Jogo sem capa: degradê na cor do console, puxado um pouco para outro tom pelo nome do jogo
// (dois jogos do mesmo console não ficam iguais). Devolve [cor clara, cor escura].
function hexToHsl(hex) {
    var h = String(hex || "#5a5f6b").replace("#", "");
    if (h.length === 8) h = h.substring(2);
    var r = parseInt(h.substring(0, 2), 16) / 255, g = parseInt(h.substring(2, 4), 16) / 255, b = parseInt(h.substring(4, 6), 16) / 255;
    var max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2, s = 0, hue = 0;
    if (max !== min) {
        var d = max - min;
        s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
        if (max === r) hue = (g - b) / d + (g < b ? 6 : 0);
        else if (max === g) hue = (b - r) / d + 2;
        else hue = (r - g) / d + 4;
        hue /= 6;
    }
    return [hue, s, l];
}

function hslToHex(h, s, l) {
    function f(p, q, t) {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1 / 6) return p + (q - p) * 6 * t;
        if (t < 1 / 2) return q;
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
        return p;
    }
    var r, g, b;
    if (s === 0) { r = g = b = l; }
    else {
        var q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
        r = f(p, q, h + 1 / 3); g = f(p, q, h); b = f(p, q, h - 1 / 3);
    }
    function x(v) { var n = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16); return n.length < 2 ? "0" + n : n; }
    return "#" + x(r) + x(g) + x(b);
}

function titleHash(t) {
    var s = String(t || ""), h = 2166136261;
    for (var i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = (h * 16777619) >>> 0; }
    return h;
}

function coverColors(color, title) {
    var hsl = hexToHsl(color);
    var k = titleHash(cleanTitle(title));
    var shift = ((k % 1000) / 1000 - 0.5) * 0.16;          // ± 29° de matiz
    var h = (hsl[0] + shift + 1) % 1;
    var s = Math.max(0.45, Math.min(0.9, hsl[1] + 0.15));
    var light = hslToHex(h, s, Math.max(0.5, Math.min(0.66, hsl[2] + 0.12)));
    var dark = hslToHex((h + 0.92 - ((k >> 10) % 100) / 2000) % 1, Math.min(0.8, s), 0.15);
    return [light, dark];
}

// Data da conquista mais nova primeiro (para "conquistas recentes")
function recentEarned(list, limit) {
    var got = (list || []).filter(function (a) { return a.earned; });
    got.sort(function (a, b) { return a.when < b.when ? 1 : (a.when > b.when ? -1 : 0); });
    return got.slice(0, limit || 8);
}

// "Ontem" -> "ontem", para usar no meio da frase ("Último: ontem")
function shortLastPlayed(date) {
    var s = formatLastPlayed(date);
    if (/^\d/.test(s)) return s;
    return s.charAt(0).toLowerCase() + s.substring(1);
}

// Nome curto do controle para o topo ("Sony ... Wireless Controller" -> "DualSense")
function padLabel(name) {
    var n = String(name || "");
    if (/dualsense|wireless controller/i.test(n)) return "DualSense";
    if (/dualshock/i.test(n)) return "DualShock";
    if (/xbox/i.test(n)) return "Xbox";
    if (/8bitdo/i.test(n)) return "8BitDo";
    if (/pro controller/i.test(n)) return "Pro Controller";
    n = n.replace(/\s+/g, " ").trim();
    return n.length > 18 ? n.substring(0, 17) + "…" : (n || "Controle");
}

// Cor do anel da bateria
function batteryColor(level, charging) {
    if (charging) return "#7fd6ff";
    if (level <= 15) return "#ff7a6b";
    if (level <= 30) return "#ffc35a";
    return "#5ff0a8";
}
