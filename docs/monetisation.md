# Monetisation

## Overview

- **Banner ads:** Google AdMob bottom banners on scan (when no active alert), help, and settings.
- **Remove ads:** Pay-what-you-want non-consumable IAP — slider from **£0.25–£20.00** in **25p** steps (default **£2.00**).
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
   For CI release builds, set GitHub Actions variable (or secret) `ADMOB_BANNER_ID` — see [release.md](release.md).
4. Configure UMP consent in AdMob for UK/GDPR.
5. Publish the European regulations message with **Ad unit deployment off** (the app uses UMP SDK).
6. Users change or withdraw ad consent via **Settings & Privacy → Ad privacy choices** (required revocation entry point).

Debug builds use Google’s test banner ID by default.

### In-app purchase (pay what you want)

App stores require **one product per price**. The app uses a **slider** with fixed tiers only:

| Range | Step | Product count | Pattern |
|-------|------|---------------|---------|
| £0.25–£20.00 | 25p | 80 | `remove_ads_{pence}` |

Examples:

| User amount | Product ID |
|-------------|------------|
| £0.25 | `remove_ads_25` |
| £2.00 | `remove_ads_200` |
| £5.50 | `remove_ads_550` |
| £20.00 | `remove_ads_2000` |

Pence = GBP × 100 (must be divisible by 25).

#### Bulk-create on Google Play

Use the Play Developer API script (same service account as CI upload):

```bash
./tool/play/run.sh --dry-run
./tool/play/run.sh --apply --credentials store/android/your-service-account.json
```

See [tool/play/README.md](../tool/play/README.md) (`python3` + venv; not `python` / `pip`).

See [tool/play/README.md](../tool/play/README.md).

**Play Console (manual):** Monetize → Products → create **non-consumable** products with IDs and prices matching the table above. At minimum ship `remove_ads_200` before wider tiers.

Legacy tier IDs (`remove_ads_1`, `remove_ads_3`, `remove_ads_5`, `remove_ads_10`) still work for restore if you already shipped them.

Use license testers (Play) or Sandbox (Apple) for test purchases.

If a tier is missing in the store, the remove-ads screen shows that the amount is unavailable.

### Dev bypass

```bash
flutter run --dart-define=UNRECORDED_ADS_REMOVED=true
```

## Store limitation

Apple and Google do not support a single “any amount” SKU. The UI offers **80 discrete tiers** on a slider; each maps to `remove_ads_{pence}`. Amounts outside £0.25–£20.00 or off the 25p grid are not offered (legacy purchases still restore).
