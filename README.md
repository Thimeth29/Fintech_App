# FinSmart — Personal Finance Management

Flutter app (Android / iOS / Web) for managing personal expenses and
investments, with CSE market insights and an OpenAI-powered "FinBot"
assistant. Built with the Provider (MVVM) pattern and Supabase as the
backend.

## 1. Install dependencies

```bash
flutter pub get
```

## 2. Set up the database

This app is already wired to the Supabase project you provided
(`https://zgpvwddcduemjkldzcvl.supabase.co`, see
`lib/core/config/supabase_config.dart`). Before first run, open that
project's SQL Editor in the Supabase dashboard and run
`supabase_schema.sql` from the root of this project. It creates:

- `profiles` — name/email/mobile for each signed-up user
- `expenses` — expenditure tracking entries
- `investment_actions` — history of investment decisions logged from the
  analytics pages
- `chat_messages` — reserved for persisting FinBot conversations

Every table has Row Level Security enabled so a user can only read/write
their own rows.

Also confirm, under Authentication -> Providers, that Email sign-up is
enabled (it is by default), and under Authentication -> URL
Configuration that email confirmation is either disabled for testing or
that you have an email provider configured — otherwise signUp will
succeed but the account won't be usable until confirmed.

## 3. Set up FinBot (OpenAI)

The bot needs an OpenAI API key at runtime. Don't hardcode it — pass it
in with --dart-define:

```bash
flutter run --dart-define=OPENAI_API_KEY=sk-xxxxxxxx
```

For web/release builds, pass the same flag to `flutter build`. Without a
key, the chat screens still work but FinBot will explain that it isn't
connected yet instead of crashing.

## 4. Run

```bash
flutter run                # mobile/desktop, pick a device
flutter run -d chrome       # web
```

## App structure (MVVM)

```
lib/
  core/       config, theme, router stub, shared widgets
  models/     plain data classes
  services/   talk to Supabase / CSE / OpenAI — no UI, no state
  viewmodels/ ChangeNotifier classes the views watch via Provider
  views/      screens, grouped by feature (auth, home, investments, ...)
```

## Notes & honest limitations

- CSE data is live via the unofficial cse.lk/api endpoints (top
  gainers/losers). It's not an official/documented API, so it can
  change or fail — the app falls back to sample data if it does.
- SEC (government securities), FD, and Gold pages use clearly-labelled
  reference figures, not a live feed, since there's no free public API
  for these. Swap lib/services/asset_data_service.dart for a real data
  source when you have one.
- Insights and suggested actions are rule-based (fast, free, always
  available). FinBot (OpenAI) is there for open-ended questions.
- Login uses email/password (Supabase's built-in auth), not just a name.
