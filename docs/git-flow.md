# Git workflow

Concise branching model for Unrecorded. Feature work integrates on **`dev`**; **`main`** matches what we ship and tag.

## Branches

| Branch | Purpose |
|--------|---------|
| `main` | Production history; run Android release workflow from here |
| `dev` | Integration; merge feature PRs here |
| `feature/*` | Short-lived work; PR → `dev` only |
| `release/*` | Stabilization before a version ships (version bumps, copy, last fixes) |
| `hotfix/*` | Urgent fix off `main` after a release |
| `sync/*` | Back-merge `main` → `dev` after shipping |

`dev` and `main` are protected (PR required). Do not push directly to them.

## Day-to-day development

```text
feature/my-thing  ──PR──►  dev
```

1. Branch from latest `dev`: `git fetch origin && git checkout -b feature/my-thing origin/dev`
2. Open PR into `dev`; wait for CI (see [`.github/workflows/mobile-ci.yml`](../.github/workflows/mobile-ci.yml)).
3. Squash or merge per repo settings; delete the feature branch.

## Releasing to `main`

Use a **release branch** when the build might need tweaks you cannot push straight to `dev`.

```text
dev  ──cut──►  release/0.2.0  ──PR──►  main  ──tag/workflow──►  Play / GitHub Release
                                      │
                                      └──back-merge PR──►  dev
```

### 1. Start release branch

```bash
./tool/git/start_release_branch.sh 0.2.0 3
```

Creates `release/0.2.0` from `origin/dev`, bumps `pubspec.yaml` / `CHANGELOG.md` (`0.2.0+3`), and prints next steps.

Without a build number (branch only):

```bash
./tool/git/start_release_branch.sh 0.2.0
```

### 2. Stabilize on the release branch

- Fill in `CHANGELOG.md` for `0.2.0+3`.
- Commit release-only fixes on `release/0.2.0` (not on `dev` unless cherry-picked later).
- Preflight locally:

```bash
./tool/git/preflight_release.sh
```

### 3. PR into `main`

```bash
./tool/git/open_release_pr.sh
```

Uses `gh` when installed; otherwise prints the manual PR URL.

Review, merge when CI is green.

### 4. Ship from `main`

1. Check out `main` and pull.
2. GitHub Actions → **Release Android** → run on branch **`main`** with `version_name` / `version_code` matching `pubspec.yaml` (or let the workflow bump — see [release.md](release.md)).
3. Tag format: `mobile-v0.2.0+3`.

Do **not** run the release workflow from `dev` while `main` is behind; store artifacts should match `main`.

### 5. Back-merge into `dev`

```bash
./tool/git/backmerge_main_to_dev.sh
```

Opens (or prints) a PR **`main` → `dev`** so the next feature cycle includes shipped commits.

## Direct `dev` → `main` PR

OK when `dev` is exactly what you want to ship and review needs no extra commits:

1. PR `dev` → `main`
2. Release from `main`
3. `./tool/git/backmerge_main_to_dev.sh` (noop if already aligned; still safe)

## Hotfix after release

```text
main  ──cut──►  hotfix/0.2.1  ──PR──►  main  ──release──►  stores
                                      │
                                      └──back-merge──►  dev
```

```bash
./tool/git/start_hotfix_branch.sh 0.2.1 4
# fix, preflight, PR to main, release from main, then:
./tool/git/backmerge_main_to_dev.sh
```

Never reuse a published Android `version_code`; bump the build number.

## Helper scripts

| Script | Purpose |
|--------|---------|
| [`tool/git/start_feature_branch.sh`](../tool/git/start_feature_branch.sh) | Cut `feature/issue-N-slug` from `dev` (uses `gh` for title if available) |
| [`tool/git/start_release_branch.sh`](../tool/git/start_release_branch.sh) | Cut `release/VERSION` from `dev`, optional version bump |
| [`tool/git/start_hotfix_branch.sh`](../tool/git/start_hotfix_branch.sh) | Cut `hotfix/VERSION` from `main`, optional version bump |
| [`tool/git/open_release_pr.sh`](../tool/git/open_release_pr.sh) | Open PR to `main` from current release/hotfix branch |
| [`tool/git/backmerge_main_to_dev.sh`](../tool/git/backmerge_main_to_dev.sh) | Open PR `main` → `dev` after shipping |
| [`tool/git/preflight_release.sh`](../tool/git/preflight_release.sh) | Version, copy guardrails, format, analyze, tests |
| [`tool/git/release_status.sh`](../tool/git/release_status.sh) | Branch, version, and ahead/behind vs `main`/`dev` |

Version bump details: [`tool/release/bump_version.sh`](../tool/release/bump_version.sh). Store shipping: [release.md](release.md).

## CI

- **Mobile CI:** PRs and pushes to `dev` and `main`.
- **Release Android:** Manual `workflow_dispatch` on the selected branch (use `main` after merge).

## AI assistants

Phrase → playbook mapping and step-by-step instructions: [skills/README.md](../skills/README.md).

Examples: “create release” → `skills/create-release/SKILL.md`; “branch for issue 42” → `skills/create-feature-branch/SKILL.md`.

## Related

- [release.md](release.md) — versioning, signing, Play upload
- [skills/README.md](../skills/README.md) — agent playbooks
- [CONTRIBUTING.md](../CONTRIBUTING.md) — contribution rules
- [AGENTS.md](../AGENTS.md) — AI assistant git/release expectations
