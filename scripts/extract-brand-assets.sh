#!/usr/bin/env bash
# Extract brand kit assets from the design sheet PNG.
# Requires ImageMagick (convert). Re-run after updating SOURCE or crop coords.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${SOURCE:-$ROOT/apps/mobile/assets/brand/brand-kit-source.png}"

if [[ ! -f "$SOURCE" ]]; then
  # Bootstrap from Cursor assets if not yet copied.
  CURSOR_ASSET="/home/vscode/.cursor/projects/workspace/assets/c__Users_nigel_AppData_Roaming_Cursor_User_workspaceStorage_e592d1e0b75e273d3daf559bd41dc9ad_images_ChatGPT_Image_May_19__2026__04_59_37_PM-eb7ec8ce-627b-4f67-bdd2-95fea84b0043.png"
  mkdir -p "$ROOT/apps/mobile/assets/brand"
  cp "$CURSOR_ASSET" "$SOURCE"
fi

UI_ICONS="$ROOT/packages/unrecorded_ui/assets/icons"
UI_STATUS="$ROOT/packages/unrecorded_ui/assets/status"
UI_BRAND="$ROOT/packages/unrecorded_ui/assets/brand"
MOBILE_BRAND="$ROOT/apps/mobile/assets/brand"

mkdir -p "$UI_ICONS" "$UI_STATUS" "$UI_BRAND" "$MOBILE_BRAND"

crop() {
  local out="$1"
  shift
  convert "$SOURCE" -crop "$@" +repage -trim +repage \
    -background none -gravity center -extent 128x128 \
    -resize 96x96 "$out"
}

crop_raw() {
  local out="$1"
  shift
  convert "$SOURCE" -crop "$@" +repage -trim +repage "$out"
}

# --- Branding (top section, 1024x682 sheet) ---
crop_raw "$UI_BRAND/logo_mark.png" 120x55+80+95
convert "$UI_BRAND/logo_mark.png" -resize 256x256 -background none \
  -gravity center -extent 256x256 "$UI_BRAND/logo_mark.png"

crop_raw "$MOBILE_BRAND/app_icon_light.png" 95x95+545+88
crop_raw "$MOBILE_BRAND/app_icon_dark.png" 95x95+660+88
crop_raw "$MOBILE_BRAND/app_icon_accent.png" 95x95+775+88
convert "$MOBILE_BRAND/app_icon_accent.png" -resize 1024x1024 \
  "$MOBILE_BRAND/app_icon_accent.png"

# --- Icon set: 6 columns x 3 rows (crop 110x110 cells) ---
# Row 1
crop "$UI_ICONS/scan.png"           110x110+35+348
crop "$UI_ICONS/protection.png"     110x110+175+348
crop "$UI_ICONS/alert.png"          110x110+315+348
crop "$UI_ICONS/risk_high.png"      110x110+455+348
crop "$UI_ICONS/risk_medium.png"    110x110+595+348
crop "$UI_ICONS/risk_low.png"       110x110+735+348
# Row 2
crop "$UI_ICONS/device.png"         110x110+35+428
crop "$UI_ICONS/glasses.png"        110x110+175+428
crop "$UI_ICONS/camera.png"         110x110+315+428
crop "$UI_ICONS/signal.png"         110x110+455+428
crop "$UI_ICONS/info.png"           110x110+595+428
crop "$UI_ICONS/settings.png"       110x110+735+428
# Row 3
crop "$UI_ICONS/help.png"           110x110+35+508
crop "$UI_ICONS/privacy.png"        110x110+175+508
crop "$UI_ICONS/history.png"        110x110+315+508
crop "$UI_ICONS/widget.png"         110x110+455+508
crop "$UI_ICONS/share.png"          110x110+595+508
crop "$UI_ICONS/more.png"           110x110+735+508

# --- Status badges (circular, ~95px) ---
crop_raw "$UI_STATUS/protection_on.png"      95x95+35+575
crop_raw "$UI_STATUS/scanning_active.png"    95x95+175+575
crop_raw "$UI_STATUS/scanning_paused.png"    95x95+315+575
crop_raw "$UI_STATUS/high_risk.png"          95x95+455+575
crop_raw "$UI_STATUS/bluetooth_off.png"      95x95+595+575
crop_raw "$UI_STATUS/permissions_needed.png" 95x95+735+575
for f in "$UI_STATUS"/*.png; do
  convert "$f" -resize 96x96 "$f"
done

# --- Navigation icons (reserve for future bottom nav) ---
crop "$UI_ICONS/nav_home.png"     90x90+35+638
crop "$UI_ICONS/nav_alerts.png"   90x90+175+638
crop "$UI_ICONS/nav_devices.png"  90x90+315+638
crop "$UI_ICONS/nav_history.png"  90x90+455+638
crop "$UI_ICONS/nav_help.png"     90x90+595+638
crop "$UI_ICONS/nav_settings.png" 90x90+735+638

cp "$UI_BRAND/logo_mark.png" "$MOBILE_BRAND/logo_mark.png"

echo "Extracted brand assets to:"
echo "  $UI_ICONS"
echo "  $UI_STATUS"
echo "  $UI_BRAND"
echo "  $MOBILE_BRAND"
