# Changelog

## 0.9.1+17

### Added
- Confirmation dialog before turning off background protection, with clear
  guidance that scanning then continues only while the app is open.

### Changed
- Background protection is on by default for all installs (one-shot migrate).
- Background toggle copy is shorter when on; off state reminds users to leave
  the app open for reliable checks.
- Settings keeps a single Privacy & data entry (duplicate notice card removed).
- Agent design artifacts under `docs/superpowers/` are no longer tracked.

### Fixed
- Turn off protection stays tappable while protecting, during transitions, and
  while stop is finalising; Stop times out to recovery instead of hanging busy.
- Turning background off while protecting immediately switches to foreground-only
  scanning (after confirmation).


## 0.9.0+16

### Added
- Glance-first main screen with a bold protection status hero, dominant Turn on/off
  control, one compact notice row, and progressive disclosure for details (#92).
- ProtectionOrchestrator as the sole owner of protection intent, with an Android
  atomic protocol store (SharedPreferences transactions, engine incarnations, and
  exclusive scanner lease) coordinating UI and background task engines.
- Typed radio start/stop results so scanning lifecycle fails closed when stop is
  uncertain.

### Changed
- Background task startup and notification Stop now go through the protocol store
  so Stop cannot race an auto-restart claim.
- Supporting screens (settings, help, alerts) use shorter glanceable copy while
  keeping privacy disclaimers accurate (possible risk, never proof of recording).

### Fixed
- Protection intent no longer flips briefly to "off" during background handoff or
  resume when the user still intends protection on.


## 0.8.2+15

### Changed
- Android release manifest again declares Google AdMob advertising ID permissions
  so the app aligns with Play policy while keeping non-personalised ads by default
  until UMP consent.
- Privacy policy and Android permissions docs clarify advertising ID is for ad
  serving only and is separate from Bluetooth scanning.

## 0.8.1+14

### Fixed
- Background protection now keeps protection visibly on during the handoff to
  background scanning and app resume, avoiding a transient "Turn on protection"
  state while background protection is enabled.


## 0.8.0+13

### Added
- Watch-friendly possible-risk notification copy with expanded phone text for Android notification mirroring.
- Recent-risk-aware protection status notifications with tap-through to recent risk details.

### Changed
- Protection and background notification copy now reflects scanning mode (foreground vs background) and recent risk state.
- Notifications help text explains that watch delivery depends on Android, Wear OS, and device settings.

### Fixed
- Stale risk alerts when background protection stops; foreground protection notification re-sync when background scanning ends.
- Background risk alerts respect OS notification permission; active-alert notification taps open alert details.


## 0.7.0+12

### Added
- Background protection (Android): optional foreground service keeps BLE scanning active with a persistent notification when the app is in the background.
- Recent risk reminder: configurable notification when elevated risk was detected recently, with threshold and window preferences.
- Expanded BLE detection catalogue: manufacturer ID hints and verified manufacturer data improve wearable/smart-glasses signature matching.

### Changed
- Risk scoring and signature matching incorporate manufacturer evidence alongside service UUID and name heuristics.
- Notification handling and user guidance for protection status, permission prompts, and recovery when Android stops the foreground service.

### Fixed
- Android edge-to-edge display: correct system bar insets on modern devices; release manifest permissions audited.


## 0.6.0+11

### Added
- Android deep links (`unrecorded://open/...`) for help, alert-info, and settings, with Play Console pre-launch URI list in `store/android/pre_launch_deep_links.txt`.
- Release workflow uploads Dart symbol maps for deobfuscated crash reports and reports estimated Play download size from the release AAB.

### Changed
- Remove-ads purchase and entitlement handling: clearer UI when ads are removed, stronger tests, and ads hidden consistently after purchase.
- Feedback mailto launcher builds more reliable URIs on Android.
- Release Android builds use obfuscation and split debug info; release docs updated accordingly.

### Fixed
- `tool/play/run.sh` is executable in the repo for Play upload helpers.
- Release workflow stages AAB Dart symbol maps before the convenience APK build so Play crash deobfuscation matches the uploaded bundle.


## 0.5.0+10

### Added
- In-app feedback from settings and help: optional email, category, and message sent via the device mail app with local diagnostics (no cloud backend).
- Scan screen dismissed-risk tracking so cleared alerts stay dismissed until signals change.
- Relative time labels on alert and scan surfaces for recent activity.
- Demo-mode banner and clearer scan lifecycle handling when demo protection is active.

### Changed
- Monetisation and feedback copy moved into dedicated copy modules for consistency and copy-guard tests.
- CI path filters, dev branch status checks, and testing/contributing documentation updates.

### Fixed
- No additional fixes in this release.


## 0.4.0+9

### Added
- Detection signature catalogue with signature matching to improve wearable/smart-glasses risk scoring.
- Scan UI risk level handling and clearer scan-state presentation during active detection.
- App version display on the about/settings surfaces via `package_info_plus`.
- AdMob configuration and `app-ads.txt` documentation for store compliance.

### Changed
- Android release workflow enhancements for Play internal publishing and release summaries.

### Fixed
- Ad UI is hidden when the user has removed ads (verified in widget tests).


## 0.3.1+8

### Added
- Release workflow now publishes the Google Play internal testing URL in the job summary after a successful internal upload.

### Changed
- Android Play upload status is `completed` so internal releases are published automatically instead of staying as drafts.

### Fixed
- No additional fixes in this release.


## 0.3.0+7

### Added
- Alert details now show clearer nearby device identity and proximity context.

### Changed
- Dark mode scan and alert surfaces use improved contrast for readability.
- Risk scoring now weighs signal distance/proximity alongside existing heuristics.

### Fixed
- Bluetooth permission handling now maps denied/permanently-denied states more reliably.
- App startup no longer triggers immediate false high-risk alert states.


## 0.2.2+6

### Fixed
- Android internal test scan failed on API 31+ because BLE scan requested fine location while the manifest only declares it for API 30 and below. Use `neverForLocation` on `BLUETOOTH_SCAN`, scan without location, and require Bluetooth runtime permissions on modern Android.

## 0.2.1+5

### Fixed
- Release workflow staged an unsigned intermediary AAB instead of the signed `app-release.aab`, causing Play Console "app not signed" errors.

## 0.2.1+4

### Changed
- Release Android workflow runs automatically on `main` when version changes; uploads to Play internal (draft) and creates GitHub Release.

## 0.2.1+3

### Fixed
- Release Android workflow YAML: signing step no longer uses shell grouping that broke GitHub’s workflow parser (line 119).

### Changed
- 

### Fixed
- 


## 0.2.0+2

### Added
- Android release pipeline (signed AAB/APK, GitHub Actions, optional Play upload).
- Static site and privacy policy at unrecorded.app.
- Optional banner ads and remove-ads IAP; AdMob and Play billing integration.
- Home screen widget, local risk notifications, and notification threshold settings.
- App shell navigation, alert details route, and nearby-signals UI on scan screen.
- SVG branding assets, adaptive launcher icons, and splash screen.
- Dev container improvements (host ADB, Gradle build dir, demo scan scenarios).
- Git workflow docs, `tool/git/` scripts, and agent playbooks under `skills/`.

### Changed
- Scan and settings UI refresh; help screen layout; debug testing section.
- Risk notification handling and deep links from notifications.
- Scanner configuration (emulator detection, fake scanner demo modes).

### Fixed
- Widget tap-to-open and banner ad load notifications.
- Dev-container build symlink removed from version control.
- Format and CI fixes across the monorepo.

## 0.1.0+1

### Added
- Initial Android release pipeline scaffolding.

### Changed
- 

### Fixed
- 
