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
| `docs/` | Architecture, detection-limitations, privacy-model, git-flow, release |
| `skills/` | Agent-agnostic step-by-step playbooks (release, feature branch, hotfix) |
| `tool/git/` | Branching helpers: release/hotfix/feature branches, preflight, back-merge |
| `tool/release/` | Version bump, copy checks, release notes for CI |

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

## Git workflow

Branching model: **`dev`** (integration) → **`release/*` or `hotfix/*`** → **`main`** (shipped) → back-merge to **`dev`**. Do not push directly to `dev` or `main`.

**Merge policy (required):** PRs into **`main`** and back-merge PRs into **`dev`** must use a **merge commit**, never squash or rebase merge. Squash merges break `main`/`dev` ancestry and leave misleading ahead/behind counts even when trees match. See [docs/git-flow.md](docs/git-flow.md).

### User phrases → playbooks

When the user asks for git/release work, **read the matching skill in full** and follow it step by step ([skills/README.md](skills/README.md)):

| User says (examples) | Read first |
|----------------------|------------|
| create release, start release, prepare release | [skills/create-release/SKILL.md](skills/create-release/SKILL.md) |
| ship release, publish, run release workflow | [skills/ship-release/SKILL.md](skills/ship-release/SKILL.md) |
| branch for issue N, feature branch from issue | [skills/create-feature-branch/SKILL.md](skills/create-feature-branch/SKILL.md) |
| hotfix, patch production | [skills/hotfix/SKILL.md](skills/hotfix/SKILL.md) |
| backmerge, sync main to dev | [skills/backmerge/SKILL.md](skills/backmerge/SKILL.md) |
| release status, dev vs main | [skills/release-status/SKILL.md](skills/release-status/SKILL.md) |

Run shell commands from the skill; report after each step; ask before push/merge/workflow dispatch unless the user already approved.

### Quick reference

| Task | Command / doc |
|------|----------------|
| Feature from issue | `./tool/git/start_feature_branch.sh <issue#>` |
| Start release | `./tool/git/start_release_branch.sh <version> [build]` — [docs/git-flow.md](docs/git-flow.md) |
| Preflight | `./tool/git/preflight_release.sh` |
| Open PR to `main` | `./tool/git/open_release_pr.sh` |
| Ship build | **Release Android** auto on `main` after version bump merge — [docs/release.md](docs/release.md) |
| Sync after ship | `./tool/git/backmerge_main_to_dev.sh` |
| Status | `./tool/git/release_status.sh` |

Never run the release workflow from `dev` while `main` is behind production. Never reuse a published Android `version_code`. Never squash-merge into `main` or squash-merge a `main` → `dev` back-merge PR.

## Agent workflow

- Keep edits small, testable, and privacy-first.
- When changing detection, scoring, permissions, or privacy-sensitive behaviour, update the relevant tests and concise docs.
- For release-related edits: use a `release/*` or `hotfix/*` branch (not direct commits intended only for `main`), update `CHANGELOG.md`, run `./tool/git/preflight_release.sh`, and follow [docs/git-flow.md](docs/git-flow.md).

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
