# Android permissions inventory

Release manifest audit for Unrecorded Android builds. Use this for Play Console review, privacy-policy checks, and contributor onboarding.

**Regenerate the merged release manifest:**

```bash
cd apps/mobile/android
./gradlew :app:processReleaseMainManifest --console=plain
```

**Inspect:**

`apps/mobile/build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml`

**List permissions:**

```bash
rg 'uses-permission android:name|<uses-permission$' -A1 \
  apps/mobile/build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml \
  | rg 'android:name'
```

After a `./gradlew :app:clean`, run `processReleaseMainManifest` again (the path above is correct for current Gradle output).

## Before / after (v0.6.0 audit)

Command used: `cd apps/mobile/android && ./gradlew :app:processReleaseMainManifest`

### Before (pre-audit, release merged manifest)

| Permission | In release? |
|------------|-------------|
| `android.permission.BLUETOOTH` (maxSdk 30) | Yes |
| `android.permission.BLUETOOTH_ADMIN` (maxSdk 30) | Yes |
| `android.permission.ACCESS_FINE_LOCATION` (maxSdk 30) | Yes |
| `android.permission.BLUETOOTH_SCAN` (`neverForLocation`) | Yes |
| `android.permission.BLUETOOTH_CONNECT` | Yes |
| `android.permission.POST_NOTIFICATIONS` | Yes |
| `android.permission.FOREGROUND_SERVICE` | Yes |
| `android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE` | Yes (app-declared) |
| `android.permission.INTERNET` | Yes |
| `android.permission.VIBRATE` | Yes |
| `android.permission.ACCESS_NETWORK_STATE` | Yes |
| `com.google.android.gms.permission.AD_ID` | Yes (AdMob SDK) |
| `android.permission.ACCESS_ADSERVICES_AD_ID` | Yes (AdMob SDK) |
| `android.permission.ACCESS_ADSERVICES_ATTRIBUTION` | Yes (AdMob SDK) |
| `android.permission.ACCESS_ADSERVICES_TOPICS` | Yes (AdMob SDK) |
| `com.android.vending.BILLING` | Yes |
| `android.permission.WAKE_LOCK` | Yes |
| `android.permission.RECEIVE_BOOT_COMPLETED` | No (not in release baseline; debug-only from some deps) |

### After (post-audit, fresh release merged manifest)

**Removed via `tools:node="remove"` in [`apps/mobile/android/app/src/main/AndroidManifest.xml`](../apps/mobile/android/app/src/main/AndroidManifest.xml):**

| Permission | Result |
|------------|--------|
| `com.google.android.gms.permission.AD_ID` | **Removed** |
| `android.permission.ACCESS_ADSERVICES_AD_ID` | **Removed** |
| `android.permission.ACCESS_ADSERVICES_ATTRIBUTION` | **Removed** |
| `android.permission.ACCESS_ADSERVICES_TOPICS` | **Removed** |
| `android.permission.RECEIVE_BOOT_COMPLETED` | **Removed** — app sets `autoRunOnBoot: false`; background protection does not auto-start after reboot ([`detection-limitations.md`](detection-limitations.md)) |

**Remaining release permissions:** BLE set (above), `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CONNECTED_DEVICE`, `WAKE_LOCK`, `INTERNET`, `VIBRATE`, `ACCESS_NETWORK_STATE`, `com.android.vending.BILLING`, plus internal signature permission `app.unrecorded.unrecorded_mobile.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (AndroidX).

AdMob may still merge non-permission AdServices metadata (`android.adservices.AD_SERVICES_CONFIG`); the app does not declare AdServices API permissions and uses non-personalised ad requests by default ([`ads_service.dart`](../apps/mobile/lib/services/ads_service.dart)).

## Permission inventory

| Permission / capability | Source | Why it exists | Decision | User-facing / privacy impact |
|-------------------------|--------|---------------|----------|------------------------------|
| `BLUETOOTH` / `BLUETOOTH_ADMIN` / `ACCESS_FINE_LOCATION` (maxSdk 30) | App | BLE scanning on Android 11 and below | **Keep** | Play may show location for pre-12 BLE; scoped to old SDKs only |
| `BLUETOOTH_SCAN` (`neverForLocation`) | App | BLE scanning on Android 12+ without location | **Keep** | “Nearby devices” / scan wording; not used for location tracking |
| `BLUETOOTH_CONNECT` | App | Required by `flutter_blue_plus` on Android 12+ | **Keep** | Play may group as “connect to paired devices”; app does not pair devices in UI |
| `POST_NOTIFICATIONS` | App + `flutter_local_notifications` | Possible-risk alerts and FGS status | **Keep** | User can deny; alerts respect OS setting |
| `FOREGROUND_SERVICE` | App + `flutter_foreground_task` | Background protection while enabled | **Keep** | Visible ongoing notification when protection runs |
| `FOREGROUND_SERVICE_CONNECTED_DEVICE` | App | Android 14+ FGS type for Bluetooth scanning | **Keep** | Matches connected-device FGS declaration |
| `WAKE_LOCK` | `flutter_foreground_task` | Keeps FGS cadence reliable (`allowWakeLock: true`) | **Keep** | Does not run unless user enables background protection |
| `VIBRATE` | `flutter_local_notifications` | Notification vibration | **Keep** | Only when notifications fire |
| `INTERNET` | AdMob, UMP, Play Billing | Banner ads, consent form, IAP | **Keep** | No scan data sent; ads isolated from detection ([`monetisation.md`](monetisation.md)) |
| `ACCESS_NETWORK_STATE` | AdMob / Play Services | SDK connectivity checks | **Keep** | Does not upload scan results |
| `com.android.vending.BILLING` | Play Billing | Pay-what-you-want remove-ads IAP | **Keep** | Optional purchase; core scanning stays free |
| `com.google.android.gms.permission.AD_ID` | AdMob (was merged) | Advertising ID for personalised ads | **Removed** | App defaults to non-personalised requests; declare “No” for Advertising ID in Play Console |
| AdServices permissions (3) | AdMob (was merged) | Topics / attribution APIs | **Removed** | Not used for banner-only non-personalised flow |
| `RECEIVE_BOOT_COMPLETED` | `flutter_foreground_task` (was merged) | Plugin boot receiver | **Removed** | Boot auto-start disabled in app; user re-enables protection manually after reboot |

## Play Console label mapping

| Play Console wording (examples) | Actual use in Unrecorded |
|---------------------------------|---------------------------|
| Discover / pair nearby Bluetooth devices | BLE **scan** for possible recording-risk signals; `neverForLocation` on 12+; no pairing UI |
| Run foreground service | Optional background protection (user opt-in) |
| Show notifications | Possible-risk alerts and protection status |
| Full network access | AdMob banners, UMP consent, Play Billing — not scan uploads |
| Google Play billing | Remove-ads in-app purchase |
| Advertising ID / AdId / AdServices | **Removed from manifest** — declare Advertising ID **No**; ads non-personalised by default |

## Privacy boundary (ads)

- Scan results, device names, MAC addresses, and risk outputs are **never** passed to ad SDKs.
- Ad code lives under `apps/mobile/lib/services/` only; core packages have no ad SDK imports.

## Play Console follow-ups after this audit

1. **Advertising ID declaration** → **No** (permissions removed from release manifest).
2. **Data safety** → review Device IDs / Advertising ID sections to match “No”.
3. **Privacy policy** → [apps/site/privacy.html](../apps/site/privacy.html) §8 remains accurate (permissions for BLE/notifications); no change required unless store copy mentions Advertising ID collection.

## Manual QA (edge-to-edge + permissions)

See PR notes for device checks. Minimum:

- API 35/36: gesture **and** 3-button navigation — scan screen, ad slot, settings/help bottom scroll
- Feedback screen: keyboard does not hide submit button
- BLE scan, notifications, background protection FGS, ads (or graceful empty slot), remove-ads purchase/restore
