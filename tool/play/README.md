# Play Console tooling

## Bulk-create remove-ads products

Creates one-time (non-consumable) products via the **monetization.onetimeproducts** API (Google deprecated legacy `inappproducts` for new catalog work).

Pay-what-you-want tiers:

- **80 products** by default: `remove_ads_25` … `remove_ads_2000`
- **Prices:** £0.25–£20.00 in **25p** steps
- Must match [RemoveAdsPricing](../../apps/mobile/lib/services/remove_ads_pricing.dart) in the app

### Prerequisites

1. **Google Play Android Developer API** enabled on the **same Google Cloud project** as your service account JSON (`project_id` field).  
   If you see `SERVICE_DISABLED` / `created=0 failed=80`, enable it here (replace `PROJECT_ID` with your project number, e.g. `673154140353`):

   https://console.developers.google.com/apis/api/androidpublisher.googleapis.com/overview?project=PROJECT_ID

   Click **Enable**, wait 2–5 minutes, then re-run the script.

2. **Service account** with Play Console access (same JSON as CI release upload is fine).
3. Play Console → **Users and permissions** → invite the service account (`client_email` in the JSON) with **Admin** or permissions that include managing one-time products / monetization for the app.
4. Python 3.10+.

### Install

Linux / dev container use **`python3`** (there is no `python` / `pip` command by default). Debian blocks system-wide `pip install` (PEP 668), so use a venv:

```bash
# One-time: venv + deps
python3 -m venv tool/play/.venv
tool/play/.venv/bin/pip install -r tool/play/requirements.txt
```

**Easiest:** use the helper script (creates `.venv` automatically):

```bash
chmod +x tool/play/run.sh
./tool/play/run.sh --dry-run
./tool/play/run.sh --apply --credentials store/android/your-service-account.json
```

If `python3 -m venv` fails, run: `sudo apt-get install -y python3-venv python3-pip`

### Dry run (no API calls)

```bash
python3 tool/play/create_remove_ads_products.py --dry-run
# or: ./tool/play/run.sh --dry-run
```

### Create products

```bash
python3 tool/play/create_remove_ads_products.py --apply \
  --credentials store/android/your-service-account.json
```

Or with an env var (same as GitHub Actions):

```bash
export GOOGLE_PLAY_SERVICE_ACCOUNT_JSON="$(cat store/android/your-service-account.json)"
python3 tool/play/create_remove_ads_products.py --apply
```

**Never commit** service account JSON — `store/android/*.json` is gitignored.

Base64 env var `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64` is also supported (same as GitHub Actions).

### Options

| Flag | Default | Purpose |
|------|---------|---------|
| `--dry-run` | on | List SKUs only |
| `--apply` | off | Call Play API |
| `--package` | `app.unrecorded.unrecorded_mobile` | App package name |
| `--from-pence` | `25` | First tier (pence) |
| `--to-pence` | `2000` | Last tier (pence) |
| `--step-pence` | `25` | Step between tiers |
| `--regions-version` | `2025/02` | Play [supported locations](https://play.google.com/supported-locations/) version |
| `--batch-size` | `100` | Products per API batch (max 100) |
| `--delay-seconds` | `1.0` | Pause between batch calls |
| `--no-skip-existing` | off | Error on duplicate SKU instead of skip |

### After creation

1. Confirm products are **Active** in Play Console → **Monetize** → **Products**.
2. Add license testers for internal testing.
3. Install a release/internal build and test **Settings → Remove ads** slider.

### Troubleshooting

| Error | Action |
|-------|--------|
| `SERVICE_DISABLED` / API not used in project | Enable **Google Play Android Developer API** on the Cloud project (link above). Wait a few minutes. Re-run. |
| `request billing permission` | Not the Admin role — enable **View financial data** (account) + **Manage orders and subscriptions** (app) on the service account; complete **payments/merchant** setup; upload an AAB with billing library to internal testing; or create one product manually in Play Console first (see script error text). |
| `Please migrate to the new publishing API` | You are on an old script using `inappproducts`. Pull latest `tool/play/create_remove_ads_products.py` (uses `monetization.onetimeproducts`) and re-run. |
| `The caller does not have permission` | Play Console → **Users and permissions** → grant the service account **Admin** (or monetization/catalog) on the Unrecorded app. Wait a few minutes. Re-run. |
| 403 / other permission denied | Same as above — API enabled but Play Console has not granted the service account access to this app |
| `Regions version` / `regionsVersion` | Set `--regions-version` to the current value from [supported locations](https://play.google.com/supported-locations/) (e.g. `2025/02`) |
| Product already exists | Normal on re-run; skipped unless `--no-skip-existing` |
| Quota / rate limit | Increase `--delay-seconds` and re-run (skips existing) |
