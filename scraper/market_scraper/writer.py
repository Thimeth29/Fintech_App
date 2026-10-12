"""Writes prices to Supabase through PostgREST with the service-role key.

Only rows that were scraped successfully are written, so a source that fails
today leaves yesterday's row (and its as_of time) in place: the table is the
cache, and the app shows how old each price is.
"""
from __future__ import annotations

import os

import requests

from .model import Price


class SupabaseWriter:
    def __init__(self, url: str | None = None, key: str | None = None, session=None):
        self.url = (url or os.environ["SUPABASE_URL"]).rstrip("/")
        self.key = key or os.environ["SUPABASE_SERVICE_ROLE_KEY"]
        self.http = session or requests.Session()

    def _upsert(self, table: str, rows: list[dict], conflict: str) -> None:
        if not rows:
            return
        res = self.http.post(
            f"{self.url}/rest/v1/{table}?on_conflict={conflict}",
            json=rows,
            headers={
                "apikey": self.key,
                "authorization": f"Bearer {self.key}",
                "content-type": "application/json",
                "prefer": "resolution=merge-duplicates,return=minimal",
            },
            timeout=30,
        )
        if res.status_code >= 300:
            raise RuntimeError(f"{table}: HTTP {res.status_code} {res.text[:300]}")

    def write(self, prices: list[Price]) -> None:
        self._upsert("market_prices", [p.row() for p in prices], "symbol")
        self._upsert("market_price_history", history_rows(prices), "symbol,price_date")


def history_rows(prices: list[Price]) -> list[dict]:
    """One row per symbol per day: the backfilled series, plus today's value."""
    rows: dict[tuple[str, str], dict] = {}
    for p in prices:
        series = dict(p.history)
        series.setdefault(p.as_of.date().isoformat(), p.price)
        for d, v in series.items():
            if v and v > 0:
                rows[(p.symbol, d)] = {"symbol": p.symbol, "price_date": d, "price": round(v, 6), "source": p.source}
    return list(rows.values())
