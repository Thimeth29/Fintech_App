"""Treasury bill yields from Bank of Ceylon's weekly table (port of tbill_parser.ts).

CBSL publishes auction results only as PDFs; BOC's "TREASURY BILL RATES
APPLICABLE FOR THE WEEK COMMENCING FROM dd.mm.yyyy" table is what a retail
investor can buy at that week.
"""
from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone

from .. import config, http
from ..model import Price
from .html_tables import extract_tables


def parse(html: str) -> tuple[str | None, dict[int, float]] | None:
    for t in extract_tables(html):
        text = t.context + " " + " ".join(c for r in t.rows for c in r)
        if not re.search(r"treasury bill rates", text, re.I):
            continue
        yields: dict[int, float] = {}
        for cells in t.rows:
            days = re.search(r"\((\d{2,3})\s*days\)", " ".join(cells), re.I)
            pct = next((m for m in (re.match(r"^\s*(\d{1,2}\.\d{1,3})\s*%", c) for c in cells) if m), None)
            if days and pct:
                yields[int(days.group(1))] = float(pct.group(1))
        if not yields:
            continue
        d = re.search(r"commencing from\s*(\d{2})\.(\d{2})\.(\d{4})", text, re.I)
        return (f"{d.group(3)}-{d.group(2)}-{d.group(1)}" if d else None), yields
    return None


def collect(page=None) -> list[Price]:
    page = page or (lambda u: http.get(u).text)
    parsed = parse(page(config.BOC_RATES_URL))
    if not parsed:
        raise RuntimeError("T-bill table not found on the BOC page")
    week, yields = parsed
    tz = timezone(timedelta(hours=config.COLOMBO_OFFSET_HOURS))
    as_of = datetime.fromisoformat(week).replace(hour=9, tzinfo=tz) if week else datetime.now(timezone.utc)
    return [Price(symbol=f"TBILL_{d}", kind="tbill_yield", name=f"{d}-day T-Bill", price=y, unit="% p.a.",
                  source="Bank of Ceylon", as_of=as_of, source_url=config.BOC_RATES_URL)
            for d, y in sorted(yields.items())]
