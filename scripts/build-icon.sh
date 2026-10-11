#!/bin/bash
set -euo pipefail
foldbar_icon_build="${1:-build}"
foldbar_iconset="$foldbar_icon_build/AppIcon.iconset"
mkdir -p "$foldbar_iconset"
for foldbar_size in 16 32 128 256 512; do
  sips -z "$foldbar_size" "$foldbar_size" Resources/FoldBar.png --out "$foldbar_iconset/icon_${foldbar_size}x${foldbar_size}.png" >/dev/null
  foldbar_double=$((foldbar_size * 2))
  sips -z "$foldbar_double" "$foldbar_double" Resources/FoldBar.png --out "$foldbar_iconset/icon_${foldbar_size}x${foldbar_size}@2x.png" >/dev/null
done
iconutil -c icns "$foldbar_iconset" -o "$foldbar_icon_build/FoldBar.app/Contents/Resources/AppIcon.icns"
