#!/usr/bin/env python3
"""
eBay Item Search - reads ebay-items.json, searches eBay, prints results.

Output format:
    ITEM NAME
      £123.45  https://www.ebay.com/itm/123456789
      £99.99   https://www.ebay.com/itm/987654321
"""

import json
import os
import sys
import base64
import time
from urllib.parse import quote

try:
    import requests
except ImportError:
    print("Install requests:  pip install requests")
    sys.exit(1)

# ─── CONFIG ──────────────────────────────────────────────────────────────────
# Get these from https://developer.ebay.com → Application Keys
# Set as environment variables, or paste them below.
CLIENT_ID = os.environ.get("EBAY_CLIENT_ID", "YOUR_APP_ID_HERE")
CLIENT_SECRET = os.environ.get("EBAY_CLIENT_SECRET", "YOUR_CERT_ID_HERE")
MARKETPLACE = os.environ.get("EBAY_MARKETPLACE", "EBAY-GB")  # EBAY-GB for UK
ITEMS_FILE = "ebay-items.json"
RESULTS_PER_ITEM = 5   # how many listings to show per item
# ─────────────────────────────────────────────────────────────────────────────

TOKEN_URL = "https://api.ebay.com/identity/v1/oauth2/token"
SEARCH_URL = "https://api.ebay.com/buy/browse/v1/item_summary/search"


def get_access_token():
    """Get an OAuth application token (client credentials flow)."""
    if CLIENT_ID.startswith("YOUR_") or CLIENT_SECRET.startswith("YOUR_"):
        print("❌ Set EBAY_CLIENT_ID and EBAY_CLIENT_SECRET first.")
        print("   export EBAY_CLIENT_ID='your-app-id'")
        print("   export EBAY_CLIENT_SECRET='your-cert-id'")
        sys.exit(1)

    credentials = base64.b64encode(
        f"{CLIENT_ID}:{CLIENT_SECRET}".encode()
    ).decode()

    headers = {
        "Authorization": f"Basic {credentials}",
        "Content-Type": "application/x-www-form-urlencoded",
    }
    body = "grant_type=client_credentials&scope=https://api.ebay.com/oauth/api_scope"

    resp = requests.post(TOKEN_URL, headers=headers, data=body, timeout=30)
    if not resp.ok:
        print(f"❌ Token request failed: {resp.status_code}")
        print(resp.text)
        sys.exit(1)

    return resp.json()["access_token"]


def search_item(token, query, limit=RESULTS_PER_ITEM):
    """Search eBay for a single item. Returns a list of dicts."""
    headers = {
        "Authorization": f"Bearer {token}",
        "X-EBAY-C-MARKETPLACE-ID": MARKETPLACE,
        "Content-Type": "application/json",
    }
    params = {
        "q": query,
        "limit": limit,
        "sort": "price",  # cheapest first
    }

    resp = requests.get(SEARCH_URL, headers=headers, params=params, timeout=30)
    if not resp.ok:
        print(f"   ⚠️  search failed ({resp.status_code}) for: {query}")
        return []

    data = resp.json()
    results = []
    for item in data.get("itemSummaries", []):
        price = item.get("price", {})
        results.append({
            "title": item.get("title", ""),
            "price": f"{price.get('currency', '')} {price.get('value', '')}".strip(),
            "url": item.get("itemWebUrl", ""),
        })
    return results


def main():
    # Load items
    if not os.path.exists(ITEMS_FILE):
        print(f"❌ {ITEMS_FILE} not found in current folder.")
        sys.exit(1)

    with open(ITEMS_FILE) as f:
        data = json.load(f)
    items = data.get("items", [])
    print(f"📦 Loaded {len(items)} items from {ITEMS_FILE}\n")

    # Auth
    print("🔑 Getting eBay access token...")
    token = get_access_token()
    print("✅ Token acquired\n")

    # Search each item
    for i, name in enumerate(items, 1):
        print(f"{'='*70}")
        print(f"[{i}/{len(items)}] {name}")
        print(f"{'='*70}")

        results = search_item(token, name)

        if not results:
            print("   (no results)")
        else:
            for r in results:
                print(f"   {r['price']:<12} {r['url']}")

        print()
        time.sleep(0.5)  # be gentle with the API

    print("✅ Done.")


if __name__ == "__main__":
    main()