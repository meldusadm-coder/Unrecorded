# Release guide (Android)

Concise steps for maintainers shipping the Unrecorded Flutter app (`apps/mobile`).

**Git:** merge to `main` via a `release/*` branch first — see [git-flow.md](git-flow.md). After merge, run this workflow on **`main`** and back-merge with `./tool/git/backmerge_main_to_dev.sh`.

## Versioning

**Source of truth:** [`apps/mobile/pubspec.yaml`](../apps/mobile/pubspec.yaml)

```yaml
version: 0.1.0+1   # versionName+versionCode (Flutter convention)
```

Flutter propagates this automatically:

| Platform | Field | Source |
|----------|--------|--------|
| Android | `versionName` / `versionCode` | `flutter.versionName` / `flutter.versionCode` in Gradle |
| iOS | `CFBundleShortVersionString` / `CFBundleVersion` | `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER` in Info.plist |

Do not duplicate version numbers in native project files unless you have a special case.

## Bump version

```bash
./tool/release/bump_version.sh 0.1.0 2
# CI / dirty tree:
./tool/release/bump_version.sh 0.1.0 2 --allow-dirty
```

Updates `pubspec.yaml` and inserts a placeholder `CHANGELOG.md` section if missing.

Verify:

```bash
./tool/release/verify_version.sh
```

## Local Android release build

1. Create an upload keystore (once):

   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Copy [`apps/mobile/android/key.properties.example`](../apps/mobile/android/key.properties.example) to `apps/mobile/android/key.properties` and set paths/passwords.

3. Place the keystore at the path referenced by `storeFile` (e.g. `apps/mobile/android/app/upload-keystore.jks`).

4. Build:

   ```bash
   flutter pub get
   cd apps/mobile
   flutter build appbundle --release   # Play Store artifact (.aab)
   flutter build apk --release         # optional convenience APK
   ```

Outputs are under `apps/mobile/build/` (or the dev-container symlink target). **Submit the `.aab` to Google Play**, not the APK.

Without `key.properties`, release builds use debug signing (local testing only).

## GitHub Actions release workflow

Workflow: [`.github/workflows/release-android.yml`](../.github/workflows/release-android.yml)

**Trigger:** Actions → **Release Android** → **Run workflow**

| Input | Default | Purpose |
|-------|---------|---------|
| `version_name` | (required) | e.g. `0.1.0` |
| `version_code` | (required) | Integer build number |
| `track` | `internal` | Play track when uploading |
| `upload_to_play` | `false` | Upload AAB to Google Play |
| `create_github_release` | `true` | Tag `mobile-vX.Y.Z+N` + GitHub Release |

The workflow runs format, analyze, tests, release copy checks, signed AAB/APK build, artifact upload, optional Play upload, and optional GitHub Release.

### Required GitHub Secrets (signed release)

| Secret | Purpose |
|--------|---------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded `.jks` / `.keystore` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |

Encode keystore locally:

```bash
base64 -w0 upload-keystore.jks   # Linux
# macOS: base64 -i upload-keystore.jks
```

Never commit keystores or `key.properties`.

### Optional: AdMob banner unit (release builds)

Set **`ADMOB_BANNER_ID`** as a repository **variable** (recommended) or **secret**:

**Settings → Secrets and variables → Actions → Variables** → `ADMOB_BANNER_ID` = `ca-app-pub-XXXX/YYYY`

Release builds **fail in CI** when unset. Debug builds use Google’s test banner ID. Also set your production AdMob **app ID** in `apps/mobile/android/app/src/main/AndroidManifest.xml`. See [monetisation.md](monetisation.md).

### Optional: Google Play upload

Set **one** of:

| Secret | Purpose |
|--------|---------|
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Raw service account JSON |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64` | Base64-encoded JSON |

Play Console → **Setup** → **API access** → create a service account with release permissions, download JSON, store as secret.

Enable **Upload to Google Play** in the workflow. Default upload `status` is **draft** (review in Play Console before promoting).

Package name: `app.unrecorded.unrecorded_mobile` (must match Play Console).

## GitHub Releases and tags

Tag format: `mobile-v{version}+{build}` (e.g. `mobile-v0.1.0+2`).

Release notes: extracted from `CHANGELOG.md` for that version, else [`tool/release/release_notes_template.md`](../tool/release/release_notes_template.md).

Copy guardrails: `./tool/release/check_release_copy.sh` (also run in the release workflow).

## Store listing copy

Scaffolding (paste into Play Console / App Store Connect):

- Android: [`store/android/`](../store/android/)
- iOS: [`store/ios/`](../store/ios/)

Use cautious language: **possible** risk, **not proof of recording**, scan data stays on device.

### Privacy policy URL (required)

Google Play and **Google AdMob** require a **public, non-geofenced** privacy policy URL before publication.

| Field | Value |
|-------|--------|
| Privacy policy URL | `https://unrecorded.app/privacy.html` |

Source of truth: [`apps/site/privacy.html`](../apps/site/privacy.html) (deploy `apps/site` to `unrecorded.app`). The policy must cover, at minimum:

- BLE scanning processed on-device; scan data not uploaded by default
- Google AdMob banner ads and optional remove-ads IAP (scan data not passed to ads)
- No accounts; no third-party analytics in core scanning
- Possible privacy risk indicators — not proof of recording

Privacy contact in the policy: **privacy@unrecorded.app** (operator: **Meldlife Ltd**). In AdMob, link the same policy URL to your app.

## iOS (manual / future automation)

No iOS release workflow yet. For local builds on macOS:

```bash
cd apps/mobile
flutter build ipa --release
```

Requires Xcode signing (certificates, provisioning profile, App Store Connect).

Before App Store submission, add required **Info.plist usage descriptions** (Bluetooth, location if used) — not yet complete in this repo.

Future TestFlight automation would need secrets such as `APP_STORE_CONNECT_API_KEY_*`, `IOS_CERTIFICATE_*`, `IOS_PROVISIONING_PROFILE_*` (document only; do not commit).

## Recovery

| Problem | Action |
|---------|--------|
| Play upload failed | Fix credentials/track; bump `version_code`; re-run workflow |
| Wrong version in stores | Never reuse a published `version_code`; ship a new build number |
| GitHub Release tag exists | Delete tag/release in GitHub or use a new version |
| Unsigned local build | Add `key.properties` or expect debug-signed release APK/AAB |

## Related

- [git-flow.md](git-flow.md) — `dev` / `main` / `release/*` branching and `tool/git/` scripts
- [local-testing.md](local-testing.md) — UAT and debug builds
- [AGENTS.md](../AGENTS.md) — product guardrails (no certainty claims)
- [CHANGELOG.md](../CHANGELOG.md) — version history
