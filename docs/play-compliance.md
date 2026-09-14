# Google Play release review — 13 September 2026

Version prepared: 0.9.5+21. This is a technical review, not confirmation of Play approval.

- Android updates explicitly target API 36; compile SDK is at least 36.
- Existing Billing 8 meets the current submission requirement. Verify the resolved Android dependency and merged billing version metadata in the release build.
- Existing AGP 8.11.1 supports 16 KB packaging. Release CI now checks every bundled 64-bit native ELF library; physical/emulator testing on a 16 KB device is still needed.
- Bluetooth permissions remain bounded: legacy location only through API 30, neverForLocation on Android 12+, connectedDevice foreground-service type, user-controlled background protection, no boot restart.
- Ads wait for the UMP form callback and canRequestAds before SDK initialisation; changes to privacy choices invalidate and dispose ads. Scan data remains separate from ads.
- Flutter 3.47.4 is pinned in CI/release, with refreshed compatible Pub dependencies and enforced lockfile resolution. GitHub checkout, Java/Node setup and artifact actions use current releases.
- The website's vulnerable js-yaml dependencies were updated. npm audit and site verification are now required in CI. Dependabot monitors pub, npm, Gradle and Actions weekly against dev.

## Outstanding hosting and Console actions

The live /privacy.html and /privacy URLs returned HTTP 404 during this review. The Eleventy build creates the policy correctly. Do not mark issue #110 resolved until live verification and Console resubmission succeed.

`.github/workflows/deploy-site.yml` is the production deployment path: a relevant push to `main` runs the locked Eleventy build and verification, audits npm dependencies, and uploads `apps/site/_site` to the Cloudflare Pages project. It requires the `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` Actions secrets; `CLOUDFLARE_PAGES_PROJECT` may override the default project name `unrecorded`. Do not enable a second Cloudflare Git build or publish the source directory. If a successful Pages upload still leaves the domain unavailable, check its custom-domain assignment and Workers routes.

Run `python3 tool/release/check_public_site.py` after deployment. Android release CI blocks Play upload if the public policy or required assets are invalid.

In Play Console, confirm and resubmit the working privacy URL, reconcile Data safety with the installed AdMob SDK's data disclosures (including advertising identifiers/IP-derived approximate location), review the connectedDevice foreground-service declaration/video, advertising-ID and ads declarations, content rating, target audience, and developer verification status. No account-deletion flow is applicable while the app has no accounts. These account-specific declarations cannot be confirmed from source code alone.

Before production promotion, run Android 16 BLE, notification permission denial, background start/stop, ad consent/revocation and purchase/restore smoke tests. The existing release workflow uploads to internal testing; it does not publish to production automatically.

## Official references

- https://support.google.com/googleplay/android-developer/answer/11926878
- https://developer.android.com/google/play/billing/deprecation-faq
- https://developer.android.com/guide/practices/page-sizes
- https://developer.android.com/about/versions/16/behavior-changes-16
- https://developers.google.com/admob/flutter/privacy
