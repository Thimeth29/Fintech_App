"""LKR fixed-deposit rates from banks' "rates & tariffs" pages.

Same approach as the collect-rates edge function (fd_parser.ts): every
<table> is parsed, rows that name a tenure ("6 Months", "1 Year - at
maturity") give a rate, and the table with the most standard tenures wins.
"""
from __future__ import annotations

import re
from datetime import datetime, timezone

from .. import config, http
from ..model import Price
from .html_tables import extract_tables

TRACKED = [1, 3, 6, 12, 24, 60]
EXCLUDE_ROW = re.compile(r"\b(usd|gbp|eur|euro|aud|cad|jpy|sgd|chf|nzd|sek|hkd|cny|inr|fcy|foreign|senior|minor|"
                         r"children|child|staff|special|nrfc|rfc|pensioner|women|sevana|udara|ladies)\b", re.I)
NON_MATURITY = re.compile(r"\b(monthly|annually|quarterly|semi[- ]?annual|half[- ]?yearly|upfront|in advance)\b", re.I)
MATURITY = re.compile(r"maturity", re.I)
EXCLUDE_TABLE = re.compile(r"\b(usd|gbp|eur|aud|foreign currency|fcy|loan|lending|pawning|leasing|treasury)\b", re.I)
EXCLUDE_CONTEXT = re.compile(r"\b(senior|minor|loans?|advances|lending|pawning|leasing|certificate of deposits?|"
                             r"foreign currency|fcy|usd|co-operative|samurdhi|treasury)\b", re.I)


def tenure_months(label: str) -> int | None:
    m = re.search(r"(\d{1,3})\s*(months?|mths?|mnths?|years?|yrs?)\b", label, re.I)
    if m:
        n = int(m.group(1))
        return n * 12 if m.group(2).lower().startswith("y") else n
    d = re.search(r"(\d{2,4})\s*days?\b", label, re.I)
    if d:
        days = int(d.group(1))
        months = round(days / 30.4)
        if months in TRACKED and abs(days - months * 30.4) < 8:
            return months
    return None


def _is_tenure_header(cell: str) -> bool:
    return re.fullmatch(r"\s*\d{1,3}\s*(months?|mths?|years?|yrs?)\s*", cell, re.I) is not None


def cell_rate(cell: str) -> float | None:
    if tenure_months(cell) is not None:
        return None
    m = re.match(r"^\s*(\d{1,2}(?:\.\d{1,3})?)(?![\d,])\s*%?", cell)
    if not m:
        return None
    v = float(m.group(1))
    return v if 0.5 <= v <= 30 else None


def first_rate(cells: list[str]) -> float | None:
    for c in cells:
        v = cell_rate(c)
        if v is not None:
            return v
    return None


def _parse_transposed(rows: list[list[str]]) -> list[tuple[int, float, bool]]:
    header_idx = next((i for i, r in enumerate(rows) if sum(map(_is_tenure_header, r)) >= 3), -1)
    if header_idx < 0:
        return []
    header = rows[header_idx]
    out, currency = [], "LKR"
    for cells in rows[header_idx + 1:]:
        code = next((c for c in cells if re.fullmatch(r"[A-Z]{3}", c.strip())), None)
        if code:
            currency = code.strip()
        if currency != "LKR":
            continue
        label = next((c for c in cells if c != code and re.search(r"[a-z]{3}", c, re.I) and first_rate([c]) is None), "")
        if EXCLUDE_ROW.search(label):
            continue
        maturity = bool(MATURITY.search(label)) or not NON_MATURITY.search(label)
        shift = len(header) - len(cells)
        for j, h in enumerate(header):
            months, k = tenure_months(h), j - shift
            if months is None or k < 0 or k >= len(cells):
                continue
            rate = first_rate([cells[k]])
            if rate is not None and re.search(r"\d", cells[k]):
                out.append((months, rate, maturity))
    return out


def _parse_table(rows: list[list[str]]) -> dict[int, float]:
    cands: list[tuple[int, float, bool]] = []
    header: list[str] | None = None
    maturity_col = -1
    for cells in rows:
        if len(cells) < 2 or sum(map(_is_tenure_header, cells)) >= 3:
            continue
        label_idx = next((i for i, c in enumerate(cells) if tenure_months(c) is not None), -1)
        if label_idx < 0:
            if all(cell_rate(c) is None for c in cells):
                header = cells
                maturity_col = next((i for i, c in enumerate(cells) if MATURITY.search(c)), -1)
            continue
        label = cells[label_idx]
        if EXCLUDE_ROW.search(label):
            continue
        months = tenure_months(label)
        maturity = bool(MATURITY.search(label)) or not NON_MATURITY.search(label)
        if header and maturity_col > 0:
            col = maturity_col - (len(header) - len(cells))
            rate = cell_rate(cells[col]) if label_idx < col < len(cells) else None
            maturity = True
        else:
            rate = first_rate(cells[label_idx + 1:])
        if rate is not None and months is not None:
            cands.append((months, rate, maturity))
    cands += _parse_transposed(rows)
    result: dict[int, float] = {}
    for months, rate, maturity in cands:
        if maturity and months not in result:
            result[months] = rate
    return result


def parse_fd_rates(html: str, table_hint: str | None = None) -> dict[int, float] | None:
    hint = re.compile(table_hint, re.I | re.M) if table_hint else None
    best, best_score = None, 0
    for t in extract_tables(html):
        head = " ".join(c for r in t.rows[:2] for c in r)
        if EXCLUDE_TABLE.search(head):
            continue
        if hint is not None:
            if not hint.search(t.context):
                continue
        elif EXCLUDE_CONTEXT.search(t.context[-100:]):
            continue
        parsed = _parse_table(t.rows)
        tenures = len([m for m in parsed if m in TRACKED])
        if tenures < 2:
            continue
        score = tenures + (2 if re.search(r"fixed deposit", t.context, re.I) else 0)
        if score > best_score:
            best, best_score = parsed, score
    return best


def to_prices(bank: str, url: str, rates: dict[int, float], now: datetime) -> list[Price]:
    return [Price(symbol=f"FD|{bank}|{m}", kind="fd_rate", name=f"{bank} {m}-month FD", price=rates[m],
                  unit="% p.a.", source=bank, as_of=now, source_url=url)
            for m in config.FD_TENURES if rates.get(m)]


def collect(page=None) -> tuple[list[Price], list[str]]:
    """(prices, errors). [page] fetches a URL's HTML (shared with T-bills)."""
    page = page or (lambda u: http.get(u).text)
    now = datetime.now(timezone.utc)
    prices, errors = [], []
    for b in config.BANKS:
        try:
            rates = parse_fd_rates(page(b["url"]), b.get("table_hint"))
            if not rates:
                errors.append(f"{b['name']}: rate table not found (page layout changed?)")
                continue
            prices += to_prices(b["name"], b["url"], rates, now)
        except Exception as e:  # one bank failing must not stop the others
            errors.append(f"{b['name']}: {e}")
    return prices, errors
