from datetime import datetime, timezone

from market_scraper import run
from market_scraper.model import Price


def test_a_failed_source_is_reported_not_fatal(monkeypatch, capsys):
    ok = Price(symbol="USDLKR", kind="forex", name="USD", price=300, unit="LKR", source="CBSL",
               as_of=datetime(2026, 10, 12, tzinfo=timezone.utc))
    monkeypatch.setattr(run.cbsl, "collect", lambda days: [ok])

    def boom():
        raise RuntimeError("cse.lk unreachable")
    monkeypatch.setattr(run.cse, "collect", boom)
    assert run.main(["--sources", "cbsl,cse", "--dry-run"]) == 0
    out = capsys.readouterr().out
    assert "cbsl: ok (1 prices)" in out and "cse: failed: cse.lk unreachable" in out
    assert '"symbol": "USDLKR"' in out


def test_exit_code_when_nothing_scraped(monkeypatch):
    def boom(*a):
        raise RuntimeError("down")
    monkeypatch.setattr(run.cse, "collect", boom)
    assert run.main(["--sources", "cse", "--dry-run"]) == 1
