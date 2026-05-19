# Monetisation

## Overview

- **Banner ads:** Google AdMob bottom banners on scan (when no active alert), help, and settings.
- **Remove ads:** Pay-what-you-want non-consumable IAP tiers via `in_app_purchase`.
- **Core scanning:** Always free; payment only removes ads.

## Privacy boundary

- Ad and payment code lives under `apps/mobile/lib/services/` and feature screens only.
- `ScanController`, `unrecorded_core`, and `unrecorded_radio` never import ad or IAP SDKs.
- Scan results, device names, and identifiers are **never** passed to ad SDKs.
- Default ad requests use **non-personalised** ads until UMP consent allows otherwise.

## Manual setup

### AdMob

1. Create an AdMob app and banner ad unit.
2. Add your app ID to `AndroidManifest.xml` (`com.google.android.gms.ads.APPLICATION_ID`).
3. Pass the banner unit ID at build time:
   ```bash
   flutter run --dart-define=ADMOB_BANNER_ID=ca-app-pub-XXXX/YYYY
   ```
4. Configure UMP consent in AdMob for UK/GDPR.

Debug builds use Google’s test banner ID by default.

### In-app purchase

Create non-consumable products in Play Console / App Store Connect:

| Product ID     | Suggested tier |
|----------------|----------------|
| `remove_ads_1` | £1             |
| `remove_ads_3` | £3             |
| `remove_ads_5` | £5             |
| `remove_ads_10`| £10            |

Use license testers for sandbox purchases.

### Dev bypass

```bash
flutter run --dart-define=UNRECORDED_ADS_REMOVED=true
```

## Custom amount

Not in MVP — fixed tiers only. Document as a future enhancement if store APIs allow variable pricing in your target regions.
