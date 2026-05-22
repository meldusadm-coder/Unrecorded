---
name: backmerge
description: >-
  Sync main into dev after a release or hotfix using the sync branch and PR.
  Use when the user says backmerge, sync main to dev, merge main into dev, or
  dev is behind main.
---

# Back-merge main → dev

## Step 0 — Check drift

```bash
./tool/git/release_status.sh
```

If `main` is **not** ahead of `dev`, report "already aligned" and stop.

## Step 1 — Run script

```bash
./tool/git/backmerge_main_to_dev.sh
```

Dry run only:

```bash
./tool/git/backmerge_main_to_dev.sh --dry-run
```

Creates `sync/main-into-dev-YYYYMMDD` and opens PR → `dev` (with `gh`) or prints manual URL.

## Step 2 — User merges PR

Wait for CI on the sync PR. Merge into `dev` with **Create a merge commit** only — never squash.

```bash
# After CI green (replace PR number):
gh pr merge <PR_NUMBER> --merge
```

## Step 3 — Cleanup

After merge: delete the sync branch locally/remotely if still present.

Confirm with `./tool/git/release_status.sh` that `main` is no longer ahead of `dev`.
