# Dev container (Windows-focused)

Develop Unrecorded inside a reproducible Linux container with Flutter, Dart, Java 17, and the Android SDK—matching CI. On Windows, run the **Android emulator on the host** and connect from the container via `host.docker.internal`.

## Prerequisites

| Tool | Purpose |
|------|---------|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Dev Containers |
| [Android Studio](https://developer.android.com/studio) | SDK + at least one AVD (API 30+, x86_64, Google APIs) |
| [Cursor](https://cursor.com/) or VS Code | Editor + [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension |

## Quick start (Windows)

1. **Host bootstrap** (once per session)—double-click or run from repo root:

   ```cmd
   start-dev.cmd
   ```

   This starts Docker Desktop (if needed), resets adb, launches an AVD, and waits for the emulator to boot.

   PowerShell alternatives:

   ```powershell
   .\scripts\windows\Start-UnrecordedDev.ps1
   .\scripts\windows\Start-UnrecordedDev.ps1 -ListAvds
   ```

2. **Reopen in container** — Command Palette → **Dev Containers: Reopen in Container** (first build may take several minutes).

3. **Run the app** — in the container terminal:

   ```bash
   ./scripts/dev-run-demo.sh
   ```

   For real BLE on a USB device: `./scripts/dev-run.sh`

   Or press **F5** → **Unrecorded (demo UAT)** or **Unrecorded (real BLE)**.

   See [local-testing.md](local-testing.md).

   Build a debug APK instead:

   ```bash
   ./scripts/dev-run.sh --build
   ```

## Host script options

| Flag | Purpose |
|------|---------|
| `-AvdName <name>` | Use a specific AVD |
| `-SkipDocker` | Skip Docker start/check |
| `-SkipEmulator` | Docker only (emulator already running) |
| `-RestartEmulator` | Kill and restart the emulator |
| `-ColdBoot` | Skip emulator snapshot (slower, useful if boot is stuck) |
| `-OpenCursor` | Open the repo in Cursor if `cursor` is on PATH |

## What runs where

| Task | Where |
|------|--------|
| `flutter pub get`, `dart format`, `dart analyze`, tests, APK build | Dev container |
| Android emulator | Windows host (recommended) |
| Real BLE scanning | Physical device (not the emulator) |
| Demo / fake scanner | `./scripts/dev-run-demo.sh` or debug Settings → Developer testing |

## CI parity commands (inside container)

Full suite (matches push to `dev` and release PR CI — see [ci-testing.md](ci-testing.md)):

```bash
flutter pub get
dart format --set-exit-if-changed .
dart analyze --fatal-infos
cd packages/unrecorded_core && dart test
cd packages/unrecorded_radio && flutter test
cd packages/unrecorded_ui && flutter test
cd apps/mobile && flutter test
cd apps/mobile && flutter build apk --debug   # release PR gate only in CI
```

VS Code task **CI: format + analyze + all tests** runs the test subset.

## Git commits

Git identity is **not** stored in the repo. Copy [`.devcontainer/gitconfig.example`](../.devcontainer/gitconfig.example) to `.devcontainer/gitconfig` (gitignored), set your name and email, then reopen or rebuild the dev container — `postCreate` installs it as `~/.gitconfig`. If the file is missing on first create, the example is copied for you to edit.

## Troubleshooting

### Blank workspace (no files in the container)

The repo must be bind-mounted at `/workspace`. If the explorer is empty after reopening:

1. **Dev Containers: Rebuild Container** (picks up `workspaceMount` in `devcontainer.json`).
2. Confirm you opened the **repository root** (the folder that contains `.devcontainer/`), not a parent or subfolder.
3. In a container terminal, run `ls /workspace` — you should see `apps/`, `packages/`, `pubspec.yaml`, etc.

### Stuck on "waiting for emulator to boot"

- An **emulator window** should appear on Windows — if it closes immediately, open the AVD from **Android Studio → Device Manager** to see the error.
- First boot can take **several minutes**; the script now prints progress every 15s.
- Retry with a clean restart:

  ```powershell
  .\scripts\windows\Start-UnrecordedDev.ps1 -RestartEmulator
  ```

- If still stuck, start the AVD manually in Android Studio, then run:

  ```cmd
  start-dev.cmd -SkipEmulator
  ```

### `Permission denied` on `/sdks/flutter/bin/cache`

The Flutter SDK cache was root-owned. **Rebuild the dev container**:

**Dev Containers: Rebuild Container**

Or run once in a container terminal:

```bash
sudo chown -R "$(id -u):$(id -g)" /sdks/flutter
```

### Flutter only sees Linux desktop (no Android emulator)

The emulator runs on **Windows**, not inside the container. Flutter in the container only sees it after the host bridge is up.

1. On **Windows** (repo root): `start-dev.cmd` — wait until the emulator window is booted.
2. On **Windows**, confirm: `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe devices` shows `emulator-5554` as `device`.
3. In the **container** terminal (repo root `/workspace`):

   ```bash
   ./scripts/dev-run-demo.sh
   ```

   Do **not** run bare `flutter run` from `apps/mobile` without `./scripts/dev-run.sh` first — that skips host adb setup.

4. If still no device, reconnect manually:

   ```bash
   bash .devcontainer/scripts/prepare-emulator.sh
   flutter devices
   ```

The dev container uses `ADB_SERVER_SOCKET=tcp:host.docker.internal:5037` (host adb must listen on all interfaces; `start-dev.cmd` runs `adb -a start-server`). Rebuild the dev container after pulling changes that touch `devcontainer.json`.

### `connect-host-emulator.sh` fails

- Run `Start-UnrecordedDev.ps1` on the host first.
- Confirm host adb sees the device: `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe devices`
- Emulator should show as `emulator-5554`. The container uses host adb on port **5037**, with optional `adb connect` to **5555** on `host.docker.internal`.

### Docker never becomes ready

- Start Docker Desktop manually and wait until it is running.
- Ensure WSL2 backend is enabled (Docker Desktop settings).

### No AVDs listed

- Open Android Studio → **Device Manager** → create a device (API 30+, x86_64).

### `assembleDebug` very slow or appears stuck

The **first** Android debug build inside a dev container on **Windows + Docker** is often **10–20+ minutes** (sometimes longer). Gradle is not frozen—it is downloading dependencies and compiling on a slow bind-mounted workspace. The message `31 packages have newer versions…` from `flutter pub get` is **informational only**; it does not block the build.

**Do this:**

1. Give **Docker Desktop → Settings → Resources** at least **8 GB RAM** (more helps).
2. Prefer warming the build once, then run the app:

   ```bash
   ./scripts/warm-android-build.sh
   ./scripts/dev-run-demo.sh
   ```

3. See live Gradle progress in a second terminal:

   ```bash
   cd apps/mobile/android
   ./gradlew :app:assembleDebug --info
   ```

4. Keep Gradle’s cache **off** the Windows bind mount (default in this repo): `GRADLE_USER_HOME=/home/vscode/.gradle` in `devcontainer.json`.

5. `apps/mobile/build` is symlinked to `~/.cache/unrecorded-android-build` (`UNRECORDED_ANDROID_BUILD_DIR` in `devcontainer.json`) so Gradle and Flutter use the same path off the Windows bind mount.

6. After a successful build, `flutter run` / hot reload is much faster than the first assemble.

### `Could not set file mode 755` / `permission_handler_android:generateDebugResValues`

Gradle is writing under `apps/mobile/build` on the Windows bind mount, often with **root-owned** folders from a prior failed build.

```bash
./scripts/prepare-android-build.sh
cd apps/mobile && flutter clean
./scripts/dev-run-demo.sh
```

If Gradle finished but Flutter reports **could not find the .apk**, recreate the symlink from `/workspace`:

```bash
export UNRECORDED_ANDROID_BUILD_DIR=/home/vscode/.cache/unrecorded-android-build
./scripts/prepare-android-build.sh
./scripts/dev-run-demo.sh
```

If the env var is missing (container opened before this change), export it or **Dev Containers: Rebuild Container**.

If it still never finishes after 30+ minutes, check Docker memory and disk space, then rebuild the dev container (**Dev Containers: Rebuild Container**).

### In-container Android emulator

Not supported reliably on Windows Docker (no nested KVM). Use the host emulator workflow above.

### iOS

iOS builds and Simulator require macOS; not available in this Linux dev container.

## Manual fallback (no host script)

1. Start Docker Desktop and an emulator from Android Studio.
2. Reopen in Container.
3. Run `connect-host-emulator.sh` and `flutter run` as above.
