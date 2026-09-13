#!/bin/zsh
# Bucles H3 nativos en HD (.godot/video/hd/*.mp4, 1120x768 con audio) → Theora + OGG para Godot.
cd "$(dirname "$0")/.."
mkdir -p assets/video/desk_tuesday
for v in .godot/video/hd/*.mp4; do
  n=$(basename "$v" .mp4)
  ffmpeg2theora -v 9 --noaudio -o "assets/video/desk_tuesday/$n.ogv" "$v" >/dev/null 2>&1
  /opt/homebrew/bin/ffmpeg -y -loglevel error -i "$v" -vn -ac 2 -ar 44100 -c:a vorbis -strict -2 -q:a 4 "assets/video/desk_tuesday/$n.ogg"
  echo "hd $n"
done
godot --headless --path . --import >/dev/null 2>&1
echo "HD CONVERTIDOS $(ls .godot/video/hd/*.mp4 | wc -l) $(date +%T)"
