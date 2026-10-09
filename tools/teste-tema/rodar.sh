#!/bin/bash
# Compila o executor e roda o passeio pelo tema numa tela virtual, gravando vídeo.
set -x
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-$HERE/saida}
mkdir -p "$OUT" "$HERE/build"
cd "$HERE/build"
moc ../main.cpp -o main.moc
g++ -std=c++17 -fPIC -O1 -I. ../main.cpp -o tema $(pkg-config --cflags --libs Qt5Quick Qt5Qml Qt5Gui Qt5Core) || exit 1
Xvfb :99 -screen 0 1600x1068x24 >/dev/null 2>&1 &
XV=$!
sleep 2
export DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 QT_QPA_PLATFORM=xcb QSG_RENDER_LOOP=basic
ffmpeg -loglevel error -y -f x11grab -framerate 30 -video_size 1600x1068 -i :99 -c:v libx264 -preset ultrafast -pix_fmt yuv420p "$OUT/passeio.mp4" &
FF=$!
timeout 240 ./tema "$HERE" "$OUT" > "$OUT/registro.txt" 2>&1
echo "saida do tema: $?" >> "$OUT/registro.txt"
kill -INT $FF; sleep 2
kill $XV
cd "$OUT"
# folhas de contato das animações (uma imagem por animação)
for a in 10-cartucho 20-disco 30-cartao 66-abrir-biblioteca; do
  ls ${a}-*.png >/dev/null 2>&1 && ffmpeg -loglevel error -y -pattern_type glob -i "${a}-*.png" -vf "scale=400:-1,tile=5x5:padding=4" -frames:v 1 "folha-${a}.png"
done
ls -la
