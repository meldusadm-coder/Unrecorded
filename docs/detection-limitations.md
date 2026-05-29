# Detection limitations

Unrecorded detects **possible** nearby smart glasses or wearable recording indicators. It **cannot** prove that any device is recording.

## Local-first scanning

- Scan data stays on your device. There is no cloud analysis of nearby signals.
- Detection history (device ids, names, addresses) is **not** persisted — only your protection and notification preferences are saved.

## Foreground-first scan cadence

- While protection is on, scanning runs in **short windows** with **rest periods** between them to reduce battery use.
- **Keep the app open** for the most reliable scanning. There is no always-on background protection service in this version.
- Risk notifications may appear while protection is active, but Android may limit behaviour when the app is not in the foreground.

## Why detection is probabilistic

- **Bluetooth visibility varies.** Devices may hide their name, randomise their address, or stop advertising.
- **Device names can be hidden, randomised, or spoofed.**
- **Address prefix hints are weak** — they are not proof of a specific device.
- **RSSI is noisy** — signal strength is only a rough proximity indicator.
- **Android 12+** may use privacy-preserving scan filters (`neverForLocation` on `BLUETOOTH_SCAN`); some BLE signals may not appear.
- **iOS** restricts background BLE more than Android. Real BLE scanning in production builds targets **Android**; other platforms may use demo data.
- **Alerts are risk indicators, not proof of recording.**

## Session memory (in-app only)

- Repeated sightings of the same signal within a session can modestly increase confidence.
- Stale signals expire after about a minute without a new observation.
- Risk is scored from **active session state**, not a single instant batch alone.

## What the app can detect

- BLE advertisements from nearby devices.
- Names, service UUID hints, and address prefixes matched against a **local catalogue**.
- Deterministic, explainable scoring with plain-English reasons.

## What the app cannot detect

- Devices that do not use Bluetooth or hide advertising.
- Whether recording is actually happening.
- Non-BLE cameras or microphones.

## Demo / test mode

- Demo mode uses a **fake scanner** with sample data for UI testing — not live Bluetooth.
