"""Entry point: python -m market_scraper.run [--sources cbsl,cse,banks,tbills] [--dry-run]."""
from __future__ import annotations

import argparse
import json
import sys
from functools import lru_cache

from . import http
from .model import Price
from .sources import banks, cbsl, cse, tbills

ALL = ["cbsl", "cse", "banks", "tbills"]


def scrape(sources: list[str], backfill_days: int = 7) -> tuple[list[Price], dict[str, str]]:
    """Runs each source on its own; a failure is reported, never fatal."""

    @lru_cache(maxsize=None)
    def page(url: str) -> str:  # BOC's page serves both FD and T-bill rates
        return http.get(url).text

    prices: list[Price] = []
    report: dict[str, str] = {}
    for name in sources:
        try:
            if name == "cbsl":
                got = cbsl.collect(backfill_days)
            elif name == "cse":
                got = cse.collect()
            elif name == "banks":
                got, errors = banks.collect(page)
                for e in errors:
                    print(f"  warning: {e}", file=sys.stderr)
            elif name == "tbills":
                got = tbills.collect(page)
            else:
                raise ValueError(f"unknown source {name}")
            prices += got
            report[name] = f"ok ({len(got)} prices)"
        except Exception as e:
            report[name] = f"failed: {e}"
    return prices, report


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--sources", default=",".join(ALL), help="comma-separated: " + ",".join(ALL))
    ap.add_argument("--backfill-days", type=int, default=7, help="days of CBSL history to (re)write")
    ap.add_argument("--dry-run", action="store_true", help="print rows instead of writing to Supabase")
    args = ap.parse_args(argv)

    sources = [s.strip() for s in args.sources.split(",") if s.strip()]
    prices, report = scrape(sources, args.backfill_days)
    for name, status in report.items():
        print(f"{name}: {status}")

    if args.dry_run:
        print(json.dumps([p.row() for p in prices], indent=2))
    elif prices:
        from .writer import SupabaseWriter
        SupabaseWriter().write(prices)
        print(f"wrote {len(prices)} prices")
    # Fail the job only when nothing at all could be scraped.
    return 0 if prices else 1


if __name__ == "__main__":
    sys.exit(main())
