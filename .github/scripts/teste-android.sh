#!/bin/bash
# Teste do P7 Station num Android virtual (tablet Pixel C, Android 11), agora com um
# emulador de verdade: instala o RetroArch e o núcleo Snes9x, coloca uma ROM de teste numa
# pasta com nome livre ("ROMs/Super Nintendo") e confere se o P7 Station abre o jogo.
# Tudo (prints e registros) vai para a pasta "resultado".
set -x
OUT=resultado
mkdir -p "$OUT"
PKG=com.p7station.app

shot() { sleep "${2:-3}"; adb exec-out screencap -p > "$OUT/$1.png"; }
key()  { adb shell input keyevent "$@"; sleep 1.2; }
start_app() { adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1; }
stop_app()  { adb shell am force-stop "$PKG"; sleep 2; }
top_activity() { adb shell dumpsys activity activities | grep -E "mResumedActivity|topResumedActivity" | head -2; }

adb wait-for-device
adb root; sleep 3; adb wait-for-device
adb shell settings put global window_animation_scale 0
adb shell getprop ro.product.cpu.abilist > "$OUT/abis.txt"
adb shell wm size > "$OUT/tela.txt"

adb install -r -g apk/*.apk || { echo "FALHOU A INSTALACAO" > "$OUT/erro.txt"; exit 0; }

# ---------------------------------------------------------------- RetroArch
RA_PKG=""
if [ -f emus/RetroArch.apk ]; then
    adb install -r -g emus/RetroArch.apk > "$OUT/retroarch-instalacao.txt" 2>&1
    RA_PKG=$(cat emus/retroarch-pacote.txt)
    adb shell appops set --uid "$RA_PKG" MANAGE_EXTERNAL_STORAGE allow
    # primeira abertura: o RetroArch cria as pastas e extrai os arquivos dele
    adb shell monkey -p "$RA_PKG" -c android.intent.category.LAUNCHER 1
    sleep 25
    shot 00a-retroarch-primeira-abertura 1
    adb shell am force-stop "$RA_PKG"; sleep 2
    RA_UID=$(adb shell stat -c %u "/data/data/$RA_PKG" | tr -d '\r')
    adb shell mkdir -p "/data/data/$RA_PKG/cores"
    adb push emus/snes9x_libretro_android.so "/data/data/$RA_PKG/cores/snes9x_libretro_android.so"
    adb shell chown -R "$RA_UID:$RA_UID" "/data/data/$RA_PKG/cores"
    adb shell chmod 755 "/data/data/$RA_PKG/cores"
    adb shell chmod 644 "/data/data/$RA_PKG/cores/snes9x_libretro_android.so"
    adb shell restorecon -R "/data/data/$RA_PKG/cores" 2>/dev/null
    adb shell ls -laZ "/data/data/$RA_PKG/cores" > "$OUT/retroarch-nucleos.txt" 2>&1
else
    echo "RetroArch não foi baixado" > "$OUT/retroarch-instalacao.txt"
fi

# ---------------------------------------------------------------- jogos
# Pasta com nome livre, como a de quem já tem os jogos organizados: o app deve achar sozinho.
adb shell mkdir -p "/sdcard/ROMs/Super\ Nintendo" /sdcard/ROMs/PS1 /sdcard/ROMs/psp "/sdcard/ROMs/Nintendo\ 64" /sdcard/ROMs/gba
adb push emus/teste.sfc "/sdcard/ROMs/Super Nintendo/000 Teste P7.sfc"
mk() { adb shell "touch \"/sdcard/ROMs/$1\""; }
mk "Super Nintendo/Super Mario World (USA).sfc"
mk "Super Nintendo/Kirby Super Star (USA).sfc"
mk "PS1/Crash Bandicoot (USA).chd"
mk "psp/God of War - Chains of Olympus (USA).iso"
mk "Nintendo 64/Super Mario 64 (USA).z64"
mk "gba/Pokemon - Emerald Version (USA, Europe).gba"

# ---------------------------------------------------------------- P7 Station
start_app
shot 01-pede-permissao 6
adb shell appops set --uid "$PKG" MANAGE_EXTERNAL_STORAGE allow
key KEYCODE_BACK
shot 02-abriu 25
adb shell cat /sdcard/Android/data/$PKG/files/P7Station/biblioteca/metadata.pegasus.txt > "$OUT/metadata-gerado.txt" 2>&1
shot 03-inicio 5
# parado no menu por 22 s: o registro mostra quantos quadros o app desenhou a cada 10 s
sleep 22
shot 03b-parado 1
# segurar Triângulo (favoritar) deve marcar uma vez só, sem ficar piscando
adb shell input keyevent --longpress KEYCODE_F
shot 03c-segurou-triangulo 2

# Consoles e emuladores: engrenagem > primeiro item
key KEYCODE_DPAD_UP
key KEYCODE_ENTER
shot 04-configuracoes 2
key KEYCODE_ENTER
shot 05-consoles 3
key KEYCODE_DPAD_DOWN
key KEYCODE_DPAD_DOWN
shot 06-consoles-snes-selecionado 2
key KEYCODE_ENTER
shot 07-console-snes 2
key KEYCODE_DPAD_DOWN
key KEYCODE_DPAD_RIGHT
shot 08-trocou-emulador 2
key KEYCODE_DPAD_LEFT
shot 09-voltou-snes9x 2
key KEYCODE_DPAD_UP
key KEYCODE_ENTER
shot 10-navegador-de-pastas 2
key KEYCODE_ESCAPE
key KEYCODE_ESCAPE
key KEYCODE_ESCAPE
shot 10b-voltou-ao-console 2
key KEYCODE_ESCAPE
key KEYCODE_ESCAPE
shot 11-fechou-consoles 8

# Biblioteca
key KEYCODE_E
shot 12-biblioteca 4
key KEYCODE_Q
sleep 2

# ---------------------------------------------------------------- abrir o jogo de teste
adb logcat -c
key KEYCODE_ENTER
shot 13-abrindo-jogo 12
shot 14-jogo-rodando 6
top_activity > "$OUT/tela-ativa-no-jogo.txt"
adb logcat -d > "$OUT/logcat-jogo.txt"
grep -iE "P7:|RetroArch|libretro|snes9x|ActivityManager: (START|Displayed)|ActivityTaskManager: (START|Displayed)" "$OUT/logcat-jogo.txt" | head -200 > "$OUT/log-jogo-resumo.txt"

# volta para o P7 Station
adb shell am force-stop "$RA_PKG" 2>/dev/null
start_app
shot 15-voltou 8
# depois de voltar do jogo, o controle tem que andar sem tocar na tela
key KEYCODE_DPAD_RIGHT
key KEYCODE_DPAD_RIGHT
shot 16-navegou-depois-de-voltar 2

# ---------------------------------------------------------------- registros
adb logcat -d > "$OUT/logcat-completo.txt"
grep -E "P7|pegasus-fe|qml|QML" "$OUT/logcat-completo.txt" | grep -v "^--" | tail -300 > "$OUT/log-app.txt"
adb shell ls -laR /sdcard/ROMs > "$OUT/pastas.txt" 2>&1
ls -la "$OUT"
exit 0
