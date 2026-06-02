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
| `apps/site` | Static marketing and privacy policy site for [unrecorded.app](https://unrecorded.app) |
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

# Demo / UAT on emulator (scripted BLE, deterministic alerts)
./scripts/dev-run-demo.sh
# or: flutter run --dart-define=UNRECORDED_DEMO_MODE=true --dart-define=UNRECORDED_DEMO_SCENARIO=high

# Or build a debug APK
cd apps/mobile && flutter build apk --debug
```

See [docs/local-testing.md](docs/local-testing.md) for BLE vs demo mode, debug settings, and UAT checklists.

### Dev container (recommended on Windows)

Use a [Dev Container](docs/devcontainer.md) for Flutter, Dart, Android SDK, and CI-parity tooling without installing Flutter on the host.

**Windows (Android Studio + Docker Desktop installed):**

```powershell
.\scripts\windows\Start-UnrecordedDev.ps1
# or double-click: start-dev.cmd
```

Then open the repo in Cursor → **Dev Containers: Reopen in Container**, then run `./scripts/dev-run.sh` inside the container. See [docs/devcontainer.md](docs/devcontainer.md) for details.

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

## CI/CD test automation (no paid device farm required)

GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs **tiered** checks:

- **Feature PR → `dev`:** format, analyze, and path-scoped package tests (faster feedback).
- **Push to `dev`:** full unit/widget suite (core, radio, ui, mobile).
- **`release/*` / `hotfix/*` PR → `main`:** full suite plus release copy checks and a debug APK build.
- **Ship on `main`:** [Release Android](.github/workflows/release-android.yml) builds and uploads; unit tests already passed on the release PR.

Scan and scoring tests use fake/scripted scanners — no physical glasses or emulator farm required. Details: [docs/ci-testing.md](docs/ci-testing.md).

## Releases

Maintainers: see [docs/release.md](docs/release.md) for versioning, signed Android App Bundle builds, GitHub Releases, and optional Google Play upload.

## Privacy model

All scanning is local. No account, no cloud, no analytics. See [docs/privacy-model.md](docs/privacy-model.md).

## Monetisation and widget

Optional bottom banner ads and pay-what-you-want remove-ads IAP are documented in [docs/monetisation.md](docs/monetisation.md). Android home screen widget notes: [docs/widget.md](docs/widget.md).

## Funding

See [FUNDING.md](FUNDING.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). AI coding assistants should follow [AGENTS.md](AGENTS.md) (tool-agnostic; no vendor-specific rule files in the repo).

## Licence

[MPL-2.0](LICENSE)
