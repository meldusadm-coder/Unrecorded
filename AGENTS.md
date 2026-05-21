# AGENTS.md

Canonical instructions for **any** AI coding assistant (Cursor, GitHub Copilot, Claude Code, Codex, Gemini CLI, etc.). Humans contributing with or without AI should follow the same rules in [CONTRIBUTING.md](CONTRIBUTING.md).

Do **not** commit tool-specific rule files (for example `.cursor/rules/`, `CLAUDE.md`, `.github/copilot-instructions.md`). If your editor supports local overrides, keep them on your machine or add `.cursor/` locally (it is gitignored).

## Project summary

Unrecorded is an open-source privacy app for detecting possible nearby smart glasses or wearable recording devices and warning users about potential unwanted recording risk.

## Product truth

Unrecorded alerts users to possible recording risk. It must never claim to prove that someone is recording.

## Repo structure

| Path | Description |
|---|---|
| `apps/mobile` | Flutter app (Android & iOS) — Riverpod + GoRouter |
| `apps/site` | Static site for [unrecorded.app](https://unrecorded.app) (landing + privacy policy) |
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

## Agent workflow

- Keep edits small, testable, and privacy-first.
- When changing detection, scoring, permissions, or privacy-sensitive behaviour, update the relevant tests and concise docs.

## Things not to do

- Do not claim recording can be proven.
- Do not add cloud services.
- Do not add telemetry.
- Do not add ad SDKs.
- Do not add accounts/auth.
- Do not add ML detection yet.
- Do not add committed tool-specific AI rule/config files; extend this file instead.

## Dev container

- Use the repo [`.devcontainer/`](.devcontainer/) (Flutter stable at `/sdks/flutter`, Android SDK at `/opt/android-sdk`).
- Run `flutter pub get` from the repo root (`/workspace`) after the container is created.
- On Windows, run `start-dev.cmd` on the host, then `./scripts/dev-run.sh` inside the container. See [docs/devcontainer.md](docs/devcontainer.md).
- The `unrecorded_core` package uses `dart test` (no Flutter dependency). The other packages and the app use `flutter test`.
- The fake scanner (`FakeRadioScanner`) is the default; real BLE scanning requires a physical device.
- Android debug APK builds work headless: `cd apps/mobile && flutter build apk --debug`.
- There is no database, no backend, and no external services to start.
