# Local testing and UAT

Unrecorded detects **possible** nearby smart-glass-style BLE signals. It does not prove recording. See [detection-limitations.md](detection-limitations.md).

## Quick paths

| Goal | Command / action |
|------|------------------|
| Emulator or fast UAT | `./scripts/dev-run-demo.sh` or F5 → **Unrecorded (demo UAT)** |
| Physical Android + real BLE | `./scripts/dev-run.sh` or F5 → **Unrecorded (real BLE)** |
| Instant alert in debug app | Settings → **Developer testing** → **Simulate alert now** (re-shows card after dismiss) |
| Calmer emulator UAT | Developer testing → **Demo scenario** → **Low risk only** |
| Risk notification toggle | Settings → **Alerts** → **Risk alerts** |
| Notification risk level | Settings → **Alerts** → **Notify me for** (when alerts on) |
| Developer testing UI | **Debug/profile builds only** — hidden in release (`kReleaseMode`) |
| Automated regression | `cd packages/unrecorded_core && dart test` (and radio + mobile tests) |

## Demo mode (scripted BLE)

Demo mode uses `FakeRadioScanner` with deterministic scenarios instead of the device radio.

```bash
cd apps/mobile
flutter run \
  --dart-define=UNRECORDED_DEMO_MODE=true \
  --dart-define=UNRECORDED_DEMO_SCENARIO=high
```

Scenarios: `random`, `low`, `medium`, `high` (default for UAT: `high` — includes a Ray-Ban Meta–style name every batch).

From the dev container (host emulator connected):

```bash
./scripts/dev-run-demo.sh
```

**Windows + dev container:** start `start-dev.cmd` on the host first, then run the script above from `/workspace` in the container. Plain `flutter run` without `dev-run.sh` will not see the host emulator.

## Debug settings (debug builds only)

Open **Settings & Privacy** → **Developer testing**:

- **Demo** vs **Real BLE** — persisted on device; switching restarts an active scan.
- **Demo scenario** — low / medium / high / random.
- **Simulate alert now** — injects one high-risk batch and re-shows the on-screen alert (even if you dismissed it). May also fire a local notification if alerts are enabled.
- **Reset scanner defaults** — clears overrides; emulators default back to demo + high scenario.

On first launch in debug, **Android emulators and iOS simulators** default to demo + high, so you may see alerts without pressing simulate. Choose **Low risk only** for a quieter session.

**Nearby signals** on the scan screen hide headphones/speakers under **Other nearby devices**; alert details show the top possible recording wearables only.

## Real Bluetooth testing

Use a **physical Android device** (emulator BLE is unreliable).

1. Run without demo defines: `./scripts/dev-run.sh`
2. In debug settings, choose **Real BLE** (or clear overrides on a physical device).
3. Grant Bluetooth and location permissions; keep Bluetooth on.
4. Keep smart glasses or another BLE peripheral nearby (advertising name may be hidden).

Optional: use **nRF Connect** on a second phone to advertise a custom name containing e.g. `ray-ban` or `meta` to trigger scoring without hardware glasses.

## Slow first build in the dev container

On Windows with Docker, the first `assembleDebug` can take **10–20+ minutes** and look stuck at `Running Gradle task 'assembleDebug'…`. That is usually normal.

1. Run `./scripts/warm-android-build.sh` once (optional but clearer progress).
2. Then `./scripts/dev-run-demo.sh`.
3. Ignore `31 packages have newer versions…` unless you are upgrading dependencies on purpose.

See [devcontainer.md](devcontainer.md) → **assembleDebug very slow or appears stuck**.

## Gradle: `Could not set file mode 755` on `build/…`

On **Windows + dev container**, Android plugin outputs under `apps/mobile/build` sit on a bind mount. Gradle may fail with `generateDebugResValues` / `Could not set file mode 755` if some paths are **root-owned** (often after an interrupted build).

**Fix (container terminal):**

```bash
./scripts/prepare-android-build.sh
cd apps/mobile && flutter clean
./scripts/dev-run-demo.sh
```

The dev container symlinks `apps/mobile/build` → `~/.cache/unrecorded-android-build` (via `UNRECORDED_ANDROID_BUILD_DIR`) so Gradle and Flutter share the same path off the bind mount. **Reopen or rebuild** the dev container once, or:

```bash
cd /workspace
export UNRECORDED_ANDROID_BUILD_DIR=/home/vscode/.cache/unrecorded-android-build
./scripts/prepare-android-build.sh
```

If Gradle succeeded but Flutter says it **could not find the .apk**, the symlink was missing — run `prepare-android-build.sh` from `/workspace`, then `./scripts/dev-run-demo.sh` (no full rebuild needed if the APK already exists under `~/.cache/unrecorded-android-build`).

You do **not** need to wipe the emulator for these errors — they are build-path issues, not install issues.

## Settings and notifications

- **Settings** opens with **Alerts** at the top (risk notifications toggle and threshold).
- **Developer testing** appears at the bottom of Settings in debug/profile builds only (hidden in release).
- Tapping a **risk notification** or **View details** on an alert opens **Alert details** (`/alert-details`) — risk level, possible device names/types, and reasons. **How detection works** (`/alert-info`) remains linked from there and from Help.
- **Notify me for** uses brand icons; the app bundles Material Design icons (`uses-material-design: true`) for dropdown affordances.
- Bluetooth **address prefix hints** (local map only) may appear on alert details when the scan ID looks like a MAC — not proof of vendor or recording.
- **Remove ads** above the banner uses a full-width tap row — use that link, not the ad itself.

## Launcher icon still wrong on the emulator

The home-screen icon is **not** the in-app SVG — it is baked into the APK from `apps/mobile/assets/brand/` and `android/app/src/main/res/`. Regenerate and reinstall:

```bash
./scripts/refresh-launcher-icons.sh
cd apps/mobile && flutter clean && flutter run …
```

On the emulator: uninstall the old app or cold-boot if the launcher still shows a purple circle with a lens (stale cache).

## Brand icons missing after pulling UI changes

SVG icons live in `packages/unrecorded_ui/assets/`. If the app shows empty gaps where icons should be:

1. From repo root: `flutter pub get`
2. Full restart (not hot reload): `cd apps/mobile && flutter clean && flutter run …`
3. Confirm `packages/unrecorded_ui/assets/icons/scan.svg` exists on disk.

In **debug**, a failed SVG shows a small broken-image icon and logs `Unrecorded SVG failed:` in the console.

## CI and unit tests

CI tiers (feature PR vs integration vs release): [ci-testing.md](ci-testing.md).

```bash
flutter pub get
cd packages/unrecorded_core && dart test
cd packages/unrecorded_radio && flutter test
cd packages/unrecorded_ui && flutter test
cd apps/mobile && flutter test
```

`scan_controller_test.dart` covers simulate-inject and scan lifecycle; `risk_scoring_engine_test.dart` covers name/signal rules.
