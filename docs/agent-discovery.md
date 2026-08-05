# Markdown for Agents (unrecorded.app)

Optional Cloudflare zone setting for [unrecorded.app](https://unrecorded.app). Helps AI agents request markdown instead of HTML when reading public pages about the Unrecorded Android app.

Static content indexes (`llms.txt`, `sitemap.xml`, `auth.md`) are generated or copied by the Eleventy site build in `apps/site/`. Cloudflare Pages should use root directory `apps/site`, build command `npm run build`, output directory `_site`, and `NODE_VERSION=20`.

## What this site does not publish

`unrecorded.app` is a static marketing site. It does **not** expose:

- MCP servers or WebMCP tools
- Agent Skills indexes (dev/release playbooks stay in the GitHub repo only)
- OAuth or protected APIs
- DNS-AID agent endpoint records (no agent services on this domain)

## Enable Markdown for Agents

Markdown for Agents converts HTML to Markdown when clients send `Accept: text/markdown`. Requires Cloudflare **Pro**, **Business**, or **Enterprise**.

### Dashboard

1. [Cloudflare dashboard](https://dash.cloudflare.com/) → select the `unrecorded.app` zone.
2. **AI Crawl Control** (or **Rules → Configuration rules** on some plans).
3. Enable **Markdown for Agents**.

### API

```bash
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/{zone_id}/settings/content_converter" \
  --header "Authorization: Bearer {api_token}" \
  --header "Content-Type: application/json" \
  --data '{"value":"on"}'
```

Requires an API token with **Zone Settings → Edit**.

### Verify

```bash
curl -sI https://unrecorded.app/ -H "Accept: text/markdown" | grep -iE '^(content-type|x-markdown-tokens):'
```

Expected:

- `Content-Type: text/markdown`
- `x-markdown-tokens` present (token estimate)

See [Cloudflare Markdown for Agents docs](https://developers.cloudflare.com/fundamentals/reference/markdown-for-agents/).

## Public content files

| Path | Purpose |
|------|---------|
| `/llms.txt` | Markdown site index |
| `/auth.md` | Notes that the site is public (no login) |
| `/.well-known/api-catalog` | RFC 9727 linkset for content endpoints |
| `/.well-known/openapi/content-discovery.yaml` | OpenAPI description of public endpoints |
