#!/bin/bash

set -euo pipefail

SOURCE_ICON="/Users/brenden/Developer/hobby/braver-search/assets/braver-search.png"
ASSET_PATH="Braver Search/Shared (App)/Assets.xcassets/AppIcon.appiconset"
HOST_ICON_PATH="Braver Search/Shared (App)/Resources/Icon.png"
EXTENSION_ICON_PATH="Braver Search/Shared (Extension)/Resources/images"

if [ ! -f "$SOURCE_ICON" ]; then
  echo "Missing source icon: $SOURCE_ICON" >&2
  exit 1
fi

generate_icon() {
  local size="$1"
  local output="$2"
  sips -s format png -z "$size" "$size" "$SOURCE_ICON" --out "$ASSET_PATH/$output" >/dev/null
}

generate_png() {
  local size="$1"
  local output="$2"
  sips -s format png -z "$size" "$size" "$SOURCE_ICON" --out "$output" >/dev/null
}

generate_rounded_png() {
  local size="$1"
  local output="$2"
  local radius=$(( size * 23 / 100 ))

  magick "$SOURCE_ICON" \
    -resize "${size}x${size}" \
    \( -size "${size}x${size}" xc:none -fill white -draw "roundrectangle 0,0,$((size - 1)),$((size - 1)),$radius,$radius" \) \
    -alpha set \
    -compose copyopacity \
    -composite \
    "$output"
}

find "$ASSET_PATH" -maxdepth 1 -type f -name "*.png" -delete

# iPhone
generate_icon 40 "icon-20@2x.png"
generate_icon 60 "icon-20@3x.png"
generate_icon 58 "icon-29@2x.png"
generate_icon 87 "icon-29@3x.png"
generate_icon 80 "icon-40@2x.png"
generate_icon 120 "icon-40@3x.png"
generate_icon 120 "icon-60@2x.png"
generate_icon 180 "icon-60@3x.png"

# iPad
generate_icon 20 "icon-20.png"
generate_icon 40 "icon-20@2x.png"
generate_icon 29 "icon-29.png"
generate_icon 58 "icon-29@2x.png"
generate_icon 40 "icon-40.png"
generate_icon 80 "icon-40@2x.png"
generate_icon 76 "icon-76.png"
generate_icon 152 "icon-76@2x.png"
generate_icon 167 "icon-83.5@2x.png"

# App Store
generate_icon 1024 "icon-1024.png"

# macOS
generate_icon 16 "mac-16.png"
generate_icon 32 "mac-16@2x.png"
generate_icon 32 "mac-32.png"
generate_icon 64 "mac-32@2x.png"
generate_icon 128 "mac-128.png"
generate_icon 256 "mac-128@2x.png"
generate_icon 256 "mac-256.png"
generate_icon 512 "mac-256@2x.png"
generate_icon 512 "mac-512.png"
generate_icon 1024 "mac-512@2x.png"

echo "Generated app icons from $SOURCE_ICON"

# Host app HTML icon
generate_png 384 "$HOST_ICON_PATH"

# Safari extension icons
generate_extension_icon() {
  local size="$1"
  local output="$2"
  generate_rounded_png "$size" "$EXTENSION_ICON_PATH/$output"
}

mkdir -p "$EXTENSION_ICON_PATH"
for size in 16 32 48 64 96 128 256 512 1024 2048; do
  generate_extension_icon "$size" "icon-${size}.png"
done

echo "Generated host and extension icons from $SOURCE_ICON"
