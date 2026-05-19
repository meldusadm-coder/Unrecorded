# Home screen widget (Android MVP)

## What it shows

- Primary status line (e.g. “Scanning active”, “Possible risk nearby”)
- Secondary line (e.g. “No obvious risk”, last-checked hint)
- Tap opens the app

## Data stored

Only enum-mapped status strings and last-checked time — **no** device names, MAC addresses, or scan payloads. See `WidgetSyncService` in `apps/mobile/lib/services/widget_sync_service.dart`.

## Platform limits

- **Android:** Implemented via `home_widget` + `UnrecordedWidgetProvider`.
- **iOS:** Not in MVP — requires WidgetKit extension and app group setup. Track as follow-up.
- **Battery:** Widget updates when app scan state changes; provider `updatePeriodMillis` is 30 minutes minimum for passive refresh.

## Testing

Add the widget on a physical Android device after installing a debug build. Turn protection on/off in the app and confirm lines update.

## Follow-up issue

- iOS home screen widget
- Deep link to permission settings when status is “Permissions needed”
