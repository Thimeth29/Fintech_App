"""Colombo Stock Exchange prices from cse.lk's public JSON API (tradeSummary)."""
from __future__ import annotations

from datetime import datetime, timezone

from .. import config, http
from ..model import Price

ENDPOINT = "https://www.cse.lk/api/tradeSummary"
SOURCE_URL = "https://www.cse.lk"


def _num(v) -> float | None:
    try:
        return None if v in (None, "") else float(v)
    except (TypeError, ValueError):
        return None


def app_symbol(cse_symbol: str) -> str:
    """'JKH.N0000' -> 'JKH.N' (the app drops the share-class digits)."""
    return cse_symbol.split("0000")[0] if cse_symbol.endswith("0000") else cse_symbol


def to_prices(payload: dict, now: datetime | None = None) -> list[Price]:
    now = now or datetime.now(timezone.utc)
    out: list[Price] = []
    for t in payload.get("reqTradeSummery") or []:
        sym = app_symbol(str(t.get("symbol", "")))
        if sym not in config.CSE_SYMBOLS:
            continue
        price = _num(t.get("price")) or _num(t.get("lastTradedPrice"))
        if not price or price <= 0:
            continue
        traded = _num(t.get("lastTradedTime"))
        as_of = datetime.fromtimestamp(traded / 1000, timezone.utc) if traded and traded > 1e12 else now
        out.append(Price(symbol=sym, kind="stock", name=config.CSE_SYMBOLS[sym], price=price,
                         unit="LKR per share", source="CSE", as_of=as_of, source_url=SOURCE_URL,
                         change_pct=_num(t.get("percentageChange"))))
    return out


def collect() -> list[Price]:
    payload = http.post(ENDPOINT, headers={"accept": "application/json"}).json()
    return to_prices(payload)
