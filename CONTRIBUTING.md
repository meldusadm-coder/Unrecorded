# Contributing to Unrecorded

Thanks for your interest in contributing.

## Getting started

### Option A: Dev container (Windows-friendly)

With [Docker Desktop](https://www.docker.com/products/docker-desktop/) and [Android Studio](https://developer.android.com/studio) (one AVD created):

```powershell
.\scripts\windows\Start-UnrecordedDev.ps1
```

Reopen the repo in a Dev Container, then follow [docs/devcontainer.md](docs/devcontainer.md).

### Option B: Local Flutter install

```bash
# Clone and enter the repo
git clone https://github.com/YOUR_ORG/unrecorded.git
cd unrecorded

# Install dependencies (requires Flutter SDK >=3.22)
flutter pub get

# Run tests
dart test --reporter expanded           # core package tests
flutter test                            # app + radio widget tests (from apps/mobile)

# Check formatting and analysis
dart format --set-exit-if-changed .
dart analyze

# Build a debug APK
cd apps/mobile && flutter build apk --debug
```

## Contribution rules

### Privacy first

- Do not add analytics, telemetry, or ad SDKs without explicit approval from the maintainers.
- Do not add cloud services or off-device data transmission without explicit approval.
- Scan data must stay on-device by default.

### No fake certainty

- Never claim the app can prove someone is recording.
- Use language like "possible", "may indicate", "potential risk".
- Keep risk explanations understandable to non-technical users.

### Releases

Maintainers shipping app versions: see [docs/release.md](docs/release.md) for versioning and the Android release workflow.

### Keep changes focused

- One concern per PR.
- Add or update tests for scoring logic and privacy-sensitive behaviour.
- Keep docs concise; update them only when behaviour or architecture changes.

### Code style

- Follow `dart format` and the project's `analysis_options.yaml`.
- Prefer plain Dart models unless code generation clearly helps.
- Keep core logic testable without Flutter.
- Keep platform-specific scanning behind interfaces.

## Things not to add without maintainer approval

- Cloud services
- User accounts / authentication
- Analytics or telemetry
- Ad SDKs
- ML-based detection
- Extra AI configuration files
