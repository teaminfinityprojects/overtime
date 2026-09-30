#!/bin/sh
# Ficheros que la pantalla de carga (web/shell.html) sirve junto al export de Godot. Van fuera del .pck
# porque se usan antes de que arranque el motor. Ejecutar tras cada export:
#   sh deploy/web_extras.sh [build/web]
set -e
OUT="${1:-build/web}"
cd "$(dirname "$0")/.."
mkdir -p "$OUT/loader" "$OUT/ads"
cp web/metrics.js "$OUT/metrics.js"
cp assets/ui/logo.png "$OUT/loader/logo.png"
cp assets/fonts/Nunito-Regular.ttf "$OUT/loader/Nunito.ttf"
cp data/ads.json "$OUT/loader/ads.json"
find assets/ads -maxdepth 1 -name '*.png' -exec cp {} "$OUT/ads/" \;
echo "web_extras: listo en $OUT"
