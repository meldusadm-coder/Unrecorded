# Brand review (product / design only)

This is not legal trademark clearance — only a lightweight product review for MVP consistency.

## Current state

- In-app mark: `AppLogo` widget loads `logo_mark.png` from `packages/unrecorded_ui/assets/brand/`.
- UI icons: 18 line icons + 6 status badges in `packages/unrecorded_ui/assets/`, rendered via `UnrecordedIcon` and `UnrecordedStatusIcon`.
- Theme: purple brand palette (`#5B4DFF` primary) via `UnrecordedColors` and `UnrecordedColorScheme` in `packages/unrecorded_ui`.
- Platform icons: generated with `flutter_launcher_icons` from `apps/mobile/assets/brand/app_icon_accent.png`.
- Splash: Android `launch_background.xml` and iOS `LaunchImage` use the shield logo on brand surface/background colours.

## Asset pipeline

Re-extract icons from the design sheet after updating crop coordinates:

```bash
./scripts/extract-brand-assets.sh
cd apps/mobile && dart run flutter_launcher_icons
```

Source sheet is stored at `apps/mobile/assets/brand/brand-kit-source.png`.

## Uniqueness

- The mark avoids a generic shield-only security-app look.
- It does not closely mimic major consumer app logos.
- At small sizes (AppBar, widget), the shield + eye mark remains readable in light and dark mode.

## Consistency checklist

- AppBar leading logo on scan, help, and remove-ads screens
- Scan status uses pre-rendered circular status badges from the brand kit
- Alert cards use shared `RiskAlertCard` styling with brand `alert` icon
- Cards use 12px corner radius via `AppThemeConstants`
- Helper text uses muted `bodySmall` styling
- Risk levels use `risk_low` / `risk_medium` / `risk_high` icons with semantic colours

## Reserved assets

Navigation icons (`nav_home`, `nav_alerts`, etc.) are extracted but not wired — the app uses GoRouter without a bottom navigation bar.
