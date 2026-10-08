.pragma library

// Funções puras do tema (sem dependência do Pegasus), para poderem ser testadas fora dele.

var SYSTEMS = {
    snes:   { name: "Super Nintendo",  short: "SNES",   color: "#6d63b8", thumbs: "Nintendo - Super Nintendo Entertainment System", ra: [3] },
    psx:    { name: "PlayStation",     short: "PS1",    color: "#5f6f8f", thumbs: "Sony - PlayStation",                            ra: [12] },
    ps2:    { name: "PlayStation 2",   short: "PS2",    color: "#2f4fb0", thumbs: "Sony - PlayStation 2",                          ra: [21] },
    wiiu:   { name: "Wii U",           short: "Wii U",  color: "#2a8fb0", thumbs: "Nintendo - Wii U",                              ra: [] },
    switch: { name: "Nintendo Switch", short: "Switch", color: "#c0453e", thumbs: "",                                              ra: [] }
};

var SYSTEM_ORDER = ["switch", "wiiu", "ps2", "psx", "snes"];

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

// Lista de jogos recentes; se ninguém jogou nada ainda, mostra os primeiros da biblioteca.
function buildRecents(entries, limit) {
    var played = entries.filter(function (e) { return playedTime(e) > 0; });
    played.sort(function (a, b) { return playedTime(b) - playedTime(a); });
    if (played.length > 0) return { label: "Jogados recentemente", list: played.slice(0, limit) };
    return { label: "Sua biblioteca", list: sortAZ(entries).slice(0, limit) };
}

function sortAZ(entries) {
    var copy = entries.slice();
    copy.sort(function (a, b) {
        var x = a.display.toLowerCase(), y = b.display.toLowerCase();
        return x < y ? -1 : (x > y ? 1 : 0);
    });
    return copy;
}

function filterBySystem(entries, shortName) {
    if (!shortName) return sortAZ(entries);
    return sortAZ(entries.filter(function (e) { return e.sys === shortName; }));
}

// Abas da Biblioteca: "Todos" + só os consoles que têm jogos, na ordem fixa.
function libraryFilters(entries) {
    var present = {};
    entries.forEach(function (e) { present[e.sys] = true; });
    var out = [{ key: "", label: "Todos" }];
    SYSTEM_ORDER.forEach(function (k) { if (present[k]) out.push({ key: k, label: SYSTEMS[k].short }); });
    Object.keys(present).forEach(function (k) {
        if (!SYSTEMS.hasOwnProperty(k)) out.push({ key: k, label: systemInfo(k).short });
    });
    return out;
}

// Resposta do API_GetUserCompletionProgress -> índice por nome normalizado (+ console).
function indexAchievements(results) {
    var idx = {};
    (results || []).forEach(function (r) {
        var key = normalize(r.Title);
        if (!key) return;
        var item = {
            got: Number(r.NumAwardedHardcore) > Number(r.NumAwarded) ? Number(r.NumAwardedHardcore) : Number(r.NumAwarded) || 0,
            total: Number(r.MaxPossible) || 0,
            consoleId: Number(r.ConsoleID) || 0
        };
        if (!idx[key]) idx[key] = [];
        idx[key].push(item);
    });
    return idx;
}

// Devolve {got,total} ou null. Sistemas sem RetroAchievements (Switch, Wii U) devolvem null.
function trophiesFor(idx, entry) {
    var sys = systemInfo(entry.sys);
    if (!sys.ra.length || !idx) return null;
    var list = idx[normalize(entry.title)];
    if (!list) return null;
    for (var i = 0; i < list.length; i++) {
        if (sys.ra.indexOf(list[i].consoleId) !== -1 && list[i].total > 0) return list[i];
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
