#!/usr/bin/env bash
# Regenerate Android/iOS launcher PNGs from brand SVGs, then run flutter_launcher_icons.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BRAND_UI="$ROOT/packages/unrecorded_ui/assets/brand"
BRAND_APP="$ROOT/apps/mobile/assets/brand"

mkdir -p "$BRAND_APP"

convert -background none -density 384 "$BRAND_UI/unrecorded-app-icon-accent.svg" \
  -resize 1024x1024 "$BRAND_APP/app_icon_accent.png"

convert -background none -density 384 "$BRAND_UI/unrecorded-logo-mark-white.svg" \
  -resize 512x512 "$BRAND_APP/logo_mark_foreground.png"

convert -background none -density 384 "$BRAND_UI/unrecorded-logo-mark.svg" \
  -resize 512x512 "$BRAND_APP/logo_mark.png"

cd "$ROOT/apps/mobile"
dart run flutter_launcher_icons

echo "Done. Reinstall the app on the device/emulator to refresh the launcher icon."
