#!/usr/bin/env python3
"""Check a JLCPCB BOM against JLC's current stock.

Usage: python3 stock_check.py bom_jlcpcb.csv [--boards 10] [--show 6]

Reads the BOM (columns "Designator" and "LCSC Part #", as jlc_bom_cpl.py writes it), looks up every
LCSC number and reports a problem when a part can't be found, when the orderable quantity
(canPresaleNumber) is below the need for --boards boards, or when the minimum purchase is above 1.
stockCount is not used: it includes parts already reserved by other orders. Lines without an LCSC
number (Global Sourcing or consigned parts) are skipped. Also lists the --show parts with the least
margin. Exit code 1 when there are problems.
"""
import argparse
import csv
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import jlc_search  # noqa: E402


def main():
    ap = argparse.ArgumentParser(description="Check a JLCPCB BOM against JLC's orderable stock.")
    ap.add_argument("bom")
    ap.add_argument("--boards", type=int, default=10, help="number of boards to cover (default 10)")
    ap.add_argument("--show", type=int, default=6, help="list this many parts with the least margin (default 6)")
    a = ap.parse_args()

    need, names = {}, {}
    with open(a.bom, newline="") as f:
        for r in csv.DictReader(f):
            c = (r.get("LCSC Part #") or "").strip()
            if c:
                need[c] = need.get(c, 0) + len([d for d in r["Designator"].split(",") if d.strip()])
                names[c] = r.get("Comment", "")

    bad, rows = [], []
    for c, n in need.items():
        _, hits = jlc_search.search(c, 5)
        h = next((x for x in hits if x.get("componentCode") == c), None)
        want = a.boards * n
        if not h:
            bad.append(f"{c} {names[c]}: not found")
            continue
        free, mp = h.get("canPresaleNumber") or 0, h.get("minPurchaseNum") or 1
        rows.append((free / want, c, names[c], n, free, mp))
        if free < want or mp > 1:
            bad.append(f"{c} {names[c]}: free {free}, need {want} for {a.boards} boards, min purchase {mp}")
        time.sleep(0.3)

    print(f"{len(rows)} parts checked; the {a.show} with the least margin (free stock / need for {a.boards} boards):")
    for m, c, name, n, free, mp in sorted(rows)[:a.show]:
        print(f"  {c:9} {name[:22]:22} x{n}/board  free {free:>9}  margin {m:,.1f}x  min buy {mp}")
    print("problems:", "none" if not bad else "")
    for b in bad:
        print("  " + b)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
