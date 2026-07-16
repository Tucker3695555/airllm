#!/usr/bin/env python3
"""
fixer_watch.py — Nova Scotia + New Brunswick fixer-upper listing watcher.

Polls Kijiji "houses for sale" searches for your keywords, remembers what it has
already seen, and emails you ONLY the new matches. Designed to run on your own
always-on machine (home computer, Raspberry Pi, cheap VPS) on a schedule.

WHY NOT MLS/REALTOR.ca?  Those sites hard-block scrapers. The durable way to
watch them is their own free "saved search" email alerts (see fixer-upper-watch.md).
This script covers the FSBO/private side (Kijiji) where the real bargains hide.

--------------------------------------------------------------------------------
QUICK START
--------------------------------------------------------------------------------
1. Needs Python 3.9+ and the 'requests' package:  pip install requests
2. Edit the CONFIG block below (price ceiling, keywords, email).
3. Test the plumbing (no network, no email):   python3 fixer_watch.py --self-test
4. Try a real run, printing to screen only:     python3 fixer_watch.py --dry-run
5. Enable email by setting these environment variables (Gmail example):
       export FW_SMTP_USER="youraddress@gmail.com"
       export FW_SMTP_PASS="your-16-char-app-password"   # NOT your normal password
       export FW_EMAIL_TO="tuckerbeetuck@gmail.com"
   (Gmail: create an App Password at https://myaccount.google.com/apppasswords)
6. Run it for real:                             python3 fixer_watch.py
7. Schedule it (Linux/Mac cron, every 2 hours):
       0 */2 * * *  cd /path/to/folder && /usr/bin/python3 fixer_watch.py >> fw.log 2>&1

NOTE: Web scraping is inherently brittle — if Kijiji changes its page structure,
the parser may need a tweak. The saved-search email alerts remain your primary net.
"""

import argparse
import json
import os
import re
import smtplib
import sys
import time
from email.mime.text import MIMEText
from html import unescape
from pathlib import Path

# =============================== CONFIG ========================================

# Max price you'd pay for a fixer (set to your expected cash from the India St sale)
PRICE_CEILING = 400_000

# Kijiji's embedded JSON stores prices in CENTS ($189,000 -> 18900000).
# If you ever see prices come out 100x too big or small, flip this.
PRICE_IN_CENTS = True

# Keywords that flag a renovation opportunity (case-insensitive, matches title/desc)
KEYWORDS = [
    "fixer", "handyman", "needs work", "tlc", "as is", "as-is",
    "renovation", "reno", "estate sale", "tear down", "teardown",
    "investment", "handy", "project", "gut",
]

# Kijiji "houses for sale" search result pages to poll.
# These are the province-level category URLs. Adjust/add city-level ones if you like.
#   Nova Scotia houses for sale:  c35l9003
#   New Brunswick houses for sale: c35l9004
SEARCH_URLS = [
    "https://www.kijiji.ca/b-house-for-sale/nova-scotia/c35l9003",
    "https://www.kijiji.ca/b-house-for-sale/new-brunswick/c35l9004",
]

# Where to remember what we've already emailed (so you only get NEW listings)
SEEN_FILE = Path(__file__).with_name("seen_listings.json")

# Email settings come from environment variables (see QUICK START). Leave unset to
# run in print-only mode.
SMTP_HOST = os.environ.get("FW_SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("FW_SMTP_PORT", "587"))
SMTP_USER = os.environ.get("FW_SMTP_USER", "")
SMTP_PASS = os.environ.get("FW_SMTP_PASS", "")
EMAIL_TO = os.environ.get("FW_EMAIL_TO", "")

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0 Safari/537.36"
)

# ==============================================================================


def fetch(url):
    """Fetch a URL's HTML. Returns text or raises."""
    import requests

    resp = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=30)
    resp.raise_for_status()
    return resp.text


def _walk(obj):
    """Recursively yield every dict inside a nested JSON structure."""
    if isinstance(obj, dict):
        yield obj
        for v in obj.values():
            yield from _walk(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from _walk(v)


def extract_listings(html):
    """
    Pull listings out of a Kijiji search page.

    Strategy 1 (preferred): parse the __NEXT_DATA__ / embedded JSON blob and walk
    it for objects that look like listings (have a title, a price, and a URL).
    Strategy 2 (fallback): regex the raw HTML for listing anchor tags.

    Returns a list of dicts: {id, title, price, url, location, description}.
    """
    listings = {}

    # ---- Strategy 1: embedded JSON ----
    for m in re.finditer(
        r'<script[^>]*>\s*(?:window\.__data\s*=|)\s*(\{.*?\})\s*</script>',
        html, re.DOTALL,
    ):
        _try_json_blob(m.group(1), listings)
    for m in re.finditer(
        r'<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.DOTALL
    ):
        _try_json_blob(m.group(1), listings)

    # ---- Strategy 2: HTML anchors (fallback) ----
    if not listings:
        for m in re.finditer(r'href="(/v-[^"]+/(\d+))"[^>]*>(.*?)</a>', html, re.DOTALL):
            path, lid, inner = m.groups()
            title = unescape(re.sub(r"<[^>]+>", "", inner)).strip()
            if not title:
                continue
            listings[lid] = {
                "id": lid,
                "title": title,
                "price": None,
                "url": "https://www.kijiji.ca" + path,
                "location": "",
                "description": "",
            }

    return list(listings.values())


def _try_json_blob(text, listings):
    """Best-effort: parse a JSON string and harvest listing-shaped dicts."""
    try:
        data = json.loads(text)
    except (json.JSONDecodeError, ValueError):
        return
    for d in _walk(data):
        # Heuristic: a listing has an id + a title-ish + a price-ish + a url-ish field
        lid = d.get("id") or d.get("listingId") or d.get("adId")
        title = d.get("title") or d.get("name")
        url = d.get("url") or d.get("seoUrl") or d.get("href")
        if not (lid and title and isinstance(title, str)):
            continue
        price = _extract_price(d)
        if url and url.startswith("/"):
            url = "https://www.kijiji.ca" + url
        listings[str(lid)] = {
            "id": str(lid),
            "title": title.strip(),
            "price": price,
            "url": url or "",
            "location": str(d.get("location") or d.get("address") or ""),
            "description": str(d.get("description") or "")[:400],
        }


def _extract_price(d):
    """Pull a numeric dollar price out of a listing dict, if present."""
    p = d.get("price")
    if isinstance(p, dict):
        p = p.get("amount") or p.get("value")
    if isinstance(p, bool):  # guard: bool is a subclass of int
        return None
    if isinstance(p, (int, float)):
        # Kijiji's numeric prices are in cents; convert to whole dollars.
        return int(p / 100) if PRICE_IN_CENTS else int(p)
    if isinstance(p, str):
        # String prices (HTML fallback) are already dollars, e.g. "$189,000".
        digits = re.sub(r"[^\d]", "", p)
        return int(digits) if digits else None
    return None


def matches(listing):
    """True if a listing looks like a fixer-upper within budget."""
    price = listing.get("price")
    if price is not None and price > PRICE_CEILING:
        return False
    haystack = (listing.get("title", "") + " " + listing.get("description", "")).lower()
    return any(kw in haystack for kw in KEYWORDS)


def load_seen():
    if SEEN_FILE.exists():
        try:
            return set(json.loads(SEEN_FILE.read_text()))
        except (json.JSONDecodeError, ValueError):
            return set()
    return set()


def save_seen(seen):
    SEEN_FILE.write_text(json.dumps(sorted(seen)))


def format_report(new_listings):
    lines = [f"{len(new_listings)} new fixer-upper listing(s) found:\n"]
    for l in new_listings:
        price = f"${l['price']:,}" if l.get("price") else "price N/A"
        lines.append(f"• {l['title']}  —  {price}")
        if l.get("location"):
            lines.append(f"  {l['location']}")
        lines.append(f"  {l['url']}\n")
    return "\n".join(lines)


def send_email(subject, body):
    if not (SMTP_USER and SMTP_PASS and EMAIL_TO):
        print("[email disabled — set FW_SMTP_USER / FW_SMTP_PASS / FW_EMAIL_TO]")
        print(body)
        return
    msg = MIMEText(body)
    msg["Subject"] = subject
    msg["From"] = SMTP_USER
    msg["To"] = EMAIL_TO
    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as s:
        s.starttls()
        s.login(SMTP_USER, SMTP_PASS)
        s.sendmail(SMTP_USER, [EMAIL_TO], msg.as_string())
    print(f"[emailed {EMAIL_TO}]")


def run(dry_run=False):
    seen = load_seen()
    found = {}
    for url in SEARCH_URLS:
        try:
            html = fetch(url)
        except Exception as e:  # network/proxy/anti-bot — keep going
            print(f"[warn] could not fetch {url}: {e}", file=sys.stderr)
            continue
        for l in extract_listings(html):
            if matches(l):
                found[l["id"]] = l
        time.sleep(2)  # be polite between requests

    new = [l for lid, l in found.items() if lid not in seen]
    if not new:
        print(f"No new matches. (checked {len(found)} matching listings)")
        return

    report = format_report(new)
    if dry_run:
        print("[dry-run — not emailing, not saving seen state]\n")
        print(report)
        return

    send_email(f"{len(new)} new NS/NB fixer-upper listing(s)", report)
    seen.update(l["id"] for l in new)
    save_seen(seen)


def self_test():
    """Verify parsing / matching / dedup / report logic with no network."""
    sample_html = """
    <html><body>
    <script id="__NEXT_DATA__" type="application/json">
    {"props":{"listings":[
       {"id":101,"title":"Handyman special - needs work","price":{"amount":18900000},
        "url":"/v-house/101","location":"Dartmouth, NS",
        "description":"Great bones, cosmetic reno needed."},
       {"id":102,"title":"Beautiful move-in ready home","price":{"amount":62500000},
        "url":"/v-house/102","location":"Halifax, NS","description":"Turnkey."},
       {"id":103,"title":"Estate sale fixer upper","price":{"amount":29900000},
        "url":"/v-house/103","location":"Moncton, NB","description":"Sold as-is."}
    ]}}
    </script></body></html>
    """
    listings = extract_listings(sample_html)
    assert len(listings) == 3, f"expected 3 parsed, got {len(listings)}"
    by_id = {l["id"]: l for l in listings}
    assert by_id["101"]["price"] == 189000, by_id["101"]["price"]
    matched = [l for l in listings if matches(l)]
    matched_ids = sorted(l["id"] for l in matched)
    assert matched_ids == ["101", "103"], matched_ids  # 102 is not a fixer / over budget
    report = format_report(matched)
    assert "Handyman special" in report and "Estate sale fixer" in report
    assert "Beautiful move-in" not in report
    # dedup check
    global SEEN_FILE
    import tempfile
    SEEN_FILE = Path(tempfile.gettempdir()) / "fw_selftest_seen.json"
    if SEEN_FILE.exists():
        SEEN_FILE.unlink()
    save_seen({"101"})
    seen = load_seen()
    fresh = [l for l in matched if l["id"] not in seen]
    assert [l["id"] for l in fresh] == ["103"], "dedup failed"
    SEEN_FILE.unlink(missing_ok=True)
    print("SELF-TEST PASSED ✔  (parse, price, keyword match, budget filter, dedup all OK)")


def main():
    ap = argparse.ArgumentParser(description="NS/NB fixer-upper listing watcher")
    ap.add_argument("--dry-run", action="store_true",
                    help="fetch and print matches, but don't email or save state")
    ap.add_argument("--self-test", action="store_true",
                    help="run offline logic tests (no network)")
    args = ap.parse_args()
    if args.self_test:
        self_test()
    else:
        run(dry_run=args.dry_run)


if __name__ == "__main__":
    main()
