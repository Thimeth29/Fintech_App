# Sandbox Investment module

Self-contained Flutter/Dart module implementing the sandbox environment from
the proposal: trading against **real market prices** (CBSL exchange rates,
CSE stock prices, bank rates — via the scraper pipeline) using **entirely
virtual money**. No real funds ever move; only the prices trades execute at
are real.

## What's inside

```
lib/sandbox/
  models/         Instrument, Holding, TermPosition, CommunityPosition, Portfolio, Transaction
  data/           mock_instruments.dart — instrument catalogue (edit terms/rates here)
  services/
    price_source.dart          PriceSource — abstract interface, live or simulated
    live_price_source.dart     LiveSupabasePriceSource — real prices from your scraper's Supabase table
    price_simulator.dart       SimulatedPriceSource — offline/demo random-walk fallback
    sandbox_engine.dart        All trading rules (buy/sell/term/community) — virtual money always
  providers/      SandboxProvider — ChangeNotifier wrapper, `.live()` or `.simulated()` factories
  widgets/        InstrumentCard, trade bottom sheet, shared color tokens
  screens/        SandboxHomeScreen (list + portfolio summary, live/demo indicator), PortfolioScreen (breakdown/history)
  utils/          formatLkr / formatPct helpers (no intl dependency needed)
```

The engine (`SandboxEngine`) and the `PriceSource` implementations have
**no dependency on trade logic knowing where prices came from** — the same
buy/sell/term/community code runs identically whether prices are live or
simulated. That's the point of the `PriceSource` abstraction: swap the feed
without touching a single line of trading logic.

### Trading rules implemented
- **Tradable** (gold, forex, stocks): buy by LKR amount, sell by quantity, at the current price (live or simulated) with average-cost tracking and unrealized P&L.
- **Term** (fixed deposits, treasury bonds): lock a principal for a fixed term at a fixed rate; withdrawing before maturity pays only the accrued value so far (mirrors an early-withdrawal penalty); withdrawing after maturity pays the full maturity value.
- **Community fund**: join, contribute per round, and simulate receiving the pooled payout on your turn.

All balances start at `kSandboxStartingBalance` (LKR 100,000) — call `resetSandbox()` any time. This resets fake money only; it never touches real prices.

## How live prices reach the app

```
Scraper job (CBSL / CSE / bank sites) --> market_prices table in Supabase --> LiveSupabasePriceSource --> SandboxEngine (virtual money trades)
```

Create the table your scraper (from the earlier scraping work) writes into:

```sql
create table market_prices (
  instrument_id text primary key,
  price numeric not null,
  daily_change_pct numeric not null default 0,
  updated_at timestamptz not null default now()
);

-- required for realtime price pushes to the app
alter publication supabase_realtime add table market_prices;
```

`instrument_id` values must match the `id` fields in `mock_instruments.dart`
(e.g. `gold_sovereign`, `forex_usd`, `cse_jkh`) so the app knows which row
maps to which instrument. Your Python scraper job upserts into this table
on its schedule, e.g.:

```python
supabase.table("market_prices").upsert({
    "instrument_id": "cse_jkh",
    "price": latest_price,
    "daily_change_pct": pct_change,
}).execute()
```

The app never scrapes anything itself — it only reads this table, live via
Supabase Realtime with a 2-minute poll as a safety net if the websocket drops.

## 1. Create your branch

```bash
git clone https://github.com/Thimeth29/Fintech_App.git
cd Fintech_App
git checkout -b feature/sandbox-environment
```

## 2. Drop the module in

Copy the `lib/sandbox/` folder from this package into your repo's `lib/` folder
(don't overwrite anything — it's a self-contained subfolder).

## 3. Add dependencies

In `pubspec.yaml`:

```yaml
dependencies:
  provider: ^6.1.2
  supabase_flutter: ^2.5.0   # skip this if your app already has it
```

Then `flutter pub get`.

## 4. Wire it into the app

In `main.dart`, initialize Supabase (if not already done elsewhere in the
app) and provide `SandboxProvider.live(...)`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sandbox/providers/sandbox_provider.dart';
import 'sandbox/screens/sandbox_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  final sandboxProvider = SandboxProvider.live(client: Supabase.instance.client);
  await sandboxProvider.start(); // fetches current prices + subscribes to realtime

  runApp(
    ChangeNotifierProvider.value(
      value: sandboxProvider,
      child: const MyApp(),
    ),
  );
}
```

Prefer to keep developing without a live Supabase connection yet? Use the
simulated feed instead — same UI, same trading rules, mock prices:

```dart
final sandboxProvider = SandboxProvider.simulated();
await sandboxProvider.start();
```

Then navigate to it from wherever "Sandbox Investing" lives in your nav:

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const SandboxHomeScreen()),
);
```

## 5. Commit and push your branch

```bash
git add .
git commit -m "Add sandbox investment environment (engine + UI)"
git push -u origin feature/sandbox-environment
```

Then open a PR into `main` (or your team's integration branch) on GitHub.

## Notes / next steps for the team
- `mock_instruments.dart` is the single place to tune term rates and add/remove instruments — `instrument_id` must match what the scraper upserts.
- `LiveSupabasePriceSource` swallows fetch errors and keeps the last known price rather than crashing the app — worth wiring to your app's error reporting so a broken scraper gets noticed.
- If a row for an instrument is missing entirely (scraper hasn't run yet, or an id typo), `priceOf` returns `0` — the UI will show that plainly rather than a fake number, so it's a clear signal something upstream needs attention.
- Trades, holdings, and cash balance are still **in-memory only** — that part hasn't changed. Persisting `Portfolio` per user (e.g. to Supabase) so sandbox progress survives app restarts is a good next PR.
- `SimulatedPriceSource` is kept around intentionally — useful for local dev, demos, and widget tests without needing a live Supabase connection.
