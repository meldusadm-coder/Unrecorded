#!/usr/bin/env python3
"""Bulk-create remove-ads one-time products on Google Play (monetization API).

Product IDs: remove_ads_{pence} for each tier (default 25p–£20.00 in 25p steps).

Uses monetization.onetimeproducts.batchUpdate (legacy inappproducts is deprecated).

Examples:
  python tool/play/create_remove_ads_products.py --dry-run
  python tool/play/create_remove_ads_products.py --apply \\
    --credentials /path/to/play-service-account.json
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

DEFAULT_PACKAGE = "app.unrecorded.unrecorded_mobile"
DEFAULT_FROM_PENCE = 25
DEFAULT_TO_PENCE = 2000
DEFAULT_STEP_PENCE = 25
DEFAULT_BATCH_SIZE = 100
DEFAULT_REGIONS_VERSION = "2025/02"
PURCHASE_OPTION_ID = "default-buy"
PRODUCT_TITLE = "Remove ads"
PRODUCT_DESCRIPTION = (
    "One-time payment to remove banner ads. Core Bluetooth scanning stays free."
)
DEFAULT_LANGUAGE = "en-GB"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
LATENCY_TOLERANT = "PRODUCT_UPDATE_LATENCY_TOLERANCE_LATENCY_TOLERANT"


@dataclass(frozen=True)
class ProductTier:
    pence: int
    sku: str
    price_gbp: str

    @staticmethod
    def from_pence(pence: int) -> ProductTier:
        gbp = pence / 100
        return ProductTier(
            pence=pence,
            sku=f"remove_ads_{pence}",
            price_gbp=f"£{gbp:.2f}",
        )


def iter_tiers(
    from_pence: int, to_pence: int, step_pence: int
) -> list[ProductTier]:
    tiers: list[ProductTier] = []
    pence = from_pence
    while pence <= to_pence:
        tiers.append(ProductTier.from_pence(pence))
        pence += step_pence
    return tiers


def money_gbp(pence: int) -> dict[str, Any]:
    """Play Money for GBP from integer pence."""
    return {
        "currencyCode": "GBP",
        "units": str(pence // 100),
        "nanos": (pence % 100) * 10_000_000,
    }


def load_credentials(path: str | None) -> dict[str, Any]:
    if path:
        return json.loads(Path(path).read_text(encoding="utf-8"))

    raw = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON")
    if raw:
        return json.loads(raw)

    b64 = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64")
    if b64:
        return json.loads(base64.b64decode(b64).decode("utf-8"))

    raise SystemExit(
        "No credentials: pass --credentials or set "
        "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON / _BASE64"
    )


def build_one_time_product(tier: ProductTier, package_name: str) -> dict[str, Any]:
    return {
        "packageName": package_name,
        "productId": tier.sku,
        "listings": [
            {
                "languageCode": DEFAULT_LANGUAGE,
                "title": PRODUCT_TITLE,
                "description": PRODUCT_DESCRIPTION,
            }
        ],
        "taxAndComplianceSettings": {
            "regionalTaxConfigs": [{"regionCode": "GB"}],
        },
        "purchaseOptions": [
            {
                "purchaseOptionId": PURCHASE_OPTION_ID,
                "buyOption": {"legacyCompatible": True},
                "regionalPricingAndAvailabilityConfigs": [
                    {
                        "regionCode": "GB",
                        "price": money_gbp(tier.pence),
                        "availability": "AVAILABLE",
                    }
                ],
                "taxAndComplianceSettings": {
                    "withdrawalRightType": "WITHDRAWAL_RIGHT_DIGITAL_CONTENT",
                },
            }
        ],
    }


def build_batch_update_request(
    tier: ProductTier,
    package_name: str,
    regions_version: str,
) -> dict[str, Any]:
    return {
        "oneTimeProduct": build_one_time_product(tier, package_name),
        "updateMask": "listings,purchaseOptions,taxAndComplianceSettings",
        "regionsVersion": {"version": regions_version},
        "allowMissing": True,
        "latencyTolerance": LATENCY_TOLERANT,
    }


def build_activate_request(
    tier: ProductTier, package_name: str
) -> dict[str, Any]:
    return {
        "activatePurchaseOptionRequest": {
            "packageName": package_name,
            "productId": tier.sku,
            "purchaseOptionId": PURCHASE_OPTION_ID,
            "latencyTolerance": LATENCY_TOLERANT,
        }
    }


def get_android_publisher(credentials_info: dict[str, Any]):
    from google.oauth2 import service_account
    from googleapiclient.discovery import build

    creds = service_account.Credentials.from_service_account_info(
        credentials_info, scopes=[SCOPE]
    )
    return build("androidpublisher", "v3", credentials=creds, cache_discovery=False)


def is_service_disabled_error(exc: BaseException) -> bool:
    text = str(exc)
    return "SERVICE_DISABLED" in text or "has not been used in project" in text


def is_caller_permission_denied(exc: BaseException) -> bool:
    text = str(exc)
    return "does not have permission" in text or "caller does not have permission" in text


def is_legacy_api_deprecated(exc: BaseException) -> bool:
    return "migrate to the new publishing API" in str(exc)


def is_billing_permission_required(exc: BaseException) -> bool:
    return "request billing permission" in str(exc)


def activation_url_from_error(exc: BaseException) -> str | None:
    import re

    match = re.search(
        r"https://console\.developers\.google\.com/apis/api/androidpublisher\.googleapis\.com/overview\?project=\d+",
        str(exc),
    )
    return match.group(0) if match else None


def print_fatal_api_help(
    exc: BaseException,
    project_id: str | None,
    *,
    service_account_email: str | None = None,
) -> None:
    print("\n*** Play API call failed — stopping (fix below, then re-run) ***\n", file=sys.stderr)
    if is_legacy_api_deprecated(exc):
        print(
            "Google no longer accepts the legacy inappproducts API for this app.",
            file=sys.stderr,
        )
        print(
            "This script uses monetization.onetimeproducts instead. "
            "Update to the latest repo version and re-run.\n",
            file=sys.stderr,
        )
        return
    if is_billing_permission_required(exc):
        print(
            'Play returned "request billing permission" — this is not fixed by the '
            "Admin user role alone. Billing catalog writes need financial access and "
            "a billing-ready developer account.\n",
            file=sys.stderr,
        )
        print(
            "Checklist:\n"
            "1. Payments / merchant: Play Console → set up payments profile "
            "(Download reports → Financial, or Monetize setup) so you can sell IAP.\n"
            "2. Service account — Account permissions:\n"
            "   • View financial data, orders, and cancellation survey responses\n"
            "3. Service account — App permissions (Unrecorded):\n"
            "   • Manage orders and subscriptions\n"
            "   (Keep Admin or Manage store presence as well.)\n"
            "4. Upload at least one AAB with Play Billing (in_app_purchase) to internal "
            "testing — Google enables catalog APIs after a billing-capable build exists.\n"
            "5. Fast workaround: Play Console → Monetize → Products → One-time products → "
            "manually create remove_ads_25, save, wait 2–5 minutes, re-run this script.\n",
            file=sys.stderr,
        )
        return
    if is_caller_permission_denied(exc):
        email = service_account_email or "(see client_email in your JSON key)"
        print(
            "The service account is authenticated but not allowed to manage "
            "one-time products for this app.",
            file=sys.stderr,
        )
        print(
            f"\nService account: {email}\n"
            "\nFix in Play Console:\n"
            "1. Play Console → Users and permissions\n"
            "2. Invite or edit the service account (same client_email as the JSON key)\n"
            "3. Grant app permissions for Unrecorded, including catalog/monetization:\n"
            "   - **Admin (all permissions)**, or\n"
            "   - Permissions that include managing one-time products / monetization\n"
            "4. Wait a few minutes, then re-run.\n",
            file=sys.stderr,
        )
        return
    if is_service_disabled_error(exc):
        print(
            "The Google Play Android Developer API is disabled on your Cloud project.",
            file=sys.stderr,
        )
        if project_id:
            url = (
                "https://console.developers.google.com/apis/api/"
                f"androidpublisher.googleapis.com/overview?project={project_id}"
            )
        else:
            url = activation_url_from_error(exc)
        if url:
            print(f"\n1. Enable the API:\n   {url}\n", file=sys.stderr)
        else:
            print(
                "\n1. Google Cloud Console → APIs & Services → Library → "
                'search "Google Play Android Developer API" → Enable\n',
                file=sys.stderr,
            )
        print(
            "2. Wait 2–5 minutes for propagation.\n"
            "3. Play Console → Users and permissions → confirm the service account "
            "has app permissions.\n"
            "4. Re-run: ./tool/play/run.sh --apply --credentials …\n",
            file=sys.stderr,
        )
        return
    if "Regions version" in str(exc) or "regionsVersion" in str(exc):
        print(
            "Invalid or outdated regionsVersion. Check the current version on:\n"
            "  https://play.google.com/supported-locations/\n"
            "Then re-run with: --regions-version YYYY/MM\n",
            file=sys.stderr,
        )
    print(str(exc), file=sys.stderr)


def product_exists(service: Any, package_name: str, product_id: str) -> bool:
    try:
        service.monetization().onetimeproducts().get(
            packageName=package_name, productId=product_id
        ).execute()
        return True
    except Exception as exc:
        if hasattr(exc, "resp") and getattr(exc.resp, "status", None) == 404:
            return False
        raise


def chunk_list(items: list[Any], size: int) -> list[list[Any]]:
    return [items[i : i + size] for i in range(0, len(items), size)]


def batch_upsert_products(
    service: Any,
    package_name: str,
    tiers: list[ProductTier],
    *,
    regions_version: str,
) -> None:
    onetime = service.monetization().onetimeproducts()
    body = {
        "requests": [
            build_batch_update_request(t, package_name, regions_version) for t in tiers
        ]
    }
    onetime.batchUpdate(packageName=package_name, body=body).execute()


def batch_activate_purchase_options(
    service: Any,
    package_name: str,
    tiers: list[ProductTier],
) -> None:
    po = service.monetization().onetimeproducts().purchaseOptions()
    body = {"requests": [build_activate_request(t, package_name) for t in tiers]}
    po.batchUpdateStates(
        packageName=package_name,
        productId="-",
        body=body,
    ).execute()


def upsert_and_activate(
    service: Any,
    package_name: str,
    tiers: list[ProductTier],
    *,
    regions_version: str,
    skip_existing: bool,
    batch_size: int,
    delay_seconds: float,
) -> tuple[int, int]:
    """Returns (created_count, skipped_count)."""
    to_create: list[ProductTier] = []
    skipped = 0
    for tier in tiers:
        if skip_existing and product_exists(service, package_name, tier.sku):
            skipped += 1
            print(f"  skipped  {tier.sku} (exists)")
        else:
            to_create.append(tier)

    if not to_create:
        return 0, skipped

    batches = chunk_list(to_create, batch_size)
    for i, batch in enumerate(batches):
        batch_upsert_products(
            service, package_name, batch, regions_version=regions_version
        )
        batch_activate_purchase_options(service, package_name, batch)
        for tier in batch:
            print(f"  created  {tier.sku} {tier.price_gbp}")
        if delay_seconds > 0 and i < len(batches) - 1:
            time.sleep(delay_seconds)

    return len(to_create), skipped


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Create products via API (default: dry-run only)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print tiers without API calls (default when --apply omitted)",
    )
    parser.add_argument("--credentials", help="Path to service account JSON")
    parser.add_argument("--package", default=DEFAULT_PACKAGE)
    parser.add_argument("--from-pence", type=int, default=DEFAULT_FROM_PENCE)
    parser.add_argument("--to-pence", type=int, default=DEFAULT_TO_PENCE)
    parser.add_argument("--step-pence", type=int, default=DEFAULT_STEP_PENCE)
    parser.add_argument(
        "--regions-version",
        default=DEFAULT_REGIONS_VERSION,
        help="Play supported-locations version (e.g. 2025/02)",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=DEFAULT_BATCH_SIZE,
        help="Products per batchUpdate call (max 100)",
    )
    parser.add_argument(
        "--delay-seconds",
        type=float,
        default=1.0,
        help="Pause between batch API calls",
    )
    parser.add_argument(
        "--no-skip-existing",
        action="store_true",
        help="Fail if product already exists instead of skipping",
    )
    args = parser.parse_args()

    batch_size = min(max(1, args.batch_size), 100)

    dry_run = not args.apply

    tiers = iter_tiers(args.from_pence, args.to_pence, args.step_pence)
    print(f"Tiers: {len(tiers)} ({tiers[0].price_gbp} – {tiers[-1].price_gbp})")
    print(f"Package: {args.package}")
    print(f"API: monetization.onetimeproducts (regions {args.regions_version})")
    print(f"Mode: {'dry-run' if dry_run else 'apply'}\n")

    if dry_run:
        for tier in tiers:
            print(f"  {tier.sku:20} {tier.price_gbp}")
        print(f"\n{len(tiers)} products would be created. Re-run with --apply.")
        return 0

    creds = load_credentials(args.credentials)
    project_id = creds.get("project_id")
    sa_email = creds.get("client_email")
    if project_id:
        print(f"Service account Cloud project: {project_id}")
    if sa_email:
        print(f"Service account email: {sa_email}")
    service = get_android_publisher(creds)
    skip_existing = not args.no_skip_existing

    created = skipped = failed = 0
    abort = False
    try:
        n_created, n_skipped = upsert_and_activate(
            service,
            args.package,
            tiers,
            regions_version=args.regions_version,
            skip_existing=skip_existing,
            batch_size=batch_size,
            delay_seconds=args.delay_seconds,
        )
        created = n_created
        skipped = n_skipped
    except Exception as exc:
        failed = len(tiers) - skipped
        print(f"  FAILED   batch: {exc}", file=sys.stderr)
        print_fatal_api_help(exc, project_id, service_account_email=sa_email)
        abort = True

    print(f"\nDone: created={created} skipped={skipped} failed={failed}")
    if abort:
        print("Aborted early — fix Play API access above, then re-run.", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
