# Monetisation

## Overview

- **Banner ads:** Google AdMob bottom banners on scan (when no active alert), help, and settings.
- **Remove ads:** Pay-what-you-want non-consumable IAP — user enters any amount (default **£2.00**, range **£0.50–£100.00**).
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

App stores require **one product per price**. The app maps the user’s GBP amount to a product ID:

| User amount | Product ID        |
|-------------|-------------------|
| £2.00       | `remove_ads_200`  |
| £5.50       | `remove_ads_550`  |
| £10.00      | `remove_ads_1000` |

Pattern: `remove_ads_{pence}` where pence = amount × 100 (rounded).

**Play Console / App Store Connect**

1. Create **non-consumable** products for each price you want to support.
2. At minimum, create `remove_ads_200` for the default £2 tier.
3. For full flexibility, bulk-create products for the pence values you expect (e.g. every 50p from 50p to £20, or use store APIs/scripts).
4. Legacy tier IDs (`remove_ads_1`, `remove_ads_3`, `remove_ads_5`, `remove_ads_10`) still work for restore if you already shipped them.

Use license testers (Play) or Sandbox (Apple) for test purchases.

If a product ID is missing in the store, the app tells the user that amount is not available and suggests trying common amounts (e.g. £2.00).

### Dev bypass

```bash
flutter run --dart-define=UNRECORDED_ADS_REMOVED=true
```

## Store limitation

Apple and Google do not support a single “any amount” SKU. The UI lets users type any value in range; the purchase uses the matching `remove_ads_{pence}` product. Amounts without a store product cannot be purchased until that product exists.
