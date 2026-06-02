# Architecture

Unrecorded uses a Dart pub workspace monorepo with clear separation between detection logic, radio scanning, UI components, and the Flutter app.

## Packages

### `apps/mobile`

The Flutter mobile app targeting Android and iOS. Uses Riverpod for state management and GoRouter for navigation. Contains screens (scan, alerts, settings) and wires together the packages below.

### `packages/unrecorded_core`

Pure Dart library with no Flutter dependency. Contains:

- **Models** — `DetectedSignal`, `RiskLevel`, `DetectionAssessment`
- **Scoring** — deterministic rule-based `RiskScoringEngine` that evaluates scan snapshots and returns a risk level with plain-English reasons
- **Privacy** — centralised disclaimer text

Because this package has no Flutter dependency it can be tested with `dart test` and reused in CLI tools or server-side analysis.

### `packages/unrecorded_radio`

Scanner abstraction behind a `RadioScanner` interface:

- **`FakeRadioScanner`** — emits realistic sample data for demos, tests, and emulators
- **`BleRadioScanner`** — wraps `flutter_blue_plus` for real BLE scanning on Android/iOS

The app selects the appropriate scanner at runtime. BLE implementation is best-effort; the fake scanner is the default fallback.

### `packages/unrecorded_ui`

Shared Flutter widgets: `RiskBadge`, `PrivacyNoticeCard`, `PrimaryActionButton`, `SignalCard`. Designed to be calm, accessible, and privacy-first.

## Design principles

- Detection is separated from UI so scoring logic is testable without Flutter.
- Platform-specific scanning lives behind an abstract interface so it can be swapped or stubbed.
- The fake scanner ensures the app works immediately in any environment.
- Future native Android (Kotlin) and iOS (Swift) scanner implementations can be added behind the same `RadioScanner` interface.
