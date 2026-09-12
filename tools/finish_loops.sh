#!/bin/zsh
# Espera a que termine el lote de bucles y convierte cada mp4 en spritesheet + ogg para Godot.
cd "$(dirname "$0")/.."
while ! grep -q "LOTE TERMINADO" .godot/video/loops.log 2>/dev/null; do sleep 30; done
for v in .godot/video/*.mp4; do
  n=$(basename "$v" .mp4)
  case "$n" in _*|*_v2|*_turbo) continue;; esac
  python3 tools/video_to_sheet.py "$v" "assets/anim/desk_tuesday/$n" --fps 12 --width 704
done
godot --headless --import >/dev/null 2>&1
echo "CONVERSION TERMINADA $(ls assets/anim/desk_tuesday/*.png | wc -l) bucles" >> .godot/video/loops.log
