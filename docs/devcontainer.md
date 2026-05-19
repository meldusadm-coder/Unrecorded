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
   ./scripts/dev-run.sh
   ```

   Or press **F5** → **Unrecorded (mobile)** (connects to the host emulator automatically).

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
| Demo / fake scanner | Works in emulator and tests |

## CI parity commands (inside container)

```bash
flutter pub get
dart format --set-exit-if-changed .
dart analyze --fatal-infos
cd packages/unrecorded_core && dart test
cd packages/unrecorded_radio && flutter test
cd apps/mobile && flutter test
cd apps/mobile && flutter build apk --debug
```

VS Code task **CI: format + analyze + all tests** runs the test subset.

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

### `connect-host-emulator.sh` fails

- Run `Start-UnrecordedDev.ps1` on the host first.
- Confirm host adb sees the device: `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe devices`
- Emulator should show as `emulator-5554`; the container connects to port **5555** on `host.docker.internal`.

### Docker never becomes ready

- Start Docker Desktop manually and wait until it is running.
- Ensure WSL2 backend is enabled (Docker Desktop settings).

### No AVDs listed

- Open Android Studio → **Device Manager** → create a device (API 30+, x86_64).

### In-container Android emulator

Not supported reliably on Windows Docker (no nested KVM). Use the host emulator workflow above.

### iOS

iOS builds and Simulator require macOS; not available in this Linux dev container.

## Manual fallback (no host script)

1. Start Docker Desktop and an emulator from Android Studio.
2. Reopen in Container.
3. Run `connect-host-emulator.sh` and `flutter run` as above.
