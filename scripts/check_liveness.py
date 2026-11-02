#!/usr/bin/env python3
"""
Weekly liveness check for the Narge feed. DNS only: no web requests to listed sites.

For each name in dist/narge.txt, ask DNS-over-HTTPS (Cloudflare JSON API, Google as
fallback) and classify:

  ok        apex (or a common delivery subdomain, for CDN-style names) has an A/AAAA address
  nxdomain  name does not exist
  servfail  resolver error or timeout on both resolvers
  noaddr    zone exists but no address at apex or common subdomains
  parked    nameservers belong to a parking / domain-sale service
  suffix    name is on the Public Suffix List (never allowed, see RULES.md)

State (consecutive failed weeks per name) is carried in a hidden JSON comment inside the
tracking issue body, so the Action never commits to the repo and never removes a name.

Usage:
  python3 scripts/check_liveness.py --prev prev_body.md --out new_body.md [--min-streak 2]
"""

import argparse
import concurrent.futures as cf
import datetime as dt
import json
import re
import time
import urllib.parse
import urllib.request

FEED = "dist/narge.txt"
RESOLVERS = [
    "https://cloudflare-dns.com/dns-query",
    "https://dns.google/resolve",
]
PSL_URL = "https://publicsuffix.org/list/public_suffix_list.dat"
DELIVERY_SUBS = ["www", "cdn", "static", "ei", "di", "assets", "img", "images", "media",
                 "s1", "static-pub", "video", "m"]
PARKING_NS = ["sedoparking", "parklogic", "parkingcrew", "bodis", "above.com", "afternic",
              "dan.com", "hugedomains", "undeveloped", "uniregistry-parking", "dsredirection",
              "parking", "domainparking", "cashparking", "voodoo.com", "smartname"]
PROBES_FILE = "scripts/liveness_probes.txt"
MIN_DAYS_BETWEEN_CHECKS = 5  # a re-run in the same week does not add a week to the streak
STATE_RE = re.compile(r"<!-- narge-liveness-state (\{.*?\}) -->", re.S)


def doh(name, rtype):
    """Return (status, answers) or (None, None) if every resolver failed."""
    for base in RESOLVERS:
        url = f"{base}?name={urllib.parse.quote(name)}&type={rtype}"
        req = urllib.request.Request(url, headers={"accept": "application/dns-json",
                                                   "user-agent": "narge-liveness-check"})
        for attempt in range(2):
            try:
                with urllib.request.urlopen(req, timeout=10) as r:
                    j = json.load(r)
                status = j.get("Status")
                if status == 2:  # SERVFAIL: try next resolver
                    break
                return status, j.get("Answer", []) or []
            except Exception:
                time.sleep(1 + attempt)
    return None, None


def has_addr(name):
    for rtype, code in (("A", 1), ("AAAA", 28)):
        status, ans = doh(name, rtype)
        if status is None:
            return None, "servfail"
        if status == 3:
            return False, "nxdomain"
        if any(a.get("type") == code for a in ans):
            return True, "ok"
    return False, "noaddr"


def load_probes():
    probes = {}
    try:
        with open(PROBES_FILE) as f:
            for line in f:
                parts = line.split("#", 1)[0].split()
                if len(parts) >= 2:
                    probes[parts[0].lower()] = parts[1:]
    except FileNotFoundError:
        pass
    return probes


PROBES = load_probes()


def check(name, psl):
    if name in psl:
        return "suffix", ""
    ok, why = has_addr(name)
    if ok is None or why == "nxdomain":
        return why, ""
    _, ns = doh(name, "NS")
    ns_txt = " ".join(a.get("data", "") for a in (ns or []) if a.get("type") == 2).lower()
    if any(p in ns_txt for p in PARKING_NS):
        return "parked", ns_txt.strip()
    if ok:
        return "ok", ""
    for sub in PROBES.get(name, []) + DELIVERY_SUBS:
        sok, _ = has_addr(f"{sub}.{name}")
        if sok:
            return "ok", f"via {sub}."
    return "noaddr", ""


def load_psl():
    try:
        with urllib.request.urlopen(PSL_URL, timeout=20) as r:
            text = r.read().decode("utf-8", "replace")
    except Exception:
        return set()
    out = set()
    for line in text.splitlines():
        line = line.strip()
        if line and not line.startswith("//"):
            out.add(line.lstrip("*.!").lower())
    return out


def load_feed():
    names = []
    with open(FEED) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                names.append(line.lower())
    return names


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prev", help="previous issue body (may be missing/empty)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--min-streak", type=int, default=2)
    args = ap.parse_args()

    prev, prev_date = {}, None
    if args.prev:
        try:
            m = STATE_RE.search(open(args.prev).read())
            if m:
                st = json.loads(m.group(1))
                prev, prev_date = st.get("names", {}), st.get("date")
        except FileNotFoundError:
            pass

    today = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")
    names = load_feed()
    psl = load_psl()
    with cf.ThreadPoolExecutor(12) as ex:
        results = dict(zip(names, ex.map(lambda n: check(n, psl), names)))

    new_week = True
    if prev_date:
        gap = (dt.date.fromisoformat(today) - dt.date.fromisoformat(prev_date)).days
        new_week = gap >= MIN_DAYS_BETWEEN_CHECKS
    state = {}
    for name, (status, note) in results.items():
        if status == "ok":
            continue
        p = prev.get(name, {})
        state[name] = {
            "streak": p.get("streak", 0) + (1 if new_week or not p else 0),
            "since": p.get("since", today),
            "status": status,
            "note": note[:120],
        }

    failing = sorted((n for n, s in state.items() if s["streak"] >= args.min_streak),
                     key=lambda n: (-state[n]["streak"], n))
    watch = sorted(n for n, s in state.items() if s["streak"] < args.min_streak)

    lines = [
        f"Weekly DNS liveness check of `dist/narge.txt`. Last run: **{today}** (UTC).",
        "",
        f"Checked {len(names)} names. OK: {len(names) - len(state)}. "
        f"Failing {args.min_streak}+ consecutive weeks: **{len(failing)}**. "
        f"Failing this week only: {len(watch)}.",
        "",
        "Nothing is removed automatically. Per RULES.md section 6, a maintainer removes a name "
        "only after 2+ failed checks over 2+ weeks (3 for servfail), with a CHANGELOG line. "
        "DNS only: no listed site is visited.",
        "",
        f"## Failing {args.min_streak}+ consecutive weeks ({len(failing)})",
        "",
    ]
    if failing:
        lines += ["| Name | Weeks | Since | Status | Note |", "|---|---|---|---|---|"]
        for n in failing:
            s = state[n]
            lines.append(f"| `{n}` | {s['streak']} | {s['since']} | {s['status']} | {s['note']} |")
    else:
        lines.append("None.")
    lines += ["", f"## Failed this week only, watching ({len(watch)})", ""]
    lines.append(", ".join(f"`{n}` ({state[n]['status']})" for n in watch) or "None.")
    lines += ["", "Status key: nxdomain = does not exist; servfail = resolver error; "
              "noaddr = no address at apex or common subdomains; parked = parking/for-sale "
              "nameservers; suffix = on the Public Suffix List.", ""]
    state_date = today if new_week else prev_date
    lines.append("<!-- narge-liveness-state " + json.dumps({"date": state_date, "names": state},
                                                         sort_keys=True) + " -->")
    with open(args.out, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"checked={len(names)} failing={len(failing)} watch={len(watch)}")
    with open(args.out + ".count", "w") as f:
        f.write(str(len(failing)))


if __name__ == "__main__":
    main()
