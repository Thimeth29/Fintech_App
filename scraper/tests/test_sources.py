import json
from datetime import datetime, timezone

import pytest

from conftest import FIXTURES
from market_scraper import config
from market_scraper.model import Price
from market_scraper.sources import banks, cbsl, cse, tbills
from market_scraper.writer import SupabaseWriter, history_rows


def read(name):
    return (FIXTURES / name).read_text()


# ---- CBSL (fixture is a real exrates_results.php response, May 2025) ----
def test_cbsl_parses_every_currency_table():
    rates = cbsl.parse(read("cbsl_exrates_results.html"))
    assert set(rates) == {"USD", "EUR", "GBP", "AUD", "INR", "JPY", "XAU"}
    assert rates["USD"]["2025-05-19"] == pytest.approx(298.8165)
    assert len(rates["USD"]) == 3


def test_cbsl_prices_use_app_symbols_and_gold_per_gram():
    prices = {p.symbol: p for p in cbsl.to_prices(cbsl.parse(read("cbsl_exrates_results.html")))}
    usd = prices["USDLKR"]
    assert usd.kind == "forex" and usd.price == pytest.approx(298.8165)
    assert usd.change_pct == pytest.approx((298.8165 / 298.5101 - 1) * 100)
    assert usd.as_of.isoformat().startswith("2025-05-19T09:30:00+05:30")
    gold = prices[config.GOLD_SYMBOL]
    assert gold.kind == "gold"
    assert gold.price == pytest.approx(963884.9136 / 31.1034768)
    assert len(gold.history) == 3


def test_cbsl_ignores_unrelated_tables():
    assert cbsl.parse("<table><tr><td>2025-01-01</td><td>1</td></tr></table>") == {}


# ---- CSE ----
def test_cse_keeps_tracked_voting_shares_with_a_price():
    prices = cse.to_prices(json.loads(read("cse_trade_summary.json")), now=datetime(2026, 10, 12, tzinfo=timezone.utc))
    by = {p.symbol: p for p in prices}
    assert set(by) == {"JKH.N", "COMB.N"}  # non-voting, untracked and zero-price rows dropped
    assert by["JKH.N"].price == 21.4 and by["JKH.N"].change_pct == 1.42
    assert by["JKH.N"].as_of.year >= 2026  # from lastTradedTime
    assert by["COMB.N"].as_of == datetime(2026, 10, 12, tzinfo=timezone.utc)


def test_cse_symbol_mapping():
    assert cse.app_symbol("JKH.N0000") == "JKH.N"
    assert cse.app_symbol("COMB.X0000") == "COMB.X"


# ---- Bank FD pages ----
def test_fd_reads_the_maturity_column_of_the_lkr_table():
    rates = banks.parse_fd_rates(read("bank_fd.html"))
    assert rates == {1: 6.50, 3: 7.25, 6: 7.75, 12: 8.50, 24: 8.75}


def test_fd_transposed_table_lkr_maturity_row_only():
    rates = banks.parse_fd_rates(read("bank_fd_transposed.html"))
    assert rates == {1: 8.0, 3: 9.0, 6: 9.5, 12: 10.0}


def test_fd_prices_use_app_keys():
    now = datetime(2026, 10, 12, tzinfo=timezone.utc)
    prices = banks.to_prices("Commercial Bank", "https://x", {1: 6.5, 12: 8.5, 60: 9.0}, now)
    assert [p.symbol for p in prices] == ["FD|Commercial Bank|1", "FD|Commercial Bank|12"]
    assert all(p.kind == "fd_rate" for p in prices)


def test_one_failing_bank_does_not_stop_the_rest():
    def page(url):
        if "combank" in url:
            raise RuntimeError("timeout")
        return read("bank_fd.html")
    prices, errors = banks.collect(page)
    assert any("Commercial Bank" in e for e in errors)
    assert any(p.symbol.startswith("FD|Bank of Ceylon|") for p in prices)


def test_tenure_labels():
    assert banks.tenure_months("1 Year - interest at maturity") == 12
    assert banks.tenure_months("6 Months") == 6
    assert banks.tenure_months("91 days") == 3
    assert banks.cell_rate("3 Month") is None
    assert banks.cell_rate("Rs. 5,000") is None


# ---- T-bills (BOC) ----
def test_tbills_from_boc_table():
    week, yields = tbills.parse(read("bank_fd.html"))
    assert week == "2026-10-05"
    assert yields == {91: 7.85, 182: 8.05, 364: 8.60}
    prices = tbills.collect(lambda url: read("bank_fd.html"))
    assert [p.symbol for p in prices] == ["TBILL_91", "TBILL_182", "TBILL_364"]


# ---- Model and writer ----
def test_price_rejects_bad_values():
    with pytest.raises(ValueError):
        Price(symbol="X", kind="stock", name="X", price=0, unit="LKR", source="t", as_of=datetime.now())
    with pytest.raises(ValueError):
        Price(symbol="X", kind="crypto", name="X", price=1, unit="LKR", source="t", as_of=datetime.now())


def test_history_rows_include_backfill_and_today():
    p = Price(symbol="USDLKR", kind="forex", name="USD", price=300, unit="LKR", source="CBSL",
              as_of=datetime(2026, 10, 12, 4, tzinfo=timezone.utc), history={"2026-10-09": 299.5})
    rows = sorted(history_rows([p]), key=lambda r: r["price_date"])
    assert [(r["price_date"], r["price"]) for r in rows] == [("2026-10-09", 299.5), ("2026-10-12", 300)]


class FakeSession:
    def __init__(self):
        self.calls = []

    def post(self, url, json, headers, timeout):
        self.calls.append((url, json, headers))
        return type("R", (), {"status_code": 201, "text": ""})()


def test_writer_upserts_prices_then_history_with_service_key():
    s = FakeSession()
    w = SupabaseWriter(url="https://proj.supabase.co/", key="service", session=s)
    p = Price(symbol="TBILL_91", kind="tbill_yield", name="91-day", price=7.85, unit="% p.a.", source="BOC",
              as_of=datetime(2026, 10, 5, tzinfo=timezone.utc))
    w.write([p])
    (u1, rows, h), (u2, hist, _) = s.calls
    assert u1 == "https://proj.supabase.co/rest/v1/market_prices?on_conflict=symbol"
    assert u2.endswith("market_price_history?on_conflict=symbol,price_date")
    assert h["authorization"] == "Bearer service" and "merge-duplicates" in h["prefer"]
    assert rows[0]["symbol"] == "TBILL_91" and hist[0]["price_date"] == "2026-10-05"
