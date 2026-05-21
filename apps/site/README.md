# Unrecorded website (`unrecorded.app`)

Static marketing site and privacy policy for [Unrecorded](https://unrecorded.app). No build step, no analytics, no cookies, and no third-party scripts.

## What this is

- **`index.html`** — public landing page
- **`privacy.html`** — privacy policy (for app stores and the site)
- **`privacy/index.html`** — redirects to `privacy.html` for `/privacy/` URLs
- **`src/styles.css`** — shared styles (brand tokens from `docs/brand-colors.json`)
- **`assets/`** — favicon, social preview image, and copies of repo brand SVGs

## Run locally

From this directory:

```bash
# Python 3
python3 -m http.server 8080

# or Node (if npx is available)
npx --yes serve -l 8080
```

Open:

- http://localhost:8080/
- http://localhost:8080/privacy.html

Paths use root-relative URLs (`/src/...`, `/assets/...`), so serve from `apps/site` (not a parent folder) unless your host rewrites paths.

## Build

There is **no build step**. Deploy the `apps/site` folder as static files.

Optional checks before deploy:

```bash
# Validate HTML (if html5validator is installed)
html5validator --also-check-css index.html privacy.html
```

## Suggested hosting

Any static host works, for example:

- **Cloudflare Pages** — connect repo, publish directory `apps/site`, custom domain `unrecorded.app`
- **GitHub Pages** — publish from `/apps/site` via Actions or branch docs
- **Netlify / Vercel** — static publish root `apps/site`

Configure HTTPS and the apex domain (`unrecorded.app` + `www` redirect as you prefer). No server-side code is required.

## Branding assets

| File | Source |
|------|--------|
| `assets/logo-mark.svg` | `packages/unrecorded_ui/assets/brand/unrecorded-logo-mark.svg` |
| `assets/logo-horizontal.svg` | `packages/unrecorded_ui/assets/brand/unrecorded-logo-horizontal.svg` |
| `assets/app-icon-accent.svg` | `packages/unrecorded_ui/assets/brand/unrecorded-app-icon-accent.svg` |
| `assets/favicon.svg` | Derived from logo mark |
| `assets/social-card.svg` | Site-specific Open Graph image |

Colour tokens match `packages/unrecorded_ui/lib/src/app_theme.dart` and `docs/brand-colors.json`. Update copies here if the mobile brand kit changes.

## Editing copy

| Content | File |
|---------|------|
| Landing page | `index.html` |
| Privacy policy | `privacy.html` |
| Styles | `src/styles.css` |

After privacy policy changes, update the **effective date** in `privacy.html` and review before Google Play / app store submission.

## Google Play and AdMob

Use this URL in Play Console and AdMob app settings:

**`https://unrecorded.app/privacy.html`**

The policy names **Google AdMob**, local BLE processing, optional IAP, no accounts, and no core analytics. See [`docs/release.md`](../../docs/release.md#privacy-policy-url-required).

## TODOs before launch

- [x] Legal entity: **Meldlife Ltd** — section 1 in `privacy.html`
- [x] Privacy contact: **privacy@unrecorded.app** — sections 1, 16, 19, footer
- [ ] Add registered company address in `privacy.html` if required by your jurisdiction or app store
- [ ] Confirm **GitHub URL** (currently `https://github.com/meldusadm-coder/Unrecorded`)
- [ ] Deploy site and verify `https://unrecorded.app/privacy.html` is publicly reachable (AdMob rejects geofenced or login-walled URLs)
- [ ] Add **Google Play / App Store** links when available (replace “Coming soon” on the homepage)
- [ ] Review privacy policy with counsel before store submission
- [ ] Point DNS for `unrecorded.app` at the chosen static host
