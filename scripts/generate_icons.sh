#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT/assets/icon/earbuds.svg"
OUT="$ROOT/assets/icon"
ANDROID_RES="$ROOT/android/app/src/main/res"
MACOS_ICON="$ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset"
WINDOWS_ICON="$ROOT/windows/runner/resources/app_icon.ico"

# Warm QCY-inspired amber (reference icon honey/goldenrod range).
YELLOW="#FFC107"
EARBUDS="#1A1A1A"
WHITE="#FFFFFF"

mkdir -p "$OUT"

render_earbuds() {
  local size="$1"
  local out="$2"
  rsvg-convert -w "$size" -h "$size" "$SVG" -o "$out"
}

make_composite() {
  local size="$1"
  local out="$2"
  local bud_size=$((size * 55 / 100))
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  render_earbuds "$bud_size" "$tmp_dir/buds.png"

  local radius=$((size / 5))
  local stroke=$((size * 5 / 100))
  magick -size "${size}x${size}" "xc:$YELLOW" \
    -fill none -stroke "$WHITE" -strokewidth "$stroke" \
    -draw "roundrectangle $((stroke / 2)),$((stroke / 2)),$((size - stroke / 2 - 1)),$((size - stroke / 2 - 1)),${radius},${radius}" \
    "$tmp_dir/stage.png"

  magick "$tmp_dir/stage.png" "$tmp_dir/buds.png" -gravity center -compose over -composite \
    "$out"
}

make_foreground() {
  local size="$1"
  local out="$2"
  local bud_size=$((size * 52 / 100))
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  render_earbuds "$bud_size" "$tmp_dir/buds.png"
  magick -size "${size}x${size}" "xc:none" "$tmp_dir/buds.png" -gravity center -compose over -composite \
    "$out"
}

echo "Generating master icon (1024px)..."
make_composite 1024 "$OUT/app_icon.png"

echo "Generating Android mipmaps..."
for spec in "mdpi:48:108" "hdpi:72:162" "xhdpi:96:216" "xxhdpi:144:324" "xxxhdpi:192:432"; do
  IFS=':' read -r density launcher fg <<<"$spec"
  dir="$ANDROID_RES/mipmap-$density"
  mkdir -p "$dir"
  make_composite "$launcher" "$dir/ic_launcher.png"
  make_foreground "$fg" "$dir/ic_launcher_foreground.png"
done

echo "Generating macOS icons..."
for size in 16 32 64 128 256 512 1024; do
  make_composite "$size" "$MACOS_ICON/app_icon_${size}.png"
done

echo "Generating Windows icon..."
WIN_TMP="$(mktemp -d)"
for size in 16 32 48 64 128 256; do
  make_composite "$size" "$WIN_TMP/icon_${size}.png"
done
magick "$WIN_TMP"/icon_16.png "$WIN_TMP"/icon_32.png "$WIN_TMP"/icon_48.png \
  "$WIN_TMP"/icon_64.png "$WIN_TMP"/icon_128.png "$WIN_TMP"/icon_256.png \
  "$WINDOWS_ICON"
rm -rf "$WIN_TMP"

echo "Done."
