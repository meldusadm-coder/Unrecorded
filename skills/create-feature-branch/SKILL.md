---
name: create-feature-branch
description: >-
  Create a feature branch from dev for GitHub issue work, link branch to issue,
  and open PR to dev. Use when the user says create branch from issue, branch
  for issue 42, start work on issue, feature branch, or implement issue #N.
---

# Create feature branch from issue

Feature work merges to **`dev`** only, never directly to `main`.

## Step 0 — Prerequisites

- Repo root, git available
- Prefer [GitHub CLI](https://cli.github.com/) (`gh`) for issue lookup; otherwise user pastes issue title/body

```bash
./tool/git/release_status.sh
```

Confirm you are not accidentally on `release/*` or `hotfix/*`.

## Step 1 — Resolve the issue

**With `gh`:**

```bash
gh issue view <ISSUE_NUMBER> --json number,title,body,state,url
```

**Without `gh`:** Ask the user for issue number, title, and acceptance criteria.

If issue is closed, confirm the user still wants a branch.

## Step 2 — Branch name

Convention:

```text
feature/issue-<NUMBER>-<short-slug>
```

- `<short-slug>`: lowercase, hyphenated, max ~40 chars from issue title (drop filler words)
- Examples: `feature/issue-42-ble-scan-timeout`, `feature/issue-7-settings-copy`

Show the proposed name; change if the user prefers.

## Step 3 — Create branch from `dev`

**Preferred (script):**

```bash
./tool/git/start_feature_branch.sh <ISSUE_NUMBER>
# optional custom slug:
./tool/git/start_feature_branch.sh <ISSUE_NUMBER> --slug ble-scan-timeout
```

**Manual:**

```bash
git fetch origin
git checkout -b feature/issue-<NUMBER>-<slug> origin/dev
```

## Step 4 — Link issue (optional comment)

If `gh` available and user wants:

```bash
gh issue comment <ISSUE_NUMBER> --body "Working on this in branch \`feature/issue-<NUMBER>-<slug>\`."
```

## Step 5 — Implement (only if user asked for code in same session)

1. Small focused commits
2. Tests for scoring/privacy-sensitive changes
3. `dart format` / `dart analyze` before PR

Otherwise stop after branch creation and tell the user the branch is ready.

## Step 6 — Open PR to `dev`

When work is ready:

```bash
git push -u origin HEAD
gh pr create --base dev --head "$(git branch --show-current)" \
  --title "<type>: <short description> (fixes #<NUMBER>)" \
  --body "## Summary
<what changed>

## Issue
Fixes #<NUMBER>

## Test plan
- [ ] \`./tool/git/preflight_release.sh --skip-tests\` or full test run
- [ ] Manual checks if needed"
```

Without `gh`, print compare URL: `https://github.com/<owner>/<repo>/compare/dev...<branch>?expand=1`

PR title examples: `fix: handle BLE timeout (fixes #42)`, `feat: add settings disclaimer (fixes #7)`

## Rules

- Target base branch: **`dev`**
- One concern per PR ([CONTRIBUTING.md](../../CONTRIBUTING.md))
- Privacy/product rules from [AGENTS.md](../../AGENTS.md)

## Scripts

| Script | Purpose |
|--------|---------|
| `tool/git/start_feature_branch.sh` | Branch from `origin/dev` + issue slug |
| `tool/git/preflight_release.sh` | Optional before PR (`--skip-tests` ok for small UI-only changes if user agrees) |
