import QtQuick 2.15

// Biblioteca e serviços de mentira para rodar o tema fora do Pegasus.
QtObject {
    id: m

    property Component gameComp: Component {
        QtObject {
            id: g
            property string title: ""
            property string sys: ""
            property string path: ""
            property var lastPlayed: new Date(0)
            property int playTime: 0
            property bool favorite: false
            property var assets: ({ boxFront: "", poster: "", tile: "", background: "", screenshot: "" })
            property QtObject collections: QtObject {
                property int count: 1
                function get(i) { return { shortName: g.sys, name: g.sys }; }
            }
            property QtObject files: QtObject {
                property int count: 1
                function get(i) { return { path: g.path }; }
            }
            function launch() { console.warn("MOCK: launch " + g.title); }
        }
    }

    function daysAgo(d) { return new Date(Date.now() - d * 86400000); }

    property var games: []
    property var installed: ["com.retroarch", "com.github.stenzek.duckstation", "org.ppsspp.ppsspp", "me.magnum.melonds", "dev.eden.eden_emulator"]
    Component.onCompleted: {
        var spec = [
            ["snes", "Super Mario World (USA).sfc", 1, 7800, false],
            ["snes", "Kirby Super Star (USA).sfc", 3, 12000, true],
            ["psx", "Crash Bandicoot (USA).chd", 5, 3900, false],
            ["switch", "Mario Kart 8 Deluxe.xci", 8, 24000, false],
            ["ps2", "God of War II (USA).iso", 0, 0, false],
            ["n64", "Super Mario 64 (USA).z64", 16, 17700, false],
            ["gba", "Pokemon - Emerald Version (USA, Europe).gba", 30, 33000, true],
            ["snes", "Donkey Kong Country (USA) (Rev 2).sfc", 0, 0, false],
            ["snes", "000 Teste P7.sfc", 0, 0, false],
            ["psx", "Spyro the Dragon (USA).chd", 0, 0, false],
            ["psp", "God of War - Chains of Olympus (USA).iso", 0, 0, false],
            ["nds", "New Super Mario Bros. (USA).nds", 0, 0, false],
            ["genesis", "Sonic The Hedgehog (USA, Europe).md", 0, 0, false],
            ["switch", "Super Mario Odyssey.nsp", 0, 0, false]
        ];
        // tablet novo: nenhum jogo e nenhum emulador
        if (tabletVazio) { spec = []; installed = []; }
        var out = [];
        spec.forEach(function (s) {
            var title = s[1].replace(/\.[^.]+$/, "");
            out.push(gameComp.createObject(m, {
                sys: s[0], title: title, path: "/storage/emulated/0/ROMs/" + s[0] + "/" + s[1],
                lastPlayed: s[2] > 0 ? daysAgo(s[2]) : new Date(0), playTime: s[3], favorite: s[4]
            }));
        });
        games = out;
        allGames.count = out.length;
    }

    property QtObject allGames: QtObject {
        property int count: 0
        function get(i) { return m.games[i]; }
    }

    property QtObject api: QtObject {
        property QtObject allGames: m.allGames
        property QtObject memory: QtObject {
            property var store: ({})
            function has(k) { return store.hasOwnProperty(k); }
            function get(k) { return store[k]; }
            function set(k, v) { store[k] = v; }
            function unset(k) { delete store[k]; }
        }
        property QtObject keys: QtObject {
            function isAccept(e)   { return e.key === Qt.Key_Return || e.key === Qt.Key_Enter; }
            function isCancel(e)   { return e.key === Qt.Key_Escape || e.key === Qt.Key_Backspace; }
            function isDetails(e)  { return e.key === Qt.Key_I; }
            function isFilters(e)  { return e.key === Qt.Key_F; }
            function isPrevPage(e) { return e.key === Qt.Key_Q; }
            function isNextPage(e) { return e.key === Qt.Key_E; }
            function isMenu(e)     { return e.key === Qt.Key_F1; }
        }
    }

    property QtObject internal: QtObject {
        property QtObject scanner: QtObject { property bool running: false }
        property QtObject settings: QtObject { function reloadProviders() { console.warn("MOCK: reloadProviders"); } }
        property QtObject gamepad: QtObject {
            signal connected(int deviceId)
            signal disconnected(int deviceId)
        }
    }

    property QtObject p7: QtObject {
        function storageRoot() { return "/storage/emulated/0"; }
        function installedPackages() { return m.installed; }
        function subdirs(p) { return []; }
        function isDir(p) { return false; }
        function countFiles(p) { return 0; }
        function readText(p) { return ""; }
        function writeText(p, t) { return true; }
        function libraryDir() { return "/tmp"; }
        function introPending() { return false; }
        function introDone() {}
        function controllers() { return tabletVazio ? [] : [{ name: "Sony Interactive Entertainment Wireless Controller", hasBattery: true, level: 72, charging: false }]; }
        function switchCover(t, f) { return ""; }
    }
}
