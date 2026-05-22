# Git workflow helpers

Scripts for the branching model in [docs/git-flow.md](../../docs/git-flow.md).

**AI playbooks** (step-by-step for “create release”, “branch for issue N”, etc.): [skills/README.md](../../skills/README.md).

```bash
./tool/git/release_status.sh
./tool/git/start_release_branch.sh 0.2.0 3
./tool/git/preflight_release.sh
./tool/git/open_release_pr.sh
# after merge + Release Android on main:
./tool/git/backmerge_main_to_dev.sh
```

Hotfix:

```bash
./tool/git/start_hotfix_branch.sh 0.2.1 4
```

Requires `git`. Optional: [GitHub CLI](https://cli.github.com/) (`gh`) for `open_release_pr.sh` and `backmerge_main_to_dev.sh`.

Environment overrides: `INTEGRATION_BRANCH` (default `dev`), `PRODUCTION_BRANCH` (default `main`).
