# Privacy model

Unrecorded is designed to be privacy-protective by default.

## Principles

- **Local-first scanning.** All detection and scoring happens on-device. No scan data leaves the phone.
- **No account required.** The app works without sign-up, login, or any user account.
- **No cloud upload by default.** Scan results stay on-device unless the user explicitly chooses to export or share them.
- **No third-party tracking in core scanning.** Analytics and telemetry are not included.
- **No analytics by default.** Usage data is not collected.
- **Ads policy.** Official builds may show small bottom banner ads (see [docs/monetisation.md](monetisation.md)). Ads are isolated from scan logic: no scan results or nearby device identifiers are sent to ad networks. Non-personalised ads are used by default until consent allows otherwise. Pay-what-you-want IAP can remove ads; core detection stays free.
- **Scan data stays on-device.** If future features add optional cloud sync or sharing, they must require explicit user consent and clearly explain what data is sent and where.
