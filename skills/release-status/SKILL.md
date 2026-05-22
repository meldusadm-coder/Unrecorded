---
name: release-status
description: >-
  Report current git branch, app version, and how main and dev relate. Use when
  the user asks release status, git status for release, is dev ahead of main,
  what version are we on, or before starting any release workflow.
---

# Release status

Run and interpret:

```bash
./tool/git/release_status.sh
./tool/release/verify_version.sh
```

## Report to the user

1. **Current branch** — warn if on `main`/`dev` with uncommitted release work
2. **App version** — `full_version`, suggested `tag_name`
3. **dev vs main** — commits ahead/behind each way
4. **Current branch vs main** — if on `release/*`, `hotfix/*`, or `feature/*`

## Suggest next action

| Situation | Suggest |
|-----------|---------|
| On `dev`, user wants to ship | [create-release](../create-release/SKILL.md) |
| On `release/*`, PR not merged | Finish CHANGELOG/preflight → `open_release_pr.sh` |
| Release PR merged, on `main` | [ship-release](../ship-release/SKILL.md) |
| `main` ahead of `dev` after ship | [backmerge](../backmerge/SKILL.md) |
| Production bug | [hotfix](../hotfix/SKILL.md) |
| Starting issue work | [create-feature-branch](../create-feature-branch/SKILL.md) |

Do not run destructive git commands unless the user asks.
