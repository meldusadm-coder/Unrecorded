# Changelog

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
