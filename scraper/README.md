# Market data scraper

Fills Supabase `market_prices` (latest value per key) and `market_price_history`
(one value per key per day) for the Investment Trainer's **live prices**. The
Flutter app never scrapes anything: it only reads these tables and subscribes to
`market_prices` with Supabase Realtime, so new prices appear on screen without
polling. Scraping lives here because sites change their HTML often — one fix in
one place instead of one per phone.

```
CBSL exrates  ─┐
CSE API       ─┼─▶ scraper (scheduled) ─▶ Supabase market_prices ─▶ Flutter app (reads only)
Bank websites ─┘
```

| Source | What | Keys written |
|---|---|---|
| CBSL `exrates_results.php` | Daily indicative rates; gold as XAU per troy ounce | `USDLKR`, `EURLKR`, `GBPLKR`, `AUDLKR`, `INRLKR`, `JPYLKR`, `GOLD24K` (LKR/gram) |
| CSE `api/tradeSummary` | Share prices for the trainer's 10 companies | `JKH.N`, `COMB.N`, … |
| Bank rate pages | LKR FD rates paid at maturity | `FD|<bank>|<months>` |
| Bank of Ceylon rates page | Weekly T-bill rates | `TBILL_91`, `TBILL_182`, `TBILL_364` |

Keys match `lib/core/sandbox/sandbox_config.dart`. Anything without a fresh live
price (T-bonds, NSB, fictional trading instruments) falls back to the simulated
price in the app.

## Run

```bash
cd scraper
pip install -r requirements-dev.txt
python -m pytest -q                                   # parsers, against saved pages
python -m market_scraper.run --dry-run                # scrape, print rows
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
  python -m market_scraper.run --backfill-days 180    # first run: 6 months of CBSL history
```

Each source runs on its own: if one fails (site down, HTML changed) the others
are still written, and the failed source's old rows stay in the table with their
original `as_of`, so the app can show how old a price is and switch to simulated
once it's stale (5 days for market prices, 30 for rates). The job exits non-zero
only when nothing could be scraped.

## Schedule

`.github/workflows/market-scraper.yml` runs it on GitHub Actions: CSE every 30
minutes during trading hours, everything once a day after CBSL publishes. Add
`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` as repository secrets. GitHub runs
schedules only from the default branch. The service-role key bypasses RLS; never
put it in the app.

## When a site changes

Run `--dry-run --sources <name>`; if a parser finds nothing, save the page to
`tests/fixtures/`, add a test, and adjust the parser in `market_scraper/sources/`.
