# CodeQL

## Default setup (current)

This repository uses GitHub **CodeQL default setup** for code scanning. Results appear under **Security → Code scanning** without uploading SARIF from a custom workflow.

The workflow [`.github/workflows/codeql.yml`](../.github/workflows/codeql.yml) is present for optional **advanced** use but **does not run analysis** until you opt in (see below). That avoids CI failures from the error:

> CodeQL analyses from advanced configurations cannot be processed when the default setup is enabled

## Optional: switch to advanced workflow

Use this only if you need a custom build (e.g. manual Flutter Android build) or want full control of languages and schedule.

1. **GitHub:** Settings → **Code security** → **Code scanning** → **CodeQL analysis** → **Switch to advanced** (disables default setup for this repo).
2. **Repository variable:** Settings → **Secrets and variables** → **Actions** → **Variables** → add:
   - Name: `CODEQL_USE_ADVANCED_WORKFLOW`
   - Value: `true`
3. Re-run the **CodeQL** workflow on `dev` or `main`.

The advanced workflow analyzes **java-kotlin** (via `flutter build apk --debug`) and **python** (`tool/play/`). Dart is not a supported CodeQL language on Actions today; rely on default setup or advanced Java/Kotlin coverage for the mobile app.

## Reverting to default setup

1. Remove or set `CODEQL_USE_ADVANCED_WORKFLOW` to anything other than `true`.
2. In Code security settings, re-enable **CodeQL default setup** for the repository.
