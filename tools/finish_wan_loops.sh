#!/bin/zsh
# Espera al lote de Wan 2.2, convierte cada mp4 a Theora (assets/video/<nivel>/*.ogv, lo único que
# Godot reproduce nativo) y después genera los efectos de sonido con Stable Audio 3 (así los dos
# lotes no se pisan los modelos en la GPU). Los bucles H3 (assets/anim) se conservan.
cd "$(dirname "$0")/.."
LOG=.godot/video/wan_loops.log
while ! grep -q "LOTE WAN TERMINADO" $LOG 2>/dev/null; do sleep 30; done
mkdir -p assets/video/desk_tuesday
for v in .godot/video/wan/*.mp4; do
  n=$(basename "$v" .mp4)
  ffmpeg2theora -v 9 --noaudio -o "assets/video/desk_tuesday/$n.ogv" "$v" >/dev/null 2>&1 && echo "ogv $n"
done
echo "CONVERSION OGV TERMINADA $(ls assets/video/desk_tuesday/*.ogv | wc -l) vídeos $(date +%T)" >> $LOG
HEARTLINE_POD=${HEARTLINE_POD:-tcs1w5s8n5a7kc} python3 tools/gen_sfx.py --batch .godot/sfx/sfx.json >> .godot/sfx/sfx.log 2>&1
echo "LOTE SFX TERMINADO $(date +%T)" >> .godot/sfx/sfx.log
godot --headless --path . --import >/dev/null 2>&1
echo "TODO TERMINADO $(date +%T)" >> $LOG
