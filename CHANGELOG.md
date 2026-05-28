# Changelog

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
