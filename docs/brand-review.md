# Brand review (product / design only)

This is not legal trademark clearance — only a lightweight product review for MVP consistency.

## Current state

- In-app mark: `AppLogo` widget (stylised “U” with signal arc) in `packages/unrecorded_ui`.
- Theme seed: indigo `0xFF5C6BC0` (Material 3).
- Platform launcher icons may still be default Flutter placeholders until `flutter_launcher_icons` is run with a custom asset.

## Uniqueness

- The mark avoids a generic shield-only security-app look.
- It does not closely mimic major consumer app logos.
- At small sizes (AppBar, widget), the “U” + arc remains readable in light and dark mode.

## Consistency checklist

- AppBar leading logo on scan, help, and remove-ads screens
- Alert cards use shared `RiskAlertCard` styling
- Cards use 12px corner radius via `AppThemeConstants`
- Helper text uses muted `bodySmall` styling

## Optional follow-up

- Add `apps/mobile/assets/brand/icon.png` and run `flutter_launcher_icons` for store builds.
- Subtle splash screen with the same mark (no full rebrand required).
