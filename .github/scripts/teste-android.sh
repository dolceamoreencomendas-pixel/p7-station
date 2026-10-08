#!/bin/bash
# Teste automático do P7 Station num Android virtual (tablet Pixel C, Android 11).
# Instala o APK, dá a permissão de arquivos, cria jogos de mentira (arquivos vazios, só com o
# nome) e tira prints de cada tela. Tudo vai para a pasta "resultado".
set -x
OUT=resultado
mkdir -p "$OUT"
PKG=com.p7station.app
ACT=org.pegasus_frontend.android.MainActivity

shot() { sleep "${2:-3}"; adb exec-out screencap -p > "$OUT/$1.png"; }
key()  { adb shell input keyevent "$@"; sleep 1.2; }
start_app() { adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1; }
stop_app()  { adb shell am force-stop "$PKG"; sleep 2; }

adb wait-for-device
adb shell settings put global window_animation_scale 0
adb shell wm size > "$OUT/tela.txt"

adb install -r -g apk/*.apk || { echo "FALHOU A INSTALACAO" > "$OUT/erro.txt"; exit 0; }

# 1) primeira abertura SEM a permissão: deve abrir a tela do Android pedindo acesso a arquivos
start_app
shot 01-pede-permissao 6
adb shell appops set --uid "$PKG" MANAGE_EXTERNAL_STORAGE allow
# volta para o app como uma pessoa faria (botão voltar): ele deve seguir sozinho
key KEYCODE_BACK
shot 02-depois-da-permissao 15
adb logcat -d -s P7 pegasus-fe Qt qml default libpegasus-fe_x86_64.so > "$OUT/log-primeira-abertura.txt"
adb shell ls -la /sdcard/Jogos /sdcard/P7Station > "$OUT/pastas-criadas.txt" 2>&1
adb shell cat /sdcard/Jogos/metadata.pegasus.txt > "$OUT/metadata-criado.txt" 2>&1

# 2) jogos de mentira (arquivos vazios) para ver capas, biblioteca e vitrine
mk() { adb shell "touch \"/sdcard/Jogos/$1\""; }
mk "snes/Super Mario World (USA).sfc"
mk "snes/Super Mario Kart (USA).sfc"
mk "snes/Top Gear (USA).sfc"
mk "psx/Crash Bandicoot (USA).chd"
mk "ps2/God of War II (USA).iso"
mk "wiiu/Mario Kart 8 (USA).wua"
mk "switch/Super Mario Odyssey.nsp"
stop_app
start_app
shot 03-inicio 15
key KEYCODE_DPAD_RIGHT
key KEYCODE_DPAD_RIGHT
shot 04-inicio-terceiro-jogo 4
key KEYCODE_F
shot 05-favoritou 2
key KEYCODE_E
shot 06-biblioteca 4
key KEYCODE_I
shot 07-biblioteca-ordenada 3
key KEYCODE_DPAD_UP
key KEYCODE_DPAD_RIGHT
key KEYCODE_DPAD_RIGHT
shot 08-filtro-console 3
key KEYCODE_E
shot 09-trofeus 4
key KEYCODE_ESCAPE
key KEYCODE_DPAD_UP
key KEYCODE_ENTER
shot 10-configuracoes 3
key KEYCODE_ESCAPE
key KEYCODE_ENTER
shot 11-jogar-sem-emulador 5

# registros para achar erros
adb logcat -d > "$OUT/logcat-completo.txt"
grep -E "P7:|pegasus-fe|qml|QML|libpegasus" "$OUT/logcat-completo.txt" > "$OUT/log-app.txt"
adb shell ls -la /sdcard/ /sdcard/Jogos /sdcard/P7Station > "$OUT/pastas-final.txt" 2>&1
grep -i -E "qml|pegasus|p7station|shader|error|fatal" "$OUT/logcat-completo.txt" | tail -400 > "$OUT/logcat-resumo.txt"
adb pull /sdcard/P7Station/lastrun.log "$OUT/lastrun.log" 2>/dev/null
adb shell dumpsys activity activities | grep -E "mResumedActivity|topResumedActivity" > "$OUT/tela-ativa.txt"
ls -la "$OUT"
exit 0
