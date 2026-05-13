# Unrecorded

Unrecorded is an open-source privacy app that detects possible smart glasses or wearable recording devices nearby and alerts you to potential unwanted recording risk.

> **Important:** Unrecorded cannot prove that a person is recording you. It detects nearby signals and patterns that may indicate smart glasses or wearable recording devices, then presents a privacy-risk warning.

## Status

Early prototype. The app includes a working scan screen with fake/demo data, deterministic risk scoring, and an initial BLE scanning path.

## What it does

- Scans for nearby Bluetooth Low Energy (BLE) signals.
- Compares signals against patterns associated with known smart glasses and wearable recording devices.
- Presents a privacy-risk level (low / medium / high) with plain-English explanations.
- Works immediately with built-in demo data when BLE hardware is unavailable.

## What it does not do

- Prove that any device is recording.
- Detect non-Bluetooth cameras or microphones.
- Guarantee detection of all smart glasses (device names can be hidden or randomised).
- Upload any data off your device.

## Why detection is probabilistic

Bluetooth signals can be hidden, randomised, or spoofed. Signal strength is noisy. Smart glasses may not advertise recognisable names. For these reasons, Unrecorded provides risk indicators — never certainty. See [docs/detection-limitations.md](docs/detection-limitations.md) for details.

## Architecture

A Dart pub workspace monorepo:

| Path | Description |
|---|---|
| `apps/mobile` | Flutter app (Android & iOS) |
| `packages/unrecorded_core` | Pure Dart: models, risk scoring, privacy text |
| `packages/unrecorded_radio` | Scanner abstraction: fake + BLE implementations |
| `packages/unrecorded_ui` | Shared Flutter widgets |

See [docs/architecture.md](docs/architecture.md) for more detail.

## Local development

Requires Flutter SDK >=3.22 (with Dart >=3.6).

```bash
# Install dependencies
flutter pub get

# Run the app (in apps/mobile)
cd apps/mobile && flutter run

# Or build a debug APK
cd apps/mobile && flutter build apk --debug
```

## Running tests

```bash
# Core package unit tests (from repo root)
cd packages/unrecorded_core && dart test

# Radio package tests
cd packages/unrecorded_radio && flutter test

# App widget tests
cd apps/mobile && flutter test

# Format check
dart format --set-exit-if-changed .

# Static analysis
dart analyze
```

## Privacy model

All scanning is local. No account, no cloud, no analytics. See [docs/privacy-model.md](docs/privacy-model.md).

## Funding

See [FUNDING.md](FUNDING.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Licence

[MPL-2.0](LICENSE)
