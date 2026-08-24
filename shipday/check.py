#!/usr/bin/env python3
"""
Ship Day acceptance check.

Usage:
    python3 shipday/check.py https://your-site.netlify.app

Verifies the same things the grader checks:
  1. Your Codespaces secrets are present.
  2. Your live page loads and shows real results with working source links.
  3. Your page is generated from stored data, not typed by hand.

Exit code 0 means you are ready to submit.
"""

import html
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

REQUIRED_SECRETS = ["TAVILY_API_KEY", "NETLIFY_AUTH_TOKEN", "NETLIFY_SITE_ID"]
TIMEOUT = 20
MIN_LINKS = 3

# If any of these load from the deployed site, the student published their
# working files instead of just the finished page.
LEAKY_PATHS = [
    "finds.json",
    "results.json",
    "data.json",
    "finds.db",
    "results.db",
    "data.db",
    ".env",
]

# Files that suggest a real generator step rather than hand-written HTML.
GENERATOR_HINTS = ("generate", "build", "render", "make_site", "make_page")
STORE_HINTS = (".json", ".db", ".sqlite", ".sqlite3", ".csv")

GREEN, RED, YELLOW, DIM, RESET = "\033[32m", "\033[31m", "\033[33m", "\033[2m", "\033[0m"


def ok(msg):
    print(f"{GREEN}  PASS{RESET}  {msg}")


def fail(msg, hint=None):
    print(f"{RED}  FAIL{RESET}  {msg}")
    if hint:
        print(f"{DIM}        {hint}{RESET}")


def warn(msg):
    print(f"{YELLOW}  WARN{RESET}  {msg}")


def fetch(url):
    """Return (status, body_text). Never raises for HTTP errors."""
    req = urllib.request.Request(url, headers={"User-Agent": "shipday-check/3.0"})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return resp.status, resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", errors="replace")
    except urllib.error.URLError as e:
        return None, str(e.reason)


def check_secrets():
    print("\nChecking your Codespaces secrets")
    all_ok = True
    for name in REQUIRED_SECRETS:
        if os.environ.get(name):
            ok(f"{name} is set")
        else:
            all_ok = False
            fail(
                f"{name} is not set",
                "Add it at https://github.com/settings/codespaces, grant Repository "
                "access to your assignment repo, then restart your Codespace. "
                "For NETLIFY_SITE_ID, see Part 4 of the assignment.",
            )
    return all_ok


def external_links(body, site_host):
    """Return outbound http(s) links that are not to the student's own site."""
    found = []
    for href in re.findall(r'href=["\'](https?://[^"\']+)["\']', body, re.I):
        href = html.unescape(href)
        host = urllib.parse.urlparse(href).netloc.lower()
        if host and host != site_host and "netlify.app" not in host:
            found.append(href)
    return found


def check_page(base):
    print("\nChecking your live page")
    status, body = fetch(base)

    if status is None:
        fail(f"could not reach {base}", f"Network error: {body}")
        return None
    if status == 404:
        fail(
            f"{base} returned 404",
            "You may have deployed a draft instead of production, or index.html "
            "is not at the root of the folder you deployed.",
        )
        return None
    if status != 200:
        fail(f"{base} returned HTTP {status}")
        return None
    ok("page loads")

    site_host = urllib.parse.urlparse(base).netloc.lower()
    links = external_links(body, site_host)

    if len(links) >= MIN_LINKS:
        ok(f"page has {len(links)} outbound source links")
    elif links:
        fail(
            f"page has only {len(links)} outbound source link(s), expected at least {MIN_LINKS}",
            "Each Tavily result should render as a linked title pointing at its source.",
        )
    else:
        fail(
            "page has no outbound source links",
            "Your results should each link to where Tavily found them. If the page "
            "is empty, your generator ran before the researcher saved anything.",
        )

    text = re.sub(r"<[^>]+>", " ", body)
    if len(text.split()) < 20:
        warn("page has very little text -- confirm your results actually rendered")

    return links


def check_not_leaking(base):
    """Confirm working files were not published alongside the page."""
    print("\nChecking that you published only the finished page")
    leaked = []
    for path in LEAKY_PATHS:
        status, _ = fetch(f"{base}/{path}")
        if status == 200:
            leaked.append(path)

    if leaked:
        for path in leaked:
            fail(
                f"{base}/{path} is publicly readable",
                "Only the finished page should be published. Ask your agent to "
                "deploy the built site rather than your whole project folder, "
                "then redeploy.",
            )
        return False

    ok("no data files or scripts exposed at your URL")
    return True


def check_generated(repo_root):
    """Look for evidence of a generator script and a stored dataset."""
    print("\nChecking that your page is generated, not hand-written")

    if not repo_root.exists():
        warn(f"{repo_root} not found -- skipping local file checks")
        return True

    scripts, stores = [], []
    for path in repo_root.rglob("*"):
        if not path.is_file():
            continue
        parts = {p.lower() for p in path.parts}
        if parts & {".git", "node_modules", ".venv", "venv", "__pycache__"}:
            continue
        name = path.name.lower()
        if path.suffix in (".py", ".js", ".mjs", ".ts") and any(
            h in name for h in GENERATOR_HINTS
        ):
            scripts.append(path)
        if name.endswith(STORE_HINTS) and "package" not in name and "lock" not in name:
            stores.append(path)

    if scripts:
        ok(f"found a build script: {scripts[0].name}")
    else:
        warn(
            "no obvious build script found (looked for a .py/.js file named "
            "something like generate/build/render). If yours is named differently "
            "that is fine -- just be sure rerunning it rebuilds the page."
        )

    if stores:
        ok(f"found a stored dataset: {stores[0].name}")
    else:
        warn(
            "no stored dataset found (.json, .db, .sqlite, .csv). If your data lives "
            "somewhere else, be ready to point to it in your delegation log."
        )

    return True


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2

    base = sys.argv[1].rstrip("/")
    if not base.startswith(("http://", "https://")):
        base = "https://" + base

    print(f"Ship Day check -- {base}")

    secrets_ok = check_secrets()
    links = check_page(base)
    clean = check_not_leaking(base) if links is not None else False
    check_generated(Path(__file__).resolve().parent.parent)

    page_ok = bool(links and len(links) >= MIN_LINKS) and clean

    print()
    if secrets_ok and page_ok:
        print(f"{GREEN}All checks passed. You are ready to submit.{RESET}")
        print(
            f"{DIM}Do not forget the 6-line delegation log, including which storage "
            f"your agent chose and why.{RESET}"
        )
        return 0

    print(f"{RED}Not ready yet -- fix the failures above and rerun.{RESET}")
    print(f"{DIM}Stuck? Bring the output of this script to office hours.{RESET}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
