---
name: hotfix
description: >-
  Emergency patch from main for production, version bump, PR to main, then ship
  and back-merge. Use when the user says hotfix, patch production, fix main,
  urgent release, or production bug.
---

# Hotfix

Production fix off **`main`**, not `dev`. Same ship/back-merge pattern as a release.

## Step 0 — Check status

```bash
./tool/git/release_status.sh
./tool/release/verify_version.sh
```

Confirm the bug is in what `main` shipped (not only on `dev`).

## Step 1 — Version

- **version_name**: usually patch bump (e.g. `0.2.0` → `0.2.1`)
- **build_number**: must be **new** (never reuse published `version_code`)

Ask the user to confirm both.

## Step 2 — Cut hotfix branch

```bash
./tool/git/start_hotfix_branch.sh <version_name> <build_number>
```

On `hotfix/<version_name>`.

## Step 3 — Fix + CHANGELOG

1. Minimal fix only
2. Update `CHANGELOG.md` for the new version
3. Commit

## Step 4 — Preflight

```bash
./tool/git/preflight_release.sh
```

## Step 5 — PR to `main`

```bash
./tool/git/open_release_pr.sh
```

(`open_release_pr.sh` works on `hotfix/*` branches.)

## Step 6 — After merge

Merge the hotfix PR into `main` with **Create a merge commit** only (`gh pr merge <PR> --merge`).

Follow [ship-release/SKILL.md](../ship-release/SKILL.md):

- Release Android on **`main`**
- `./tool/git/backmerge_main_to_dev.sh`

If the fix also applies only on `dev`, note whether a cherry-pick to `dev` is needed after back-merge (usually back-merge is enough).
