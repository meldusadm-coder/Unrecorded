# Dev container (Windows-focused)

Develop Unrecorded inside a reproducible Linux container with Flutter, Dart, Java 17, and the Android SDK—matching CI. On Windows, run the **Android emulator on the host** and connect from the container via `host.docker.internal`.

## Prerequisites

| Tool | Purpose |
|------|---------|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Dev Containers |
| [Android Studio](https://developer.android.com/studio) | SDK + at least one AVD (API 30+, x86_64, Google APIs) |
| [Cursor](https://cursor.com/) or VS Code | Editor + [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension |

## Quick start (Windows)

1. **Host bootstrap** (once per session)—from repo root in PowerShell or double-click:

   ```powershell
   .\scripts\windows\Start-UnrecordedDev.ps1
   ```

   Or double-click / run from cmd:

   ```cmd
   start-dev.cmd
   scripts\windows\start-unrecorded-dev.cmd
   ```

   List installed AVDs: `.\scripts\windows\Start-UnrecordedDev.ps1 -ListAvds`

   This starts Docker Desktop (if needed), launches an AVD, and waits for the emulator to boot.

2. **Reopen in container** — Command Palette → **Dev Containers: Reopen in Container** (first build may take several minutes).

3. **Connect emulator** — in the container terminal:

   ```bash
   .devcontainer/scripts/connect-host-emulator.sh
   cd apps/mobile && flutter run
   ```

   Or use the VS Code task **Android: connect host emulator**, then **Run → Start Debugging** (configuration **Unrecorded (mobile)**).

## Host script options

| Flag | Purpose |
|------|---------|
| `-AvdName <name>` | Use a specific AVD |
| `-SkipDocker` | Skip Docker start/check |
| `-SkipEmulator` | Docker only (emulator already running) |
| `-RestartEmulator` | Kill and restart the emulator |
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
