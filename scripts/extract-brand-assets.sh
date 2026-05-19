#!/usr/bin/env bash
# Deprecated: brand assets are maintained as SVGs under packages/unrecorded_ui/assets/.
# To refresh launcher PNGs from SVG sources:
#   convert -background none packages/unrecorded_ui/assets/brand/unrecorded-app-icon-accent.svg \
#     -resize 1024x1024 apps/mobile/assets/brand/app_icon_accent.png
#   cd apps/mobile && dart run flutter_launcher_icons
echo "Brand assets live in packages/unrecorded_ui/assets/ (SVG)."
echo "Regenerate platform PNGs manually if SVG sources change — see docs/brand-review.md."
exit 0
