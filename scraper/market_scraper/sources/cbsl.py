"""CBSL daily indicative exchange rates (and gold, published as XAU per troy ounce).

The rates page posts a form to exrates_results.php, which returns one HTML
table per currency with a "1 USD -> LKR" header and Date / rate rows. The same
endpoint backs CBSL's own exchange-rate lookup and accepts a date range, which
is how history is backfilled.
"""
from __future__ import annotations

import html as htmllib
import re
from datetime import date, datetime, timedelta, timezone

from .. import config, http
from ..model import Price

ENDPOINT = "https://www.cbsl.gov.lk/cbsl_custom/exrates/exrates_results.php"
SOURCE_URL = "https://www.cbsl.gov.lk/en/rates-and-indicators/exchange-rates"
_TZ = timezone(timedelta(hours=config.COLOMBO_OFFSET_HOURS))


def parse(html: str) -> dict[str, dict[str, float]]:
    """{code: {iso_date: LKR per unit}} from the results page."""
    out: dict[str, dict[str, float]] = {}
    for table in re.findall(r"<table.*?</table>", html, re.S | re.I):
        head = re.search(r"1\s+([A-Z]{3})\s+(?:-&gt;|->)\s*LKR", table)
        if not head:
            continue
        code = head.group(1)
        for d, v in re.findall(r"<td>\s*(\d{4}-\d{2}-\d{2})\s*</td>\s*<td>\s*([\d.,]+)\s*</td>", table):
            try:
                rate = float(htmllib.unescape(v).replace(",", ""))
            except ValueError:
                continue
            if rate > 0:
                out.setdefault(code, {})[d] = rate
    return out


def fetch_html(days: int, today: date | None = None) -> str:
    end = today or datetime.now(_TZ).date()
    start = end - timedelta(days=max(days, 7))  # always a week, so a holiday still yields a rate
    form = [("lookupPage", "lookup_daily_exchange_rates.php"), ("rangeType", "dates"),
            ("txtStart", start.isoformat()), ("txtEnd", end.isoformat())]
    form += [("chk_cur[]", f"{c}~{n}") for c, n in config.CBSL_FORM_NAMES.items()]
    form.append(("submit_button", "Submit"))
    return http.post(ENDPOINT, data=form).text


def to_prices(rates: dict[str, dict[str, float]]) -> list[Price]:
    prices: list[Price] = []

    def build(symbol: str, kind: str, name: str, unit: str, series: dict[str, float], scale: float = 1.0):
        if not series:
            return
        dates = sorted(series)
        last, prev = dates[-1], (dates[-2] if len(dates) > 1 else None)
        value = series[last] * scale
        change = None if prev is None else (series[last] / series[prev] - 1) * 100
        # Indicative rates are set at the start of business, 09:30 Colombo.
        as_of = datetime.fromisoformat(last).replace(hour=9, minute=30, tzinfo=_TZ)
        prices.append(Price(symbol=symbol, kind=kind, name=name, price=value, unit=unit, source="CBSL",
                            as_of=as_of, source_url=SOURCE_URL, change_pct=change,
                            history={d: v * scale for d, v in series.items()}))

    for code, (symbol, name) in config.CBSL_CURRENCIES.items():
        build(symbol, "forex", name, f"LKR per {code}", rates.get(code, {}))
    build(config.GOLD_SYMBOL, "gold", "24K gold, per gram", "LKR per gram",
          rates.get("XAU", {}), scale=1 / config.TROY_OUNCE_GRAMS)
    return prices


def collect(backfill_days: int = 7) -> list[Price]:
    return to_prices(parse(fetch_html(backfill_days)))
