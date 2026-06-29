# Privacy model

Unrecorded is designed to be privacy-protective by default.

**Public privacy policy (Play, AdMob, stores):** [https://unrecorded.app/privacy.html](https://unrecorded.app/privacy.html) — maintained in [`apps/site/privacy.html`](../apps/site/privacy.html).

**Public guides (site):**

- [Detection limitations FAQ](https://unrecorded.app/detection-limitations.html)
- [How smart glasses use BLE broadcasts](https://unrecorded.app/how-smart-glasses-broadcast-ble.html)
- [Known smart glasses BLE patterns](https://unrecorded.app/smart-glasses-ble-patterns.html)
- [Privacy in public spaces](https://unrecorded.app/how-to-avoid-being-recorded-by-smart-glasses.html)

## Principles

- **Local-first scanning.** All detection and scoring happens on-device. No scan data leaves the phone.
- **No account required.** The app works without sign-up, login, or any user account.
- **No cloud upload by default.** Scan results stay on-device unless the user explicitly chooses to export or share them.
- **No third-party tracking in core scanning.** Analytics and telemetry are not included.
- **No analytics by default.** Usage data is not collected.
- **Ads policy.** Official builds may show small bottom banner ads (see [docs/monetisation.md](monetisation.md)). Ads are isolated from scan logic: no scan results or nearby device identifiers are sent to ad networks. All ad requests use non-personalised ads only. Pay-what-you-want IAP can remove ads; core detection stays free.
- **Scan data stays on-device.** If future features add optional cloud sync or sharing, they must require explicit user consent and clearly explain what data is sent and where.

**Android permission inventory (Play Console / release manifest):** [docs/android-permissions.md](android-permissions.md).
