# AGENTS.md

## Project summary

Unrecorded is an open-source privacy app for detecting possible nearby smart glasses or wearable recording devices and warning users about potential unwanted recording risk.

## Product truth

Unrecorded alerts users to possible recording risk. It must never claim to prove that someone is recording.

## Repo structure

| Path | Description |
|---|---|
| `apps/mobile` | Flutter app (Android & iOS) — Riverpod + GoRouter |
| `packages/unrecorded_core` | Pure Dart: models, risk scoring engine, privacy disclaimers |
| `packages/unrecorded_radio` | Scanner abstraction: `FakeRadioScanner`, `BleRadioScanner` |
| `packages/unrecorded_ui` | Shared Flutter UI widgets |
| `docs/` | Architecture, detection-limitations, privacy-model |

## Setup commands

```bash
flutter pub get            # install all workspace dependencies
```

## Test commands

```bash
# Core (pure Dart)
cd packages/unrecorded_core && dart test

# Radio package
cd packages/unrecorded_radio && flutter test

# App widget tests
cd apps/mobile && flutter test

# Format + analysis (from repo root)
dart format --set-exit-if-changed .
dart analyze
```

## Build commands

```bash
cd apps/mobile && flutter build apk --debug
```

## Privacy principles

- Prefer local-first processing.
- Do not add cloud services unless explicitly requested.
- Do not add analytics, tracking, or ad SDKs without explicit approval.
- Do not send scan data off-device by default.
- Keep risk explanations understandable to non-technical users.

## Coding principles

- Keep changes small and focused.
- Prefer plain Dart models unless code generation clearly helps.
- Keep core logic testable without Flutter.
- Keep platform-specific scanning behind interfaces.
- Add or update tests for scoring and privacy-sensitive behaviour.
- Keep docs concise and update them only when behaviour or architecture changes.

## Things not to do

- Do not claim recording can be proven.
- Do not add cloud services.
- Do not add telemetry.
- Do not add ad SDKs.
- Do not add accounts/auth.
- Do not add ML detection yet.
- Do not create more AI configuration files.

## Cursor Cloud specific instructions

- Flutter SDK is installed at `/home/ubuntu/flutter`. The PATH is configured in `~/.bashrc`.
- Run `flutter pub get` from the repo root to resolve all workspace packages.
- The `unrecorded_core` package uses `dart test` (no Flutter dependency). The other packages and the app use `flutter test`.
- The fake scanner (`FakeRadioScanner`) is the default; real BLE scanning requires a physical device.
- Android debug APK builds work headless: `cd apps/mobile && flutter build apk --debug`.
- There is no database, no backend, and no external services to start.
