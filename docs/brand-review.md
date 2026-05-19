# Brand review (product / design only)

This is not legal trademark clearance — only a lightweight product review for MVP consistency.

## Asset locations

| Path | Contents |
|------|----------|
| `packages/unrecorded_ui/assets/brand/` | Logo marks and app-icon SVG sources |
| `packages/unrecorded_ui/assets/icons/` | Line icons (scan, protection, alert, …) |
| `packages/unrecorded_ui/assets/status/` | Coloured status badges |
| `packages/unrecorded_ui/assets/navigation/` | Bottom-nav icons (reserved) |
| `apps/mobile/assets/brand/` | PNG exports for launcher icons only |
| `docs/brand-colors.json` | Design token reference |

Dart constants: `UnrecordedAssetPaths` in `packages/unrecorded_ui/lib/src/unrecorded_assets.dart`.

## Rendering

- In-app icons use `flutter_svg` via `UnrecordedIcon` and `UnrecordedStatusIcon`.
- `AppLogo` uses `unrecorded-logo-mark.svg` (monochrome variant in dark mode).
- Platform launcher icons are generated from `unrecorded-app-icon-accent.svg`:

```bash
cd apps/mobile && dart run flutter_launcher_icons
```

## Theme

Purple palette via `UnrecordedColors` / `UnrecordedColorScheme` in `packages/unrecorded_ui/lib/src/app_theme.dart`.

## Consistency checklist

- AppBar leading logo on scan, help, and remove-ads screens
- Scan status uses circular status badge SVGs
- Alert cards use brand `alert` icon
- Cards use 12px corner radius via `AppThemeConstants`
- Risk levels use `risk-low` / `risk-medium` / `risk-high` icons

## Product language

Calm privacy utility. Avoid spy/threat language. Use risk, signals, indicators, and "not proof of recording" language.
