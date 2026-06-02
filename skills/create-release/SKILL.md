---
name: create-release
description: >-
  Walk through cutting a Unrecorded release branch from dev, version bump,
  CHANGELOG, preflight, and PR to main. Use when the user says create release,
  start release, new release, release branch, prepare release, ship version
  (before merge), or bump version for Play Store.
---

# Create release

Interactive playbook. Execute **one step at a time**, show command output, then continue unless the user says to stop.

## Before you start

1. Read [docs/git-flow.md](../../docs/git-flow.md) if unsure about branch rules.
2. Run from repo root (`/workspace` or clone root).
3. Do **not** push to `dev` or `main` directly.

## Step 0 — Situation check

```bash
./tool/git/release_status.sh
./tool/release/verify_version.sh
```

Tell the user:

- Current branch
- `app_version` / suggested next `version_name` + `build_number` (build must be **greater** than any published Android `version_code`)
- How far `dev` is ahead of `main`

If `dev` is not ready (open PRs, failing CI), say so and ask whether to proceed.

## Step 1 — Confirm version

Ask if not provided:

- **version_name** — semver `MAJOR.MINOR.PATCH` (e.g. `0.2.0`)
- **build_number** — integer Android `versionCode` / iOS build (e.g. `3`)

Rules:

- Never reuse a build number already on Play Store.
- Prefer `./tool/git/start_release_branch.sh <version_name> <build_number>` which bumps `pubspec.yaml` and adds a `CHANGELOG.md` section.

## Step 2 — Cut release branch

Requires clean working tree (or user approves `--allow-dirty`).

```bash
./tool/git/start_release_branch.sh <version_name> <build_number>
```

You should now be on `release/<version_name>`.

If the user only wanted a branch without bump:

```bash
./tool/git/start_release_branch.sh <version_name>
```

## Step 3 — CHANGELOG and release-only fixes

1. Open `CHANGELOG.md` — fill the `## <version>+<build>` section (Added / Changed / Fixed).
2. Apply any **release-only** tweaks on this branch (copy, version strings, last-minute fixes).
3. Commit with a clear message, e.g. `release: prepare 0.2.0+3`.

Do **not** put unrelated feature work on `release/*`.

## Step 4 — Preflight

```bash
./tool/git/preflight_release.sh
```

If tests are slow and the user agrees:

```bash
./tool/git/preflight_release.sh --skip-tests
```

Fix failures before opening the PR. Re-run preflight after fixes.

CI on the release PR will run the **full** test suite plus the **release gate** job (copy guardrails, `verify_version`, debug APK). That gate must be green before merge. See [docs/ci-testing.md](../../docs/ci-testing.md).

Do **not** use `preflight_release.sh --skip-tests` unless the user explicitly agrees and the same commit already passed full CI.

## Step 5 — Open PR to `main`

```bash
./tool/git/open_release_pr.sh
```

If `gh` is missing, give the user the printed compare URL and suggested PR title.

Checklist for the PR body (ensure covered):

- [ ] CHANGELOG updated
- [ ] `./tool/git/preflight_release.sh` passed locally (full tests + copy)
- [ ] CI **release gate** green on the PR (full tests + debug APK)

Tell the user: **merge is human/maintainer action** unless they explicitly ask you to merge and you have permission. When merging the release PR into `main`, use **Create a merge commit** only — never squash.

```bash
# After CI green:
gh pr merge <PR_NUMBER> --merge
```

## Step 6 — Hand off to ship

After the PR is merged, say:

> Release branch is merged. Next: run the **ship release** playbook (`skills/ship-release/SKILL.md`) — Release Android workflow on `main`, then back-merge.

Do **not** run the GitHub Release workflow from `dev`.

## Failure handling

| Problem | Action |
|---------|--------|
| Dirty tree | Stash/commit, or re-run with `--allow-dirty` if user agrees |
| Branch already exists | Use existing branch or pick a new version suffix; do not force-delete without asking |
| Preflight fails | Fix reported step, re-run preflight |
| Protected branch push rejected | Use PR flow only; never bypass with force-push without explicit user request |

## Scripts reference

| Script | Purpose |
|--------|---------|
| `tool/git/start_release_branch.sh` | Cut `release/*` from `dev` |
| `tool/git/preflight_release.sh` | Local CI-like checks |
| `tool/git/open_release_pr.sh` | PR → `main` |
| `tool/release/bump_version.sh` | Manual bump if needed |
