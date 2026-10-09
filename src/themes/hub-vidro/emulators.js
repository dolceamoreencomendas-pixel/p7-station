.pragma library

// Consoles, pastas e emuladores do P7 Station.
//
// Os comandos de cada emulador vêm das fichas públicas do Daijishō (licença MIT,
// github.com/TapiocaFox/Daijishou/tree/main/platforms), adaptadas ao formato do Pegasus:
//   {file.path}  caminho do arquivo (RetroArch tem acesso a todos os arquivos)
//   {file.uri}   endereço content:// do próprio P7 Station; o app dá permissão de leitura
//                ao emulador na hora de abrir, então o emulador não precisa ter a pasta liberada.
// O RetroArch aceita o núcleo pelo nome curto (-e LIBRETRO snes9x) desde a versão 1.10:
// ele procura o arquivo na pasta de núcleos dele, em qualquer versão (site, Play Store, 32 bits).

var RETROARCH = [
    { pkg: "com.retroarch.aarch64", label: "RetroArch 64 bits" },
    { pkg: "com.retroarch",         label: "RetroArch" },
    { pkg: "com.retroarch.ra32",    label: "RetroArch 32 bits" }
];

// emu.type "ra": núcleo do RetroArch · "app": emulador próprio (pkgs = variantes do mesmo app)
var SYSTEMS = [
    { key: "nes", name: "Nintendo (NES)", short: "NES", color: "#b5483f",
      thumbs: "Nintendo - Nintendo Entertainment System", ra: [7], media: "cart",
      exts: ["nes", "fds", "unf", "unif", "zip", "7z"],
      aliases: ["nes", "famicom", "fc", "nintendoentertainmentsystem", "nintendinho"],
      emus: [
        { id: "ra:nestopia", type: "ra", core: "nestopia", label: "Nestopia", note: "Recomendado" },
        { id: "ra:fceumm",   type: "ra", core: "fceumm",   label: "FCEUmm" },
        { id: "ra:mesen",    type: "ra", core: "mesen",    label: "Mesen", note: "Mais fiel" },
        { id: "app:nesemu",  type: "app", label: "NES.emu", pkgs: ["com.explusalpha.NesEmu"],
          args: "-n {pkg}/com.imagine.BaseActivity -a android.intent.action.VIEW -d {file.uri} -t application/zip" }
      ] },

    { key: "snes", name: "Super Nintendo", short: "SNES", color: "#6d63b8",
      thumbs: "Nintendo - Super Nintendo Entertainment System", ra: [3], media: "cart",
      exts: ["sfc", "smc", "fig", "swc", "bs", "st", "zip", "7z"],
      aliases: ["snes", "sfc", "supernintendo", "superfamicom", "supernes", "supernintendoentertainmentsystem"],
      emus: [
        { id: "ra:snes9x",       type: "ra", core: "snes9x",       label: "Snes9x", note: "Recomendado" },
        { id: "ra:bsnes",        type: "ra", core: "bsnes",        label: "bsnes", note: "Mais fiel, mais pesado" },
        { id: "ra:bsnes_hd_beta", type: "ra", core: "bsnes_hd_beta", label: "bsnes HD", note: "Modo 7 em alta resolução e tela larga" },
        { id: "ra:mesen-s",      type: "ra", core: "mesen-s",      label: "Mesen-S" },
        { id: "app:snes9xex",    type: "app", label: "Snes9x EX+", pkgs: ["com.explusalpha.Snes9xPlus"],
          args: "-n {pkg}/com.imagine.BaseActivity -a android.intent.action.VIEW -d {file.uri} -t application/zip" }
      ] },

    { key: "n64", name: "Nintendo 64", short: "N64", color: "#3f8a5a",
      thumbs: "Nintendo - Nintendo 64", ra: [2], media: "cart",
      exts: ["n64", "z64", "v64", "ndd", "zip", "7z"],
      aliases: ["n64", "nintendo64"],
      emus: [
        { id: "ra:mupen64plus_next_gles3", type: "ra", core: "mupen64plus_next_gles3", label: "Mupen64Plus-Next", note: "Recomendado" },
        { id: "ra:parallel_n64", type: "ra", core: "parallel_n64", label: "ParaLLEl N64" },
        { id: "app:m64fz", type: "app", label: "Mupen64Plus FZ",
          pkgs: ["org.mupen64plusae.v3.fzurita", "org.mupen64plusae.v3.fzurita.pro", "org.mupen64plusae.v3.alpha"],
          args: "-n {pkg}/paulscode.android.mupen64plusae.SplashActivity -a android.intent.action.VIEW -d {file.uri}" }
      ] },

    { key: "gb", name: "Game Boy", short: "GB", color: "#7d8a52",
      thumbs: "Nintendo - Game Boy", ra: [4], media: "cart",
      exts: ["gb", "dmg", "zip", "7z"],
      aliases: ["gb", "gameboy", "nintendogameboy"],
      emus: [
        { id: "ra:gambatte", type: "ra", core: "gambatte", label: "Gambatte", note: "Recomendado" },
        { id: "ra:sameboy",  type: "ra", core: "sameboy",  label: "SameBoy" },
        { id: "ra:mgba",     type: "ra", core: "mgba",     label: "mGBA" }
      ] },

    { key: "gbc", name: "Game Boy Color", short: "GBC", color: "#8a4fb0",
      thumbs: "Nintendo - Game Boy Color", ra: [6], media: "cart",
      exts: ["gbc", "cgb", "zip", "7z"],
      aliases: ["gbc", "gameboycolor", "nintendogameboycolor"],
      emus: [
        { id: "ra:gambatte", type: "ra", core: "gambatte", label: "Gambatte", note: "Recomendado" },
        { id: "ra:sameboy",  type: "ra", core: "sameboy",  label: "SameBoy" },
        { id: "ra:mgba",     type: "ra", core: "mgba",     label: "mGBA" }
      ] },

    { key: "gba", name: "Game Boy Advance", short: "GBA", color: "#4b55b8",
      thumbs: "Nintendo - Game Boy Advance", ra: [5], media: "cart",
      exts: ["gba", "agb", "zip", "7z"],
      aliases: ["gba", "gameboyadvance", "nintendogameboyadvance"],
      emus: [
        { id: "ra:mgba",     type: "ra", core: "mgba",     label: "mGBA", note: "Recomendado" },
        { id: "ra:vba_next", type: "ra", core: "vba_next", label: "VBA Next" },
        { id: "ra:gpsp",     type: "ra", core: "gpsp",     label: "gpSP", note: "Mais leve" },
        { id: "app:pizzagba", type: "app", label: "Pizza Boy GBA", pkgs: ["it.dbtecno.pizzaboygba", "it.dbtecno.pizzaboygbapro"],
          args: "-n {pkg}/it.dbtecno.pizzaboygba.MainActivity -e rom_uri {file.uri} --activity-clear-task --activity-clear-top" },
        { id: "app:gbaemu", type: "app", label: "GBA.emu", pkgs: ["com.explusalpha.GbaEmu"],
          args: "-n {pkg}/com.imagine.BaseActivity -a android.intent.action.VIEW -d {file.uri} -t application/zip" }
      ] },

    { key: "nds", name: "Nintendo DS", short: "DS", color: "#5d6470",
      thumbs: "Nintendo - Nintendo DS", ra: [18], media: "card",
      exts: ["nds", "zip", "7z"],
      aliases: ["nds", "ds", "nintendods"],
      emus: [
        { id: "app:melonds", type: "app", label: "melonDS", pkgs: ["me.magnum.melonds", "me.magnum.melonds.nightly"],
          args: "-n {pkg}/me.magnum.melonds.ui.emulator.EmulatorActivity -a me.magnum.melonds.LAUNCH_ROM -e uri {file.uri}", note: "Recomendado" },
        { id: "app:drastic", type: "app", label: "DraStic", pkgs: ["com.dsemu.drastic"],
          args: "-n {pkg}/com.dsemu.drastic.DraSticActivity -d {file.uri} --activity-clear-task --activity-clear-top" },
        { id: "ra:melonds", type: "ra", core: "melonds", label: "melonDS" },
        { id: "ra:desmume", type: "ra", core: "desmume", label: "DeSmuME" }
      ] },

    { key: "genesis", name: "Mega Drive", short: "MD", color: "#2b3f8f",
      thumbs: "Sega - Mega Drive - Genesis", ra: [1], media: "cart",
      exts: ["md", "gen", "smd", "bin", "68k", "sgd", "zip", "7z"],
      aliases: ["genesis", "megadrive", "md", "segagenesis", "segamegadrive", "megadrivegenesis", "genesismegadrive"],
      emus: [
        { id: "ra:genesis_plus_gx", type: "ra", core: "genesis_plus_gx", label: "Genesis Plus GX", note: "Recomendado" },
        { id: "ra:genesis_plus_gx_wide", type: "ra", core: "genesis_plus_gx_wide", label: "Genesis Plus GX Wide", note: "Tela larga" },
        { id: "ra:picodrive", type: "ra", core: "picodrive", label: "PicoDrive" },
        { id: "app:mdemu", type: "app", label: "MD.emu", pkgs: ["com.explusalpha.MdEmu"],
          args: "-n {pkg}/com.imagine.BaseActivity -a android.intent.action.VIEW -d {file.uri} -t application/zip" }
      ] },

    { key: "psx", name: "PlayStation", short: "PS1", color: "#5f6f8f",
      thumbs: "Sony - PlayStation", ra: [12], media: "disc",
      exts: ["chd", "pbp", "cue", "m3u", "iso", "img", "ecm"],
      aliases: ["psx", "ps1", "ps", "playstation", "playstation1", "sonyplaystation", "psone"],
      emus: [
        { id: "app:duckstation", type: "app", label: "DuckStation", pkgs: ["com.github.stenzek.duckstation"],
          args: "-n {pkg}/com.github.stenzek.duckstation.EmulationActivity -e bootPath {file.uri} --activity-clear-task --activity-clear-top", note: "Recomendado" },
        { id: "ra:swanstation",  type: "ra", core: "swanstation",  label: "SwanStation" },
        { id: "ra:pcsx_rearmed", type: "ra", core: "pcsx_rearmed", label: "PCSX ReARMed", note: "Mais leve" },
        { id: "ra:mednafen_psx_hw", type: "ra", core: "mednafen_psx_hw", label: "Beetle PSX HW", note: "Mais fiel" },
        { id: "app:epsxe", type: "app", label: "ePSXe", pkgs: ["com.epsxe.ePSXe"],
          args: "-n {pkg}/com.epsxe.ePSXe.ePSXe -a android.intent.action.MAIN -e com.epsxe.ePSXe.isoName {file.path} --activity-clear-task --activity-clear-top" }
      ] },

    { key: "ps2", name: "PlayStation 2", short: "PS2", color: "#2f4fb0",
      thumbs: "Sony - PlayStation 2", ra: [21], media: "disc",
      exts: ["iso", "chd", "cso", "zso", "gz", "mdf"],
      aliases: ["ps2", "playstation2", "sonyplaystation2"],
      emus: [
        { id: "app:nethersx2", type: "app", label: "NetherSX2",
          pkgs: ["xyz.aethersx2.android", "xyz.aethersx2.tturnip", "xyz.aethersx2.cturnip"],
          args: "-n {pkg}/xyz.aethersx2.android.EmulationActivity -a android.intent.action.MAIN -e bootPath {file.uri} --activity-clear-task --activity-clear-top", note: "Recomendado" },
        { id: "app:armsx2", type: "app", label: "ARMSX2", pkgs: ["com.armsx2"],
          args: "-n {pkg}/com.armsx2.Main -a android.intent.action.VIEW -d {file.uri}" },
        { id: "app:armsx2play", type: "app", label: "ARMSX2 (Play Store)", pkgs: ["come.nanodata.armsx2"],
          args: "-n {pkg}/com.armsx2.Main -a android.intent.action.VIEW -d {file.uri} --activity-clear-task --activity-clear-top" }
      ] },

    { key: "psp", name: "PSP", short: "PSP", color: "#3d4452",
      thumbs: "Sony - PlayStation Portable", ra: [41], media: "disc",
      exts: ["iso", "cso", "chd", "pbp", "elf"],
      aliases: ["psp", "playstationportable", "sonypsp"],
      emus: [
        { id: "app:ppsspp", type: "app", label: "PPSSPP", pkgs: ["org.ppsspp.ppssppgold", "org.ppsspp.ppsspp"],
          args: "-n {pkg}/org.ppsspp.ppsspp.PpssppActivity -a android.intent.action.VIEW -c android.intent.category.DEFAULT -d {file.uri} -t application/octet-stream --activity-clear-task --activity-clear-top --activity-no-history", note: "Recomendado" },
        { id: "ra:ppsspp", type: "ra", core: "ppsspp", label: "PPSSPP" }
      ] },

    { key: "dreamcast", name: "Dreamcast", short: "DC", color: "#d0602e",
      thumbs: "Sega - Dreamcast", ra: [40], media: "disc",
      exts: ["chd", "cdi", "gdi", "cue", "m3u"],
      aliases: ["dreamcast", "dc", "segadreamcast"],
      emus: [
        { id: "app:flycast", type: "app", label: "Flycast", pkgs: ["com.flycast.emulator"],
          args: "-n {pkg}/com.flycast.emulator.MainActivity -a android.intent.action.VIEW -d {file.uri}", note: "Recomendado" },
        { id: "app:redream", type: "app", label: "Redream", pkgs: ["io.recompiled.redream"],
          args: "-n {pkg}/io.recompiled.redream.MainActivity -a android.intent.action.VIEW -d {file.uri}" },
        { id: "ra:flycast", type: "ra", core: "flycast", label: "Flycast" }
      ] },

    { key: "gc", name: "GameCube", short: "GC", color: "#5a45a8",
      thumbs: "Nintendo - GameCube", ra: [16], media: "disc",
      exts: ["iso", "rvz", "gcm", "gcz", "ciso", "dol", "elf"],
      aliases: ["gc", "gamecube", "ngc", "nintendogamecube"],
      emus: [
        { id: "app:dolphin", type: "app", label: "Dolphin", pkgs: ["org.dolphinemu.dolphinemu", "org.dolphinemu.mmjr"],
          args: "-n {pkg}/org.dolphinemu.dolphinemu.ui.main.MainActivity -a android.intent.action.MAIN -e AutoStartFile {file.uri}", note: "Recomendado" },
        { id: "ra:dolphin", type: "ra", core: "dolphin", label: "Dolphin" }
      ] },

    { key: "wii", name: "Wii", short: "Wii", color: "#7f8894",
      thumbs: "Nintendo - Wii", ra: [19], media: "disc",
      exts: ["iso", "rvz", "wbfs", "wia", "gcz", "ciso", "wad"],
      aliases: ["wii", "nintendowii"],
      emus: [
        { id: "app:dolphin", type: "app", label: "Dolphin", pkgs: ["org.dolphinemu.dolphinemu", "org.dolphinemu.mmjr"],
          args: "-n {pkg}/org.dolphinemu.dolphinemu.ui.main.MainActivity -a android.intent.action.MAIN -e AutoStartFile {file.uri}", note: "Recomendado" },
        { id: "ra:dolphin", type: "ra", core: "dolphin", label: "Dolphin" }
      ] },

    { key: "wiiu", name: "Wii U", short: "Wii U", color: "#2a8fb0",
      thumbs: "Nintendo - Wii U", ra: [], media: "disc",
      exts: ["wua", "wud", "wux", "rpx"],
      aliases: ["wiiu", "nintendowiiu"],
      emus: [
        { id: "app:cemu", type: "app", label: "Cemu", pkgs: ["info.cemu.cemu"],
          args: "-n {pkg}/info.cemu.cemu.emulation.EmulationActivity -d {file.uri} --activity-clear-task --activity-clear-top", note: "Recomendado" }
      ] },

    { key: "switch", name: "Nintendo Switch", short: "Switch", color: "#c0453e",
      thumbs: "", ra: [], media: "card",
      exts: ["nsp", "xci", "nca", "nro", "nso"],
      aliases: ["switch", "nintendoswitch", "ns"],
      emus: [
        { id: "app:eden", type: "app", label: "Eden",
          pkgs: ["dev.eden.eden_emulator", "dev.legacy.eden_emulator", "dev.eden.eden_nightly", "dev.eden.eden_emulator.nightly", "com.miHoYo.Yuanshen"],
          args: "-n {pkg}/org.yuzu.yuzu_emu.activities.EmulationActivity -a android.nfc.action.TECH_DISCOVERED -d {file.uri}", note: "Recomendado" },
        { id: "app:citron", type: "app", label: "Citron", pkgs: ["org.citron.citron_emu"],
          args: "-n {pkg}/org.citron.citron_emu.activities.EmulationActivity -a android.nfc.action.TECH_DISCOVERED -d {file.uri}" },
        { id: "app:sudachi", type: "app", label: "Sudachi", pkgs: ["org.sudachi.sudachi_emu"],
          args: "-n {pkg}/org.sudachi.sudachi_emu.activities.EmulationActivity -a android.nfc.action.TECH_DISCOVERED -d {file.uri}" },
        { id: "app:yuzu", type: "app", label: "Yuzu", pkgs: ["org.yuzu.yuzu_emu"],
          args: "-n {pkg}/org.yuzu.yuzu_emu.activities.EmulationActivity -a android.nfc.action.TECH_DISCOVERED -d {file.uri}" }
      ] }
];

// Pastas comuns onde as pessoas guardam jogos (procuradas no armazenamento interno)
var ROOT_HINTS = ["jogos", "roms", "rom", "games", "game", "emulation", "emulacao", "emuladores", "emulators",
                  "retro", "retroarch", "consoles", "videogames"];

// ------------------------------------------------------------------ utilitários

function byKey(key) {
    for (var i = 0; i < SYSTEMS.length; i++) if (SYSTEMS[i].key === key) return SYSTEMS[i];
    return null;
}

var ACCENTS = { "á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a", "é": "e", "ê": "e", "è": "e", "ë": "e",
                "í": "i", "ì": "i", "î": "i", "ï": "i", "ó": "o", "ò": "o", "ô": "o", "õ": "o", "ö": "o",
                "ú": "u", "ù": "u", "û": "u", "ü": "u", "ç": "c", "ñ": "n" };

// "Super Nintendo (SNES)" -> "supernintendosnes" · "Emulação" -> "emulacao"
function squash(name) {
    return String(name || "").toLowerCase()
        .replace(/[áàâãäéêèëíìîïóòôõöúùûüçñ]/g, function (c) { return ACCENTS[c]; })
        .replace(/[^a-z0-9]/g, "");
}

// Primeiro pacote do RetroArch instalado (na ordem de preferência) ou ""
function retroarchPackage(installed) {
    for (var i = 0; i < RETROARCH.length; i++) if (installed[RETROARCH[i].pkg]) return RETROARCH[i].pkg;
    return "";
}

function installedPackage(emu, installed) {
    if (emu.type === "ra") return retroarchPackage(installed);
    for (var i = 0; i < emu.pkgs.length; i++) if (installed[emu.pkgs[i]]) return emu.pkgs[i];
    return "";
}

function isInstalled(emu, installed) { return installedPackage(emu, installed) !== ""; }

function emuLabel(emu) { return emu.type === "ra" ? "RetroArch · " + emu.label : emu.label; }

function findEmu(sys, id) {
    for (var i = 0; i < sys.emus.length; i++) if (sys.emus[i].id === id) return sys.emus[i];
    return null;
}

// Emulador que vale para o console: a escolha da pessoa (se ainda estiver instalado),
// senão o primeiro instalado da lista (a lista já está em ordem de recomendação),
// senão o recomendado (para o aviso dizer o que instalar).
function effectiveEmu(sys, choiceId, installed) {
    var chosen = choiceId ? findEmu(sys, choiceId) : null;
    if (chosen && isInstalled(chosen, installed)) return chosen;
    for (var i = 0; i < sys.emus.length; i++) if (isInstalled(sys.emus[i], installed)) return sys.emus[i];
    return chosen || sys.emus[0];
}

function launchCommand(emu, installed) {
    if (emu.type === "ra") {
        var pkg = retroarchPackage(installed) || RETROARCH[0].pkg;
        return "am start --user 0\n" +
               "  -n " + pkg + "/com.retroarch.browser.retroactivity.RetroActivityFuture\n" +
               "  -e ROM {file.path}\n" +
               "  -e LIBRETRO " + emu.core + "\n" +
               "  -e CONFIGFILE /storage/emulated/0/Android/data/" + pkg + "/files/retroarch.cfg\n" +
               "  -e QUITFOCUS 1\n" +
               "  --activity-clear-task --activity-clear-top --activity-no-history";
    }
    var p = installedPackage(emu, installed) || emu.pkgs[0];
    var parts = emu.args.replace(/\{pkg\}/g, p).split(/\s+(?=-)/);
    return "am start --user 0\n  " + parts.join("\n  ");
}

// O que falta para o console funcionar (texto curto para a tela de configuração)
function setupHint(sys, emu, installed) {
    if (emu.type === "ra") {
        if (!retroarchPackage(installed))
            return "Instale o RetroArch (retroarch.com › Android › versão AArch64) e baixe o núcleo " + emu.label + ".";
        return "Este emulador usa o núcleo " + emu.label + " do RetroArch. Se o jogo não abrir, baixe o núcleo no RetroArch: Menu › Online Updater › Core Downloader.";
    }
    if (!installedPackage(emu, installed)) return "Instale o " + emu.label + " para jogar " + sys.name + ".";
    return "";
}

// ------------------------------------------------------------------ pastas

// Acha a pasta de cada console dentro das pastas dadas.
// listDirs(path) -> nomes das subpastas. Retorna { snes: "/storage/.../SNES", ... }
function detectFolders(roots, listDirs) {
    var found = {};
    var aliasMap = {};
    SYSTEMS.forEach(function (s) { s.aliases.forEach(function (a) { aliasMap[a] = s.key; }); });

    function scan(dir, depth) {
        var names = listDirs(dir) || [];
        for (var i = 0; i < names.length; i++) {
            var key = folderKey(names[i], aliasMap);
            var full = dir.replace(/\/+$/, "") + "/" + names[i];
            if (key) { if (!found[key]) found[key] = full; continue; }
            if (depth > 0) scan(full, depth - 1);
        }
    }
    roots.forEach(function (r) { scan(r, 1); });
    return found;
}

// "Super Nintendo (SNES)", "Nintendo - Game Boy Advance", "[PS2] Jogos" -> chave do console ou ""
function folderKey(name, aliasMap) {
    var raw = String(name || "");
    var tries = [raw, raw.replace(/[\(\[][^\)\]]*[\)\]]/g, "")];
    var inside = raw.match(/[\(\[]([^\)\]]*)[\)\]]/g) || [];
    inside.forEach(function (m) { tries.push(m.slice(1, -1)); });
    for (var i = 0; i < tries.length; i++) {
        var k = squash(tries[i]);
        if (aliasMap[k]) return aliasMap[k];
        var noVendor = k.replace(/^(nintendo|sega|sony)/, "");
        if (noVendor !== k && aliasMap[noVendor]) return aliasMap[noVendor];
    }
    return "";
}

// Pastas do armazenamento que parecem guardar jogos (Jogos, ROMs, Emulation...)
function candidateRoots(storageRoot, listDirs) {
    var out = [];
    var names = listDirs(storageRoot) || [];
    for (var i = 0; i < names.length; i++) {
        var n = squash(names[i]);
        for (var j = 0; j < ROOT_HINTS.length; j++) {
            if (n.indexOf(ROOT_HINTS[j]) === 0) { out.push(storageRoot.replace(/\/+$/, "") + "/" + names[i]); break; }
        }
    }
    return out;
}

// ------------------------------------------------------------------ arquivo do Pegasus

var HEADER = "# P7STATION-GERADO v2\n" +
             "# Este arquivo é refeito pelo P7 Station a cada abertura, a partir das\n" +
             "# configurações de Consoles e emuladores. Mudanças feitas à mão aqui se perdem.\n";

// folders: { key: path } · choices: { key: emuId } · installed: { pkg: true }
function buildMetadata(folders, choices, installed) {
    var out = [HEADER];
    SYSTEMS.forEach(function (s) {
        var dir = folders[s.key];
        if (!dir) return;
        var emu = effectiveEmu(s, choices[s.key], installed);
        out.push("");
        out.push("collection: " + s.name);
        out.push("shortname: " + s.key);
        out.push("directories: " + dir);
        out.push("extensions: " + s.exts.join(", "));
        out.push("launch: " + launchCommand(emu, installed));
    });
    return out.join("\n") + "\n";
}

function toSet(list) {
    var set = {};
    (list || []).forEach(function (p) { set[p] = true; });
    return set;
}

// ------------------------------------------------------------------ Switch: emuladores achados no aparelho
// Os emuladores de Switch são quase todos derivados do yuzu e trocam de nome toda hora (Eden,
// Citron, Nyushu...). O app procura no aparelho qualquer um deles (pela tela de jogo,
// <algo>_emu.activities.EmulationActivity) e coloca na lista do Switch com o nome que o próprio
// app mostra. Os achados que não estão na lista fixa entram primeiro: se a pessoa instalou,
// é porque quer usar (o mais atualizado por último vem antes).
// found: [{ pkg, activity, label, updated }]
var FORK_ARGS = "-a android.nfc.action.TECH_DISCOVERED -d {file.uri}";

// já está na lista fixa: mesmo pacote, mesma tela de jogo e o nome do app bate
// (um app com outro nome usando o mesmo pacote entra separado, com o nome dele)
function knownPair(sys, pkg, activity, label) {
    for (var i = 0; i < sys.emus.length; i++) {
        var e = sys.emus[i];
        if (e.type !== "app" || e.fork || e.pkgs.indexOf(pkg) === -1) continue;
        if (label && squash(label).indexOf(squash(e.label)) === -1) continue;
        if (String(e.args).indexOf("{pkg}/" + activity + " ") !== -1) return true;
    }
    return false;
}

function registerSwitchEmus(found) {
    var sys = byKey("switch");
    if (!sys) return [];
    sys.emus = sys.emus.filter(function (e) { return !e.fork; });
    var list = (found || []).filter(function (f) { return f && f.pkg && f.activity && !knownPair(sys, f.pkg, f.activity, f.label); });
    list.sort(function (a, b) { return (Number(b.updated) || 0) - (Number(a.updated) || 0); });
    var added = list.map(function (f) {
        return { id: "app:fork:" + f.pkg, type: "app", fork: true, label: f.label || f.pkg, pkgs: [f.pkg],
                 args: "-n {pkg}/" + f.activity + " " + FORK_ARGS, note: "Instalado neste tablet" };
    });
    sys.emus = added.concat(sys.emus);
    return added;
}
