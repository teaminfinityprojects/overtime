#!/bin/zsh
# Descarga iconos de Tabler (MIT) a assets/icons/ y pone el trazo en blanco para que Godot
# los pueda tintar por código: ./tools/add_icon.sh search phone [filled/heart]
cd "$(dirname "$0")/.."
for n in "$@"; do
  case "$n" in filled/*) url="https://cdn.jsdelivr.net/npm/@tabler/icons@3.30.0/icons/$n.svg"; out="assets/icons/${n#filled/}-filled.svg";;
              *)        url="https://cdn.jsdelivr.net/npm/@tabler/icons@3.30.0/icons/outline/$n.svg"; out="assets/icons/$n.svg";; esac
  curl -sL --max-time 20 -o "$out" "$url" && sed -i '' 's/currentColor/#ffffff/g' "$out" && echo "$out"
done
