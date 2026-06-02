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

# Run tests (full suite — matches push to dev and release PR CI)
cd packages/unrecorded_core && dart test --reporter expanded
cd packages/unrecorded_radio && flutter test
cd packages/unrecorded_ui && flutter test
cd apps/mobile && flutter test

# Check formatting and analysis
dart format --set-exit-if-changed .
dart analyze

# Build a debug APK
cd apps/mobile && flutter build apk --debug
```

## AI-assisted contributions

Project-wide rules for humans and AI tools live in **[AGENTS.md](AGENTS.md)**. Use that file in your assistant’s project-instructions setting, or `@AGENTS.md` in chat. Do not add Cursor-, Copilot-, or other vendor-specific rule files to the repo.

## Contribution rules

### Privacy first

- Do not add analytics, telemetry, or ad SDKs without explicit approval from the maintainers.
- Do not add cloud services or off-device data transmission without explicit approval.
- Scan data must stay on-device by default.

### No fake certainty

- Never claim the app can prove someone is recording.
- Use language like "possible", "may indicate", "potential risk".
- Keep risk explanations understandable to non-technical users.

### Git branches

- **`dev`** — integration; open feature PRs here.
- **`main`** — production; merge via `release/*` or `hotfix/*` PRs (see [docs/git-flow.md](docs/git-flow.md)).
- **Merge commits only** for PRs into `main` and for back-merge PRs `main` → `dev`. Do **not** squash those merges (GitHub: “Create a merge commit”).
- Helpers: `./tool/git/start_release_branch.sh`, `./tool/git/preflight_release.sh`, etc. ([tool/git/README.md](tool/git/README.md)).
- AI assistants: step-by-step playbooks in [skills/README.md](skills/README.md) (e.g. “create release”, “branch for issue 42”).

### CI

GitHub Actions uses **tiered** checks: fast path-scoped tests on feature PRs to `dev`, full tests on push to `dev`, and a **release gate** (full tests + copy + debug APK) on `release/*` / `hotfix/*` PRs to `main`. See [docs/ci-testing.md](docs/ci-testing.md).

### Releases

Maintainers shipping app versions: [docs/git-flow.md](docs/git-flow.md) (branching) and [docs/release.md](docs/release.md) (versioning, signing, Android workflow). Before a release PR: `./tool/git/preflight_release.sh`.

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
- Tool-specific AI rule files in the repo (use [AGENTS.md](AGENTS.md) instead)
