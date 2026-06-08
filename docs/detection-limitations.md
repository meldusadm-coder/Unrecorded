# Detection limitations

Unrecorded detects **possible** nearby smart glasses or wearable recording indicators. It **cannot** prove that any device is recording.

## Local-first scanning

- Scan data stays on your device. There is no cloud analysis of nearby signals.
- Detection history (device ids, names, addresses) is **not** persisted — only your protection and notification preferences are saved.

## Foreground-first scan cadence

- While protection is on, scanning runs in **short windows** with **rest periods** between them to reduce battery use.
- **Keep the app open** for the most reliable scanning when background protection is off.
- Risk notifications may appear while protection is active, but Android may limit behaviour when the app is not in the foreground.
- An ongoing **protection status** notification appears in the Android notification shade while protection is active and notification permission is granted. It means protection is running — not that recording was detected.
- **Possible-risk alert** notifications are separate, higher-priority alerts when nearby signals match risk indicators. They are not proof of recording.

## Background protection (Android, opt-in)

- **Off by default.** Users can turn on **Background protection** from the scan screen or Settings.
- When on, Unrecorded runs a foreground service with a persistent notification and keeps the scan/rest loop running while the app is minimised or locked, where Android allows.
- **Notification permission is required** so the persistent notification is visible and includes a Stop action.
- Clearing the app from recents may not stop the service on all devices; Android or battery settings may still stop it.
- If Android stops background protection while your setting is still on, the app explains this honestly on next open and lets you restart — it does not claim protection is still active.
- Tapping **Stop** on the notification stops protection and is recorded as an explicit user stop (not “stopped by Android”).
- Background protection does **not** auto-start after reboot in this version.
- Not proof of recording. Not guaranteed on all devices or battery policies.

## Notifications (Android)

| Notification | Meaning |
|---|---|
| Protection status (ongoing) | Protection is active while the app is running. Tap to open the main screen. |
| Possible-risk alert | Nearby Bluetooth signals matched risk indicators. Tap for details. Not proof of recording. |

Scanning reliability depends on Android version, battery settings, Bluetooth state, permissions, and whether the app can keep running. Without background protection, if Android stops the app, protection and notifications stop too.

### Background protection UAT (physical Android 13+/14+)

1. Fresh install; grant Bluetooth and notification permissions.
2. Confirm background protection is **off** by default.
3. Turn it **on** → persistent notification with Stop appears.
4. Minimise and lock the device → scan cadence continues where Android allows.
5. Clear app from recents → service may continue (device-dependent).
6. Tap **Stop** on the notification → reopening shows OFF (not “stopped by Android”).
7. Turn background protection on again; trigger demo high risk → separate risk alert appears.
8. Force-stop or enable battery saver → reopening shows “stopped by Android” with restart option.
9. Reboot → background protection does **not** auto-start.

### Manual UAT checklist

1. Fresh install on Android 13+ physical device.
2. Grant Bluetooth and notification permissions.
3. Enable protection.
4. Confirm notification shade shows “Unrecorded protection is active”.
5. Press Home / lock screen / switch apps.
6. Confirm notification remains visible while protection is active.
7. Tap notification and confirm app opens to main protection screen.
8. Trigger demo high-risk alert.
9. Confirm a separate possible-risk alert appears.
10. Pause protection.
11. Confirm status notification is removed.
12. Repeat with notification permission denied and confirm in-app explanation is clear.
13. Repeat with battery saver enabled if practical.
14. Test on at least one physical Android device, not only emulator.

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
