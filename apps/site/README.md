# Unrecorded website (`unrecorded.app`)

Static marketing site and privacy policy for [Unrecorded](https://unrecorded.app). The site is built with Eleventy into `_site/`. There are no analytics, cookies, accounts, telemetry, or third-party scripts on the website.

## What this is

- `src/pages/index.njk` -> `/` (file `index.html`)
- `src/pages/privacy.njk` -> canonical `/privacy` (file `privacy.html`)
- `src/pages/privacy-redirect.njk` -> `/privacy/` redirect helper
- `src/pages/what-unrecorded-is.njk` -> canonical `/what-unrecorded-is`
- `src/pages/faq.njk` -> canonical `/faq`
- `src/pages/*.njk` -> four public smart-glasses guides (extensionless canonicals)
- `src/assets/styles.css` -> `/assets/styles.css`
- `src/sitemap.njk` -> generated `/sitemap.xml`
- `src/llms.njk` -> generated `/llms.txt`
- `src/robots.txt`, `src/app-ads.txt`, `src/auth.njk`, `src/_headers`, and `src/.well-known/**` -> public discovery files

Cloudflare Pages always redirects `*.html` to extensionless paths (for example `/privacy.html` → `/privacy`). Canonicals, sitemap entries, and internal links use those extensionless URLs so they match what Google indexes. Do **not** add zone Redirect Rules that send extensionless URLs back to `*.html` — that creates a redirect loop with Pages.

## Run locally

From `apps/site`:

```bash
npm install
npm run build
npm test
npm start
```

`npm test` runs an Eleventy build and then `scripts/verify-site.mjs`, which checks required public files, sitemap/llms coverage, product-truth copy, and stale `/src/styles.css` references.

## Host on Cloudflare Pages

Use Cloudflare Pages Git deploys. `_site/` is gitignored, so Pages must run the build instead of serving checked-in output.

| Setting | Value |
|---------|-------|
| Root directory | `apps/site` |
| Build command | `npm run build` |
| Build output directory | `_site` |
| Environment variable | `NODE_VERSION=20` |

Do not configure Pages to publish `apps/site` directly. Old flat HTML files are no longer the source of truth; Eleventy templates under `src/` build the deployable site.

### Post-deploy verification

```bash
curl -sI https://unrecorded.app/robots.txt
curl -sI https://unrecorded.app/sitemap.xml
curl -sI https://unrecorded.app/ | grep -i '^link:'
curl -s https://unrecorded.app/llms.txt | head

curl -sI https://unrecorded.app/auth.md | grep -i content-type
curl -s https://unrecorded.app/.well-known/api-catalog | head

# Markdown for Agents, after enabling in Cloudflare dashboard on eligible plans
curl -sI https://unrecorded.app/ -H 'Accept: text/markdown' | grep -iE '^(content-type|x-markdown-tokens):'
```

`_headers` is applied by Cloudflare Pages, not by `npm start` or simple local static servers.

## AI / SEO files

Eleventy generates `sitemap.xml` and `llms.txt` from pages with `canonicalPath` front matter unless `sitemap: false` is set. `auth.md` is a small Eleventy template so it can stay in the sitemap while still publishing at `/auth.md`.

Keep `Content-Signal: ai-train=no, search=yes, ai-input=yes` in `robots.txt`. Static discovery files deploy with the built site:

| File | Purpose |
|------|---------|
| `robots.txt` | Allow public pages; explicit AI crawler rules; references sitemap |
| `sitemap.xml` | Generated canonical page list |
| `llms.txt` | Generated markdown index for AI agents |
| `auth.md` | Public-site note for agents; no authentication |
| `.well-known/*` | Content discovery catalog, OpenAPI spec, status |
| `_headers` | Link headers and content types for Cloudflare Pages |

Optional Cloudflare Markdown for Agents setup is documented in [docs/agent-discovery.md](../../docs/agent-discovery.md).

## Google Play and AdMob

Use either of these public policy URLs in Play Console and AdMob (both resolve to the same policy; Pages redirects `.html` to the extensionless path):

**`https://unrecorded.app/privacy`**  
**`https://unrecorded.app/privacy.html`**

The policy names Google AdMob, local BLE processing, optional IAP, no accounts, and no core analytics. See [docs/release.md](../../docs/release.md#privacy-policy-url-required).

### app-ads.txt (AdMob)

Publish this file at:

**`https://unrecorded.app/app-ads.txt`**

Required content:

```text
google.com, pub-5555183606520770, DIRECT, f08c47fec0942fa0
```

After deployment, allow at least 24 hours for AdMob to crawl and verify.

## Branding assets

| File | Source |
|------|--------|
| `src/assets/logo-mark.svg` | `packages/unrecorded_ui/assets/brand/unrecorded-logo-mark.svg` |
| `src/assets/logo-horizontal.svg` | `packages/unrecorded_ui/assets/brand/unrecorded-logo-horizontal.svg` |
| `src/assets/app-icon-accent.svg` | `packages/unrecorded_ui/assets/brand/unrecorded-app-icon-accent.svg` |
| `src/assets/favicon.svg` | Derived from logo mark |
| `src/assets/social-card.png` | Open Graph / Twitter preview image (1200x630 PNG) |
| `src/assets/social-card.svg` | Source artwork for social card |

Colour tokens match `packages/unrecorded_ui/lib/src/app_theme.dart` and `docs/brand-colors.json`.
