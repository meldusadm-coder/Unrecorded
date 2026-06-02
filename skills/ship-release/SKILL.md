---
name: ship-release
description: >-
  After a release PR merged to main, run Android release workflow, verify tags,
  and back-merge main into dev. Use when the user says ship release, publish
  release, run release workflow, upload to Play, create GitHub release, or
  finish release.
---

# Ship release

Use **after** `release/*` (or `hotfix/*`) is merged into `main`. Execute step by step; confirm with the user before triggering CI that uploads to Play.

## Step 0 — Verify on `main`

```bash
git fetch origin
git checkout main
git pull origin main
./tool/git/release_status.sh
./tool/release/verify_version.sh
```

Confirm `pubspec.yaml` version matches what the user intends to ship (`version_name` + `build_number`).

## Step 1 — Preflight on `main` (optional)

```bash
./tool/git/preflight_release.sh
```

Skip if the **release PR** already passed CI **release gate** (full tests + copy + debug APK) on the same commit and nothing changed since merge. **Release Android** on `main` does not re-run unit tests — the release PR gate is the test authority.

## Step 2 — GitHub Actions: Release Android

After the release PR is **merged to `main`**, the workflow usually **starts automatically** when `apps/mobile/pubspec.yaml` or `CHANGELOG.md` changes. It reads version from `pubspec.yaml`, uploads to Play **internal** (draft), and creates GitHub Release `mobile-v<version>+<build>`.

Tell the user to watch: **Actions → Release Android** (trigger: `push` to `main`).

**Manual re-run only if needed** (failed Play upload, missing secrets, etc.):

**Actions → Release Android → Run workflow** on **`main`**. Leave version fields empty to use `pubspec.yaml`; defaults upload to Play internal.

```bash
gh run list --workflow=release-android.yml --limit 3
```

Never run this workflow on `dev` while `main` is the production branch.

## Step 3 — Monitor workflow

```bash
gh run list --workflow=release-android.yml --limit 3
# gh run watch <run-id>
```

Report: format/analyze/copy checks, AAB artifact, Play upload result, GitHub Release link.

## Step 4 — Store follow-up (human)

Remind maintainers (no agent action unless asked):

- Play Console: promote draft if workflow uploaded as draft
- Store listing copy: [store/android/](../../store/android/)
- Privacy URL: `https://unrecorded.app/privacy.html` — see [docs/release.md](../../docs/release.md)

## Step 5 — Back-merge `main` → `dev`

```bash
./tool/git/backmerge_main_to_dev.sh
```

Merge the sync PR when CI is green. This keeps `dev` aligned with production.

## Step 6 — Done summary

Tell the user:

- Version shipped
- Tag name
- Whether Play upload ran
- Whether back-merge PR was opened/merged

## Recovery

| Problem | Action |
|---------|--------|
| Wrong version on `main` | New hotfix playbook (`skills/hotfix/SKILL.md`), new build number |
| Tag already exists | Bump build number; do not reuse |
| Play upload failed | Fix secrets/track; bump `version_code`; re-run on `main` |
| Skipped back-merge | Run `./tool/git/backmerge_main_to_dev.sh` now |
