# Sandbox Investment Environment — architecture (V04)

Practise investing with real Sri Lankan market data and virtual money.

## Core idea: prices are separate from trading

```
            PriceSource  ("what is X worth now?")
        ┌───────────────┼──────────────────┐
SimulatedPriceSource  LivePriceSource   FallbackPriceSource
(seeded random walk,  (Supabase          (live where fresh,
 offline / demo /      market_prices +    simulated otherwise)
 tests)                Realtime)
                        │
                 SandboxTradingEngine   (knows nothing about where prices come from)
        ┌───────────────┼──────────────────┐
  TradableEngine      TermEngine        SeettuEngine
  CSE, gold, forex,   FD, T-bill,       community fund
  trading             T-bond            (rotating savings)
```

| File | Role |
|---|---|
| `lib/services/sandbox/price_source.dart` | `PriceSource` interface, `PriceQuote`, `FallbackPriceSource` |
| `lib/services/sandbox/simulated_price_source.dart` | Mock prices from `price_engine.dart`, anchored to real starting prices |
| `lib/services/sandbox/live_price_source.dart` | Reads `market_prices` / `market_price_history`, subscribes with Realtime |
| `lib/services/sandbox/trading_engine.dart` | Trading rules: spreads, fees, term maths, seettu |
| `lib/viewmodels/sandbox_viewmodel.dart` | Wires a `PriceSource` + the engine to wallets, Supabase RPCs and gamification |

Switching source (the **Live market / Simulated** control on the trainer hub) changes
only `SandboxViewModel.prices`; the engine and every screen stay the same.
`test/sandbox/price_source_engine_test.dart` runs the engine on a fixed fake source.

## Instruments

- **Tradable** (buy and sell any time at the current price): CSE shares (1.12% fees),
  gold (3% dealer spread, making charge on jewellery), foreign currency (CBSL rate
  ±0.75%), fictional trading instruments.
- **Term** (FD, T-bill, T-bond): money locked at a fixed rate. Withdrawing early pays
  the principal (a T-bill's price) plus interest accrued so far after tax — you give up
  the rest of the return. The server computes this (`_sandbox_withdrawal_amount`).
- **Community fund**: a simulated seettu. Members pay every month, one takes the pot.
  A member who took their pot may stop paying (more likely with strangers). You can only
  join if your wallet covers every round you'd owe.

## Live data pipeline

```
CBSL exrates ─┐
CSE API      ─┼─▶ scraper/ (Python, GitHub Actions schedule) ─▶ market_prices ─▶ app (read + Realtime)
Bank pages   ─┘
```

The app never scrapes. See `scraper/README.md`.

## Fast-forward

Simulated prices follow each module's sim clock. Tradable modules on live prices run in
real time (no fast-forward); term modules and the seettu still fast-forward because their
rates are locked when opened.

## Database

`supabase/migrations/20261014090000_sandbox_live_prices.sql` (also appended to
`supabase_schema.sql`); tests in `supabase/tests/sandbox_live_prices_test.sql`.
