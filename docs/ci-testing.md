# CI and test tiers

GitHub Actions runs **tiered** checks so feature work stays fast while releases keep full hardware-free coverage. Local parity: `./tool/git/preflight_release.sh` before opening a `release/*` or `hotfix/*` PR.

Workflow: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml). Android ship: [`.github/workflows/release-android.yml`](../.github/workflows/release-android.yml).

The **`dev` branch ruleset** requires the GitHub status context **`Analyze & Test`**. CI reports that via a final aggregator job after lint and package tests (individual jobs keep descriptive names).

## When each tier runs

| Event | Format + analyze | Package tests | Release gate (copy + debug APK) |
|-------|------------------|---------------|----------------------------------|
| PR → `dev` (feature) | Always | **Path-scoped** (see below) | No |
| Push to `dev` (after merge) | Always | **Full** (core, radio, ui, mobile) | No |
| PR → `main` (`release/*`, `hotfix/*`) | Always | **Full** | **Yes** |
| PR → `main` (other, e.g. back-merge typo) | Always | **Full** | No (unless head is `release/*` / `hotfix/*`) |
| Push to `main` (version bump merge) | Always | Skipped (already gated on release PR) | N/A |
| **Release Android** on `main` | Yes | No (re-run on PR) | Copy check + signed AAB build |

There is **no** Android emulator job in CI. Scan tests use `FakeRadioScanner` / `ScriptedRadioScanner` and do not need hardware.

## Path-scoped tests (PR → `dev`)

Downstream packages run when an upstream package changes:

| Changed paths | Tests run |
|---------------|-----------|
| `packages/unrecorded_core/**` or workspace `pubspec` / workflow files | core, radio, ui, mobile |
| `packages/unrecorded_radio/**` | radio, mobile |
| `packages/unrecorded_ui/**` | ui, mobile |
| `apps/mobile/**` | mobile only |
| Docs / site only | lint only |

Before merging scan/scoring work, run the full suite locally or wait for the **push to `dev`** integration job.

## Local commands

```bash
flutter pub get
dart format --set-exit-if-changed .
dart analyze --fatal-infos

# Full suite (matches dev push + release PR)
cd packages/unrecorded_core && dart test
cd packages/unrecorded_radio && flutter test
cd packages/unrecorded_ui && flutter test
cd apps/mobile && flutter test

# Release branch PR (also runs in CI release-gate)
./tool/git/preflight_release.sh
cd apps/mobile && flutter build apk --debug
```

If `dart test` fails on `pubspec.lock` mtime in some containers, use `flutter test` in `packages/unrecorded_core` instead.

## Agents and releases

- **Feature PR → `dev`:** fast CI is enough for merge if paths match; run extra packages locally when touching detection/scoring.
- **`release/*` / `hotfix/*` PR → `main`:** must pass **full tests + release gate** in CI; run `preflight_release.sh` before opening the PR.
- **After merge to `main`:** Release Android workflow ships the build; it does not re-run unit tests. Do not skip the release PR gate.

See [git-flow.md](git-flow.md) and [skills/create-release/SKILL.md](../skills/create-release/SKILL.md).
