-- ============================================================
-- FINOPS SUPABASE POSTGRESQL DATABASE SCHEMA & RLS POLICIES
-- Paste this script into your Supabase Dashboard SQL Editor
-- (https://supabase.com/dashboard/project/_/sql)
-- ============================================================

-- 1. Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. User Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  email TEXT,
  mobile_number TEXT,
  user_role TEXT DEFAULT 'App User / Citizen',
  occupation TEXT DEFAULT 'Employed',
  district TEXT DEFAULT 'Colombo',
  preferred_language TEXT DEFAULT 'English',
  money_profile TEXT DEFAULT 'Moderate Saver',
  selected_assets TEXT[] DEFAULT '{}',
  is_under_18 BOOLEAN DEFAULT FALSE,
  guardian_name TEXT,
  guardian_mobile TEXT,
  guardian_relation TEXT,
  guardian_status TEXT DEFAULT 'pending',
  -- Signup Step 4 "Your money today" answers — used to personalize FinBot
  -- (see FinancialInsightService.buildSnapshot), not just to record history.
  monthly_income TEXT,
  income_source TEXT,
  typical_monthly_spending TEXT,
  emergency_savings TEXT,
  dependents TEXT,
  financial_literacy_rank TEXT DEFAULT 'Bronze Investor',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Expenses Table
CREATE TABLE IF NOT EXISTS public.expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  amount NUMERIC(12, 2) NOT NULL,
  note TEXT,
  expense_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Budgets Table
CREATE TABLE IF NOT EXISTS public.budgets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  limit_amount NUMERIC(12, 2) NOT NULL,
  month_year TEXT NOT NULL, -- e.g. "2026-10"
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, category, month_year)
);

-- 5. Sandbox Portfolio Table
CREATE TABLE IF NOT EXISTS public.sandbox_portfolios (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  virtual_balance NUMERIC(14, 2) DEFAULT 100000.00,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Sandbox Holdings Table
CREATE TABLE IF NOT EXISTS public.sandbox_holdings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  symbol TEXT NOT NULL,
  name TEXT NOT NULL,
  instrument_type TEXT NOT NULL,
  quantity NUMERIC(12, 4) NOT NULL DEFAULT 0,
  average_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, symbol)
);

-- 7. Investment Logs Table
CREATE TABLE IF NOT EXISTS public.investment_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  action_type TEXT NOT NULL, -- "BUY", "SELL", "CONSIDERED"
  symbol TEXT NOT NULL,
  asset_class TEXT NOT NULL,
  amount NUMERIC(14, 2) NOT NULL,
  log_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. AI Chat Messages History Table
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL, -- "user", "bot"
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sandbox_portfolios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sandbox_holdings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investment_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Expenses Policies
CREATE POLICY "Users can view own expenses" ON public.expenses FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own expenses" ON public.expenses FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own expenses" ON public.expenses FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own expenses" ON public.expenses FOR DELETE USING (auth.uid() = user_id);

-- Budgets Policies
CREATE POLICY "Users can view own budgets" ON public.budgets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own budgets" ON public.budgets FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own budgets" ON public.budgets FOR UPDATE USING (auth.uid() = user_id);

-- Sandbox Portfolios Policies
CREATE POLICY "Users can view own portfolio" ON public.sandbox_portfolios FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own portfolio" ON public.sandbox_portfolios FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own portfolio" ON public.sandbox_portfolios FOR UPDATE USING (auth.uid() = user_id);

-- Sandbox Holdings Policies
CREATE POLICY "Users can view own holdings" ON public.sandbox_holdings FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own holdings" ON public.sandbox_holdings FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own holdings" ON public.sandbox_holdings FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own holdings" ON public.sandbox_holdings FOR DELETE USING (auth.uid() = user_id);

-- Investment Logs Policies
CREATE POLICY "Users can view own investment logs" ON public.investment_logs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own investment logs" ON public.investment_logs FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Chat Messages Policies
CREATE POLICY "Users can view own chat messages" ON public.chat_messages FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own chat messages" ON public.chat_messages FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- AUTOMATIC PROFILE & SANDBOX INITIALIZATION TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (new.id, new.raw_user_meta_data->>'full_name', new.email);

  INSERT INTO public.sandbox_portfolios (user_id, virtual_balance)
  VALUES (new.id, 100000.00);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger execution after auth sign up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- INVESTING OPTIONS: MARKET RATE TABLES (public, read-only)
-- Written by a scheduled scraper using the service-role key,
-- read by the app via Supabase Realtime.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.fd_rates (
  institution TEXT PRIMARY KEY,
  institution_type TEXT NOT NULL DEFAULT 'LCB' CHECK (institution_type IN ('LCB', 'LSB', 'LFC')),
  sldis_member BOOLEAN NOT NULL DEFAULT TRUE,
  rate_1m NUMERIC(5, 2),
  rate_3m NUMERIC(5, 2),
  rate_6m NUMERIC(5, 2),
  rate_12m NUMERIC(5, 2),
  rate_24m NUMERIC(5, 2),
  rate_60m NUMERIC(5, 2),
  source_url TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.gov_security_yields (
  security TEXT PRIMARY KEY,              -- e.g. '91-day T-Bill', '5-year T-Bond'
  kind TEXT NOT NULL CHECK (kind IN ('bill', 'bond')),
  sort_order INT NOT NULL DEFAULT 0,
  yield_rate NUMERIC(6, 3),
  previous_yield NUMERIC(6, 3),
  auction_date DATE,
  source_url TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.fd_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gov_security_yields ENABLE ROW LEVEL SECURITY;

-- Anyone may read; only the service role (scraper) can write.
CREATE POLICY "Public can read FD rates" ON public.fd_rates FOR SELECT USING (true);
CREATE POLICY "Public can read gov security yields" ON public.gov_security_yields FOR SELECT USING (true);

-- Push row changes to the app in real time.
ALTER PUBLICATION supabase_realtime ADD TABLE public.fd_rates;
ALTER PUBLICATION supabase_realtime ADD TABLE public.gov_security_yields;

-- ============================================================
-- DAILY RATE COLLECTOR SCHEDULE
-- Runs the `collect-rates` edge function every day at 9:00 am
-- Sri Lanka time (03:30 UTC). The job's password lives in Vault; the
-- function checks it via verify_cron_secret(). Replace <CRON_SECRET>
-- with a random value when setting up a new project — never commit it.
-- ============================================================

SELECT vault.create_secret(
  '<CRON_SECRET>',
  'collect_rates_cron_secret',
  'x-cron-secret header for the collect-rates edge function'
);

-- Lets the edge function (service role only) check a candidate password
-- without being able to read it.
CREATE OR REPLACE FUNCTION public.verify_cron_secret(candidate text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM vault.decrypted_secrets
    WHERE name = 'collect_rates_cron_secret' AND decrypted_secret = candidate
  );
$$;

REVOKE EXECUTE ON FUNCTION public.verify_cron_secret(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_cron_secret(text) TO service_role;

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

SELECT cron.schedule(
  'collect-rates-daily',
  '30 3 * * *',
  $$
  SELECT net.http_post(
    url := 'https://uttemjtuxeasyccxhhlz.supabase.co/functions/v1/collect-rates',
    headers := jsonb_build_object(
      'x-cron-secret',
      (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'collect_rates_cron_secret')
    ),
    timeout_milliseconds := 60000
  );
  $$
);

-- ============================================================
-- EXPENDITURE UPGRADE (identical to supabase/migrations/20261011120000_expenditure_upgrade.sql)
-- ============================================================

-- ------------------------------------------------------------
-- 1. Recurring expenses (created first: expenses.recurring_id points here)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.recurring_expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  note TEXT,
  priority TEXT NOT NULL DEFAULT 'essential'
    CHECK (priority IN ('essential', 'important', 'flexible')),
  frequency TEXT NOT NULL CHECK (frequency IN ('weekly', 'monthly')),
  -- First occurrence; monthly items keep this day-of-month (clamped to
  -- short months) so 31st -> 28th Feb -> 31st Mar doesn't drift.
  start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  next_due_date DATE NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- 2. Expenses: priority, link to the recurring item that generated it
-- ------------------------------------------------------------
ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'flexible',
  ADD COLUMN IF NOT EXISTS recurring_id UUID
    REFERENCES public.recurring_expenses(id) ON DELETE SET NULL;

DO $$ BEGIN
  ALTER TABLE public.expenses ADD CONSTRAINT expenses_priority_check
    CHECK (priority IN ('essential', 'important', 'flexible'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- One generated expense per recurring item per date: makes recurring
-- generation idempotent (re-running it can never double-insert). NULL
-- recurring_ids are distinct, so ordinary expenses are unaffected.
DO $$ BEGIN
  ALTER TABLE public.expenses ADD CONSTRAINT expenses_recurring_occurrence_key
    UNIQUE (recurring_id, expense_date);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Backfill: give old rows a date and the default priority for their category.
UPDATE public.expenses SET expense_date = created_at::date WHERE expense_date IS NULL;
UPDATE public.expenses SET priority = CASE
    WHEN category IN ('Housing', 'Utilities', 'Transport') THEN 'essential'
    WHEN category = 'Food' THEN 'important'
    ELSE 'flexible'
  END
WHERE recurring_id IS NULL;

CREATE INDEX IF NOT EXISTS expenses_user_id_idx ON public.expenses (user_id);
CREATE INDEX IF NOT EXISTS expenses_user_id_expense_date_idx ON public.expenses (user_id, expense_date);

-- ------------------------------------------------------------
-- 3. Budgets: allow deleting, index
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "Users can delete own budgets" ON public.budgets;
CREATE POLICY "Users can delete own budgets" ON public.budgets FOR DELETE USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS budgets_user_id_idx ON public.budgets (user_id);

-- ------------------------------------------------------------
-- 4. Finance settings (one row per user)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.finance_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  monthly_income NUMERIC(14, 2) CHECK (monthly_income >= 0),
  income_day INT CHECK (income_day BETWEEN 1 AND 28),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- 5. Savings goals + contributions
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.savings_goals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  target_amount NUMERIC(14, 2) NOT NULL CHECK (target_amount > 0),
  deadline DATE,
  icon TEXT,
  -- Optional; when set it is reserved in the month's safe-to-spend.
  planned_monthly_contribution NUMERIC(14, 2) CHECK (planned_monthly_contribution >= 0),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'archived')),
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.goal_contributions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id UUID NOT NULL REFERENCES public.savings_goals(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  -- Positive = add to the goal, negative = withdraw.
  amount NUMERIC(14, 2) NOT NULL CHECK (amount <> 0),
  note TEXT,
  contributed_on DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- 6. Debts & loans + payments
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.debts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  -- 'lent' = they owe me, 'borrowed' = I owe them.
  direction TEXT NOT NULL CHECK (direction IN ('lent', 'borrowed')),
  person_name TEXT NOT NULL CHECK (length(trim(person_name)) > 0),
  principal_amount NUMERIC(14, 2) NOT NULL CHECK (principal_amount > 0),
  note TEXT,
  start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  due_date DATE,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'settled')),
  settled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.debt_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  debt_id UUID NOT NULL REFERENCES public.debts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
  paid_on DATE NOT NULL DEFAULT CURRENT_DATE,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Server-side guard: a payment may not exceed what is still outstanding.
-- (The app checks this too; this stops a stale screen or a second device.)
CREATE OR REPLACE FUNCTION public.check_debt_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_principal NUMERIC;
  v_paid NUMERIC;
BEGIN
  SELECT principal_amount INTO v_principal
  FROM public.debts WHERE id = NEW.debt_id AND user_id = NEW.user_id
  FOR UPDATE;
  IF v_principal IS NULL THEN
    RAISE EXCEPTION 'Debt not found';
  END IF;
  SELECT COALESCE(SUM(amount), 0) INTO v_paid
  FROM public.debt_payments
  WHERE debt_id = NEW.debt_id AND id IS DISTINCT FROM NEW.id;
  IF v_paid + NEW.amount > v_principal THEN
    RAISE EXCEPTION 'Payment exceeds the outstanding balance';
  END IF;
  RETURN NEW;
END;
$$;

-- Keeps debts.status in sync: settled at 0 outstanding, reopened otherwise.
CREATE OR REPLACE FUNCTION public.sync_debt_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_debt_id UUID := COALESCE(NEW.debt_id, OLD.debt_id);
  v_outstanding NUMERIC;
BEGIN
  SELECT d.principal_amount - COALESCE(SUM(p.amount), 0) INTO v_outstanding
  FROM public.debts d LEFT JOIN public.debt_payments p ON p.debt_id = d.id
  WHERE d.id = v_debt_id
  GROUP BY d.principal_amount;

  UPDATE public.debts SET
    status = CASE WHEN v_outstanding <= 0 THEN 'settled' ELSE 'open' END,
    settled_at = CASE WHEN v_outstanding <= 0 THEN COALESCE(settled_at, NOW()) ELSE NULL END
  WHERE id = v_debt_id;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS debt_payments_check ON public.debt_payments;
CREATE TRIGGER debt_payments_check
  BEFORE INSERT OR UPDATE ON public.debt_payments
  FOR EACH ROW EXECUTE FUNCTION public.check_debt_payment();

DROP TRIGGER IF EXISTS debt_payments_sync_status ON public.debt_payments;
CREATE TRIGGER debt_payments_sync_status
  AFTER INSERT OR UPDATE OR DELETE ON public.debt_payments
  FOR EACH ROW EXECUTE FUNCTION public.sync_debt_status();

-- ------------------------------------------------------------
-- 7. Row level security
-- ------------------------------------------------------------
ALTER TABLE public.recurring_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goal_contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debt_payments ENABLE ROW LEVEL SECURITY;

-- Owner-only tables.
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['recurring_expenses', 'finance_settings', 'savings_goals', 'debts'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS "Users can view own %1$s" ON public.%1$I', t);
    EXECUTE format('DROP POLICY IF EXISTS "Users can insert own %1$s" ON public.%1$I', t);
    EXECUTE format('DROP POLICY IF EXISTS "Users can update own %1$s" ON public.%1$I', t);
    EXECUTE format('DROP POLICY IF EXISTS "Users can delete own %1$s" ON public.%1$I', t);
    EXECUTE format('CREATE POLICY "Users can view own %1$s" ON public.%1$I FOR SELECT USING (auth.uid() = user_id)', t);
    EXECUTE format('CREATE POLICY "Users can insert own %1$s" ON public.%1$I FOR INSERT WITH CHECK (auth.uid() = user_id)', t);
    EXECUTE format('CREATE POLICY "Users can update own %1$s" ON public.%1$I FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)', t);
    EXECUTE format('CREATE POLICY "Users can delete own %1$s" ON public.%1$I FOR DELETE USING (auth.uid() = user_id)', t);
  END LOOP;
END $$;

-- Child rows: owner-only AND the parent must belong to the same user, so a
-- guessed goal/debt id from another account can't be attached to.
DROP POLICY IF EXISTS "Users can view own goal_contributions" ON public.goal_contributions;
DROP POLICY IF EXISTS "Users can insert own goal_contributions" ON public.goal_contributions;
DROP POLICY IF EXISTS "Users can update own goal_contributions" ON public.goal_contributions;
DROP POLICY IF EXISTS "Users can delete own goal_contributions" ON public.goal_contributions;
CREATE POLICY "Users can view own goal_contributions" ON public.goal_contributions
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own goal_contributions" ON public.goal_contributions
  FOR INSERT WITH CHECK (auth.uid() = user_id AND EXISTS (
    SELECT 1 FROM public.savings_goals g WHERE g.id = goal_id AND g.user_id = auth.uid()));
CREATE POLICY "Users can update own goal_contributions" ON public.goal_contributions
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id AND EXISTS (
    SELECT 1 FROM public.savings_goals g WHERE g.id = goal_id AND g.user_id = auth.uid()));
CREATE POLICY "Users can delete own goal_contributions" ON public.goal_contributions
  FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own debt_payments" ON public.debt_payments;
DROP POLICY IF EXISTS "Users can insert own debt_payments" ON public.debt_payments;
DROP POLICY IF EXISTS "Users can update own debt_payments" ON public.debt_payments;
DROP POLICY IF EXISTS "Users can delete own debt_payments" ON public.debt_payments;
CREATE POLICY "Users can view own debt_payments" ON public.debt_payments
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own debt_payments" ON public.debt_payments
  FOR INSERT WITH CHECK (auth.uid() = user_id AND EXISTS (
    SELECT 1 FROM public.debts d WHERE d.id = debt_id AND d.user_id = auth.uid()));
CREATE POLICY "Users can update own debt_payments" ON public.debt_payments
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id AND EXISTS (
    SELECT 1 FROM public.debts d WHERE d.id = debt_id AND d.user_id = auth.uid()));
CREATE POLICY "Users can delete own debt_payments" ON public.debt_payments
  FOR DELETE USING (auth.uid() = user_id);

-- ------------------------------------------------------------
-- 8. Indexes on user_id (and the obvious child lookups)
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS recurring_expenses_user_id_idx ON public.recurring_expenses (user_id);
CREATE INDEX IF NOT EXISTS savings_goals_user_id_idx ON public.savings_goals (user_id);
CREATE INDEX IF NOT EXISTS goal_contributions_user_id_idx ON public.goal_contributions (user_id);
CREATE INDEX IF NOT EXISTS goal_contributions_goal_id_idx ON public.goal_contributions (goal_id);
CREATE INDEX IF NOT EXISTS debts_user_id_idx ON public.debts (user_id);
CREATE INDEX IF NOT EXISTS debt_payments_user_id_idx ON public.debt_payments (user_id);
CREATE INDEX IF NOT EXISTS debt_payments_debt_id_idx ON public.debt_payments (debt_id);
-- finance_settings.user_id is already indexed by its UNIQUE constraint.

-- ============================================================
-- SANDBOX → INVESTMENT TRAINER (identical to supabase/migrations/20261012090000_sandbox_trainer.sql)
-- Supersedes the sandbox policies and handle_new_user() defined above;
-- sandbox_portfolios is deprecated and no longer used by the app.
-- ============================================================

-- ============================================================
-- SANDBOX → INVESTMENT TRAINER
--
-- Five training modules (cse, fd, gold, trading, gov_securities), each
-- with its own virtual wallet. Every money change goes through a
-- SECURITY DEFINER function below; users can only SELECT their own rows.
--
-- Trust model: the simulated price engine runs on the client (it is pure
-- Dart so it works offline and on web), so the client sends the execution
-- price, fees and fast-forward payouts. That is acceptable because no real
-- money exists anywhere in this feature. The functions still enforce the
-- invariants that matter for a fair, bug-free trainer: positive amounts,
-- no overspending, no selling what you don't own, one wallet lock per
-- trade, and sanity caps on fees and payouts. Leaderboards stay off for
-- this reason: a modified client could report any price.
--
-- Wallets are created lazily, when a module's simulator is unlocked
-- (first lesson + quiz passed). See sandbox_unlock_module().
-- ============================================================

-- ------------------------------------------------------------
-- 1. Tables
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sandbox_wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  module TEXT NOT NULL CHECK (module IN ('cse', 'fd', 'gold', 'trading', 'gov_securities')),
  balance NUMERIC(14, 2) NOT NULL DEFAULT 100000.00 CHECK (balance >= 0),
  -- The module's simulated "today". Day 0 of the price path is start_date.
  sim_date DATE NOT NULL DEFAULT CURRENT_DATE,
  start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  -- Real-data starting prices/yields captured when the module was unlocked
  -- (or last reset), so the simulated path is reproducible after a reload.
  price_anchors JSONB NOT NULL DEFAULT '{}'::jsonb,
  reset_count INT NOT NULL DEFAULT 0 CHECK (reset_count >= 0),
  current_reset_batch UUID NOT NULL DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (sim_date >= start_date),
  UNIQUE (user_id, module)
);

-- Holdings: per module now. Existing rows are CSE shares.
ALTER TABLE public.sandbox_holdings
  ADD COLUMN IF NOT EXISTS module TEXT NOT NULL DEFAULT 'cse',
  ADD COLUMN IF NOT EXISTS direction TEXT NOT NULL DEFAULT 'long',
  ADD COLUMN IF NOT EXISTS total_fees NUMERIC(14, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS stop_loss NUMERIC(14, 4),
  ADD COLUMN IF NOT EXISTS take_profit NUMERIC(14, 4),
  ADD COLUMN IF NOT EXISTS opened_sim_date DATE;

ALTER TABLE public.sandbox_holdings ALTER COLUMN average_price TYPE NUMERIC(14, 4);
UPDATE public.sandbox_holdings SET opened_sim_date = COALESCE(opened_sim_date, created_at::date, CURRENT_DATE);
ALTER TABLE public.sandbox_holdings ALTER COLUMN opened_sim_date SET DEFAULT CURRENT_DATE;
ALTER TABLE public.sandbox_holdings ALTER COLUMN opened_sim_date SET NOT NULL;
-- The old stock type label, normalised (the trainer matches types lowercase).
UPDATE public.sandbox_holdings SET instrument_type = lower(instrument_type);

ALTER TABLE public.sandbox_holdings DROP CONSTRAINT IF EXISTS sandbox_holdings_user_id_symbol_key;
DO $$ BEGIN
  ALTER TABLE public.sandbox_holdings ADD CONSTRAINT sandbox_holdings_user_module_symbol_key
    UNIQUE (user_id, module, symbol);
EXCEPTION WHEN duplicate_object OR duplicate_table THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE public.sandbox_holdings ADD CONSTRAINT sandbox_holdings_module_check
    CHECK (module IN ('cse', 'gold', 'trading'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE public.sandbox_holdings ADD CONSTRAINT sandbox_holdings_direction_check
    CHECK (direction IN ('long', 'short'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE public.sandbox_holdings ADD CONSTRAINT sandbox_holdings_amounts_check
    CHECK (quantity > 0 AND average_price > 0 AND total_fees >= 0
           AND (stop_loss IS NULL OR stop_loss > 0)
           AND (take_profit IS NULL OR take_profit > 0));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- FDs, T-bills and T-bonds.
CREATE TABLE IF NOT EXISTS public.sandbox_positions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  module TEXT NOT NULL CHECK (module IN ('fd', 'gov_securities')),
  type TEXT NOT NULL CHECK (type IN ('fd', 'tbill', 'tbond')),
  label TEXT NOT NULL,                       -- bank name / "364-day T-Bill"
  principal NUMERIC(14, 2) NOT NULL CHECK (principal > 0), -- FD deposit or face value
  cost NUMERIC(14, 2) NOT NULL CHECK (cost > 0),           -- cash paid at opening
  rate NUMERIC(7, 4) NOT NULL CHECK (rate >= 0 AND rate <= 50), -- FD rate / yield at purchase, % p.a.
  coupon_rate NUMERIC(7, 4) CHECK (coupon_rate >= 0 AND coupon_rate <= 50), -- T-bonds only
  payout_type TEXT NOT NULL CHECK (payout_type IN ('maturity', 'monthly', 'discount', 'semi_annual')),
  tenure_months INT CHECK (tenure_months > 0),
  tenure_days INT CHECK (tenure_days > 0),
  start_sim_date DATE NOT NULL,
  maturity_sim_date DATE NOT NULL,
  last_payout_sim_date DATE,
  payouts_count INT NOT NULL DEFAULT 0 CHECK (payouts_count >= 0),
  total_paid NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (total_paid >= 0),
  auto_renew BOOLEAN NOT NULL DEFAULT FALSE,
  renew_count INT NOT NULL DEFAULT 0 CHECK (renew_count >= 0),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'matured', 'closed_early', 'archived')),
  closed_amount NUMERIC(14, 2) CHECK (closed_amount >= 0),
  closed_sim_date DATE,
  reset_batch UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (maturity_sim_date > start_sim_date)
);

-- Full history. Never deleted by a reset: rows keep their reset_batch.
CREATE TABLE IF NOT EXISTS public.sandbox_trades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  module TEXT NOT NULL CHECK (module IN ('cse', 'fd', 'gold', 'trading', 'gov_securities')),
  symbol TEXT NOT NULL,
  side TEXT NOT NULL CHECK (side IN (
    'buy', 'sell', 'short', 'cover',
    'fd_open', 'fd_interest', 'fd_mature', 'fd_renew', 'fd_break',
    'tbill_buy', 'tbill_mature', 'tbond_buy', 'tbond_coupon', 'tbond_mature', 'tbond_sell',
    'dividend', 'updown_stake', 'updown_payout')),
  quantity NUMERIC(14, 4) NOT NULL CHECK (quantity > 0),
  price NUMERIC(14, 4) NOT NULL CHECK (price >= 0),
  fee NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (fee >= 0),
  -- Signed change to the wallet balance caused by this row.
  cash_delta NUMERIC(14, 2) NOT NULL DEFAULT 0,
  realised_pnl NUMERIC(14, 2),
  ref_id UUID,                                -- position id, or the stake row for an up/down payout
  note TEXT,
  sim_date DATE NOT NULL,
  reset_batch UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- One payout per up/down stake.
CREATE UNIQUE INDEX IF NOT EXISTS sandbox_trades_updown_payout_key
  ON public.sandbox_trades (ref_id) WHERE side = 'updown_payout';

CREATE TABLE IF NOT EXISTS public.sandbox_progress (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  xp INT NOT NULL DEFAULT 0 CHECK (xp >= 0),
  level INT NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 10),
  streak_count INT NOT NULL DEFAULT 0 CHECK (streak_count >= 0),
  best_streak INT NOT NULL DEFAULT 0 CHECK (best_streak >= 0),
  last_active_date DATE,
  -- Daily cap for "good habit" XP (stop-losses, small risk, breaks).
  habit_xp_today INT NOT NULL DEFAULT 0 CHECK (habit_xp_today >= 0),
  habit_xp_date DATE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.sandbox_lesson_progress (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  module TEXT NOT NULL CHECK (module IN ('cse', 'fd', 'gold', 'trading', 'gov_securities')),
  lesson_id TEXT NOT NULL CHECK (length(lesson_id) BETWEEN 1 AND 64),
  read_at TIMESTAMPTZ,
  quiz_score NUMERIC(5, 2) CHECK (quiz_score BETWEEN 0 AND 100),
  attempts INT NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  completed_at TIMESTAMPTZ,                   -- set when the quiz is passed (>= 70%)
  PRIMARY KEY (user_id, module, lesson_id)
);

CREATE TABLE IF NOT EXISTS public.sandbox_badges (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  badge_id TEXT NOT NULL CHECK (length(badge_id) BETWEEN 1 AND 64),
  earned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, badge_id)
);

CREATE TABLE IF NOT EXISTS public.sandbox_challenges (
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  challenge_id TEXT NOT NULL CHECK (length(challenge_id) BETWEEN 1 AND 64),
  progress INT NOT NULL DEFAULT 0 CHECK (progress >= 0),
  target INT NOT NULL DEFAULT 1 CHECK (target > 0),
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, challenge_id)
);

-- ------------------------------------------------------------
-- 2. Indexes
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS sandbox_wallets_user_id_idx ON public.sandbox_wallets (user_id);
-- (user_id, module) on wallets is covered by its UNIQUE constraint.
CREATE INDEX IF NOT EXISTS sandbox_holdings_user_id_idx ON public.sandbox_holdings (user_id);
CREATE INDEX IF NOT EXISTS sandbox_holdings_user_module_idx ON public.sandbox_holdings (user_id, module);
CREATE INDEX IF NOT EXISTS sandbox_positions_user_id_idx ON public.sandbox_positions (user_id);
CREATE INDEX IF NOT EXISTS sandbox_positions_user_module_idx ON public.sandbox_positions (user_id, module, status);
CREATE INDEX IF NOT EXISTS sandbox_trades_user_id_idx ON public.sandbox_trades (user_id);
CREATE INDEX IF NOT EXISTS sandbox_trades_user_module_idx ON public.sandbox_trades (user_id, module, created_at DESC);
CREATE INDEX IF NOT EXISTS sandbox_lesson_progress_user_module_idx ON public.sandbox_lesson_progress (user_id, module);

-- ------------------------------------------------------------
-- 3. Migrate existing data
-- ------------------------------------------------------------
-- Each legacy portfolio becomes a CSE wallet with the same balance. The two
-- legacy prices are kept as anchors so the migrated JKH.N holding is valued
-- from the price it was bought at, not from today's (post-split) market.
INSERT INTO public.sandbox_wallets (user_id, module, balance, sim_date, start_date, price_anchors, created_at)
SELECT p.user_id, 'cse', COALESCE(p.virtual_balance, 100000.00), CURRENT_DATE, CURRENT_DATE,
       '{"JKH.N": 145.50, "COMB.N": 98.20}'::jsonb, COALESCE(p.created_at, NOW())
FROM public.sandbox_portfolios p
ON CONFLICT (user_id, module) DO NOTHING;

-- Existing holdings belong to the CSE module (the column default already
-- set this; explicit for clarity). Any stray non-stock legacy holding would
-- violate the module CHECK, so it is normalised to cse as well.
UPDATE public.sandbox_holdings SET module = 'cse' WHERE module IS DISTINCT FROM 'cse';

-- Progress rows for everyone who already used the sandbox, and their CSE
-- module counts as unlocked (they used it before lessons existed).
INSERT INTO public.sandbox_progress (user_id)
SELECT user_id FROM public.sandbox_wallets
ON CONFLICT (user_id) DO NOTHING;

COMMENT ON TABLE public.sandbox_portfolios IS
  'DEPRECATED: replaced by sandbox_wallets (module = cse) in 20261012090000_sandbox_trainer. '
  'The app no longer reads or writes it. Drop in a later migration.';

-- ------------------------------------------------------------
-- 4. Row level security: SELECT own rows only. Writes go through RPCs.
-- ------------------------------------------------------------
ALTER TABLE public.sandbox_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sandbox_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sandbox_trades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sandbox_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sandbox_lesson_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sandbox_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sandbox_challenges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert own portfolio" ON public.sandbox_portfolios;
DROP POLICY IF EXISTS "Users can update own portfolio" ON public.sandbox_portfolios;
DROP POLICY IF EXISTS "Users can insert own holdings" ON public.sandbox_holdings;
DROP POLICY IF EXISTS "Users can update own holdings" ON public.sandbox_holdings;
DROP POLICY IF EXISTS "Users can delete own holdings" ON public.sandbox_holdings;

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['sandbox_wallets', 'sandbox_positions', 'sandbox_trades', 'sandbox_progress',
                           'sandbox_lesson_progress', 'sandbox_badges', 'sandbox_challenges'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS "Users can view own %1$s" ON public.%1$I', t);
    EXECUTE format('CREATE POLICY "Users can view own %1$s" ON public.%1$I FOR SELECT USING (auth.uid() = user_id)', t);
  END LOOP;
END $$;

-- Belt and braces: even if a permissive policy is added later by mistake,
-- clients can't write these tables directly.
REVOKE INSERT, UPDATE, DELETE ON public.sandbox_wallets, public.sandbox_holdings, public.sandbox_positions,
  public.sandbox_trades, public.sandbox_progress, public.sandbox_lesson_progress, public.sandbox_badges,
  public.sandbox_challenges, public.sandbox_portfolios FROM anon, authenticated;

-- ------------------------------------------------------------
-- 5. New users: profile only. Wallets are created when a module unlocks,
-- so "% since start" compares against 100,000 per unlocked module and a
-- user who never opens the trainer has no sandbox rows at all.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (new.id, new.raw_user_meta_data->>'full_name', new.email);
  RETURN NEW;
END;
$$;

-- ------------------------------------------------------------
-- 6. Helpers (not callable by clients)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._sandbox_uid()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE v UUID := auth.uid();
BEGIN
  IF v IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN v;
END;
$$;

-- XP needed for levels 1..10. Must match kSandboxLevelThresholds in
-- lib/core/sandbox/sandbox_config.dart.
CREATE OR REPLACE FUNCTION public._sandbox_level_for_xp(p_xp INT)
RETURNS INT
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT COUNT(*)::int FROM unnest(ARRAY[0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200]) t
  WHERE t <= GREATEST(p_xp, 0);
$$;

-- Adds XP, updates the daily streak, returns the progress as JSON plus
-- whether this call levelled the user up.
CREATE OR REPLACE FUNCTION public._sandbox_bump(p_uid UUID, p_xp INT, p_counts_for_streak BOOLEAN)
RETURNS JSONB
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  r public.sandbox_progress;
  v_old_level INT;
BEGIN
  INSERT INTO public.sandbox_progress (user_id) VALUES (p_uid) ON CONFLICT (user_id) DO NOTHING;
  SELECT * INTO r FROM public.sandbox_progress WHERE user_id = p_uid FOR UPDATE;
  v_old_level := r.level;
  r.xp := r.xp + GREATEST(p_xp, 0);
  r.level := public._sandbox_level_for_xp(r.xp);
  IF p_counts_for_streak THEN
    IF r.last_active_date IS NULL OR r.last_active_date < CURRENT_DATE - 1 THEN
      r.streak_count := 1;
    ELSIF r.last_active_date = CURRENT_DATE - 1 THEN
      r.streak_count := r.streak_count + 1;
    END IF;
    r.last_active_date := CURRENT_DATE;
    r.best_streak := GREATEST(r.best_streak, r.streak_count);
  END IF;
  UPDATE public.sandbox_progress SET
    xp = r.xp, level = r.level, streak_count = r.streak_count, best_streak = r.best_streak,
    last_active_date = r.last_active_date, updated_at = NOW()
  WHERE user_id = p_uid;
  RETURN to_jsonb(r) || jsonb_build_object('xp_gained', GREATEST(p_xp, 0), 'leveled_up', r.level > v_old_level);
END;
$$;

CREATE OR REPLACE FUNCTION public._sandbox_wallet_for_update(p_uid UUID, p_module TEXT)
RETURNS public.sandbox_wallets
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE w public.sandbox_wallets;
BEGIN
  SELECT * INTO w FROM public.sandbox_wallets WHERE user_id = p_uid AND module = p_module FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'module_locked'; END IF;
  RETURN w;
END;
$$;

-- ------------------------------------------------------------
-- 7. Client RPCs. Errors are raised with a short code as the message
-- (e.g. 'insufficient_balance'); the app maps codes to friendly text.
-- ------------------------------------------------------------

-- Creates the module wallet the first time (after the module's first quiz
-- is passed). Idempotent: later calls only fill in missing price anchors.
CREATE OR REPLACE FUNCTION public.sandbox_unlock_module(p_module TEXT, p_anchors JSONB DEFAULT '{}'::jsonb)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._sandbox_uid();
  w public.sandbox_wallets;
BEGIN
  IF p_module NOT IN ('cse', 'fd', 'gold', 'trading', 'gov_securities') THEN RAISE EXCEPTION 'invalid_module'; END IF;
  IF p_anchors IS NULL OR jsonb_typeof(p_anchors) <> 'object' THEN p_anchors := '{}'::jsonb; END IF;

  SELECT * INTO w FROM public.sandbox_wallets WHERE user_id = v_uid AND module = p_module FOR UPDATE;
  IF NOT FOUND THEN
    IF NOT EXISTS (SELECT 1 FROM public.sandbox_lesson_progress
                   WHERE user_id = v_uid AND module = p_module AND completed_at IS NOT NULL) THEN
      RAISE EXCEPTION 'lesson_required';
    END IF;
    INSERT INTO public.sandbox_progress (user_id) VALUES (v_uid) ON CONFLICT (user_id) DO NOTHING;
    INSERT INTO public.sandbox_wallets (user_id, module, price_anchors)
    VALUES (v_uid, p_module, p_anchors)
    RETURNING * INTO w;
  ELSE
    -- Existing anchors win, so prices never jump for a running wallet.
    UPDATE public.sandbox_wallets SET price_anchors = p_anchors || price_anchors, updated_at = NOW()
    WHERE id = w.id RETURNING * INTO w;
  END IF;
  RETURN to_jsonb(w);
END;
$$;

-- Buy / sell (cse, gold, trading) and short / cover (trading, level 5+).
CREATE OR REPLACE FUNCTION public.sandbox_trade(
  p_module TEXT,
  p_symbol TEXT,
  p_name TEXT,
  p_instrument_type TEXT,
  p_side TEXT,
  p_quantity NUMERIC,
  p_price NUMERIC,
  p_fee NUMERIC DEFAULT 0,
  p_stop_loss NUMERIC DEFAULT NULL,
  p_take_profit NUMERIC DEFAULT NULL,
  p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._sandbox_uid();
  w public.sandbox_wallets;
  h public.sandbox_holdings;
  v_gross NUMERIC;
  v_cash NUMERIC;
  v_pnl NUMERIC := NULL;
  v_fee_share NUMERIC;
  v_level INT;
  v_trade_id UUID;
  v_sim DATE;
BEGIN
  IF p_module NOT IN ('cse', 'gold', 'trading') THEN RAISE EXCEPTION 'invalid_module'; END IF;
  IF p_side NOT IN ('buy', 'sell', 'short', 'cover') THEN RAISE EXCEPTION 'invalid_side'; END IF;
  IF p_quantity IS NULL OR p_quantity <= 0 THEN RAISE EXCEPTION 'invalid_quantity'; END IF;
  IF p_module = 'cse' AND p_quantity <> trunc(p_quantity) THEN RAISE EXCEPTION 'whole_shares_only'; END IF;
  IF p_price IS NULL OR p_price <= 0 THEN RAISE EXCEPTION 'invalid_price'; END IF;
  p_fee := COALESCE(p_fee, 0);
  v_gross := round(p_price * p_quantity, 2);
  -- Fees are client-computed (see header); cap them so a bad client can't
  -- turn a fee into a hidden withdrawal or deposit.
  IF p_fee < 0 OR p_fee > v_gross * 0.25 + 100 THEN RAISE EXCEPTION 'invalid_fee'; END IF;
  IF (p_stop_loss IS NOT NULL AND p_stop_loss <= 0) OR (p_take_profit IS NOT NULL AND p_take_profit <= 0) THEN
    RAISE EXCEPTION 'invalid_risk_levels';
  END IF;
  IF p_side IN ('short', 'cover') THEN
    IF p_module <> 'trading' THEN RAISE EXCEPTION 'short_not_allowed'; END IF;
    SELECT level INTO v_level FROM public.sandbox_progress WHERE user_id = v_uid;
    IF p_side = 'short' AND COALESCE(v_level, 1) < 5 THEN RAISE EXCEPTION 'short_locked'; END IF;
  END IF;

  w := public._sandbox_wallet_for_update(v_uid, p_module);
  v_sim := CASE WHEN p_module = 'trading' THEN CURRENT_DATE ELSE w.sim_date END;
  SELECT * INTO h FROM public.sandbox_holdings
  WHERE user_id = v_uid AND module = p_module AND symbol = p_symbol FOR UPDATE;

  IF p_side IN ('buy', 'short') THEN
    IF FOUND AND h.direction <> CASE WHEN p_side = 'buy' THEN 'long' ELSE 'short' END THEN
      RAISE EXCEPTION 'opposite_position_open';
    END IF;
    v_cash := -(v_gross + p_fee);
    IF w.balance + v_cash < 0 THEN RAISE EXCEPTION 'insufficient_balance'; END IF;
    IF FOUND THEN
      UPDATE public.sandbox_holdings SET
        average_price = (quantity * average_price + p_price * p_quantity) / (quantity + p_quantity),
        quantity = quantity + p_quantity,
        total_fees = total_fees + p_fee,
        stop_loss = COALESCE(p_stop_loss, stop_loss),
        take_profit = COALESCE(p_take_profit, take_profit),
        updated_at = NOW()
      WHERE id = h.id RETURNING * INTO h;
    ELSE
      INSERT INTO public.sandbox_holdings (user_id, module, symbol, name, instrument_type, direction,
        quantity, average_price, total_fees, stop_loss, take_profit, opened_sim_date)
      VALUES (v_uid, p_module, p_symbol, COALESCE(NULLIF(p_name, ''), p_symbol), lower(COALESCE(p_instrument_type, 'stock')),
        CASE WHEN p_side = 'buy' THEN 'long' ELSE 'short' END,
        p_quantity, p_price, p_fee, p_stop_loss, p_take_profit, v_sim)
      RETURNING * INTO h;
    END IF;
  ELSE
    IF NOT FOUND OR h.direction <> CASE WHEN p_side = 'sell' THEN 'long' ELSE 'short' END
       OR h.quantity < p_quantity THEN
      RAISE EXCEPTION 'insufficient_holdings';
    END IF;
    v_fee_share := round(h.total_fees * p_quantity / h.quantity, 2);
    IF p_side = 'sell' THEN
      v_cash := v_gross - p_fee;
      v_pnl := round((p_price - h.average_price) * p_quantity, 2) - p_fee - v_fee_share;
    ELSE
      -- Cover: the short's collateral (entry value) comes back, plus or
      -- minus the move. A short can lose at most its collateral.
      v_cash := GREATEST(round((2 * h.average_price - p_price) * p_quantity, 2) - p_fee, 0);
      v_pnl := v_cash - round(h.average_price * p_quantity, 2) - v_fee_share;
    END IF;
    IF v_cash < 0 THEN RAISE EXCEPTION 'invalid_fee'; END IF;
    IF h.quantity = p_quantity THEN
      DELETE FROM public.sandbox_holdings WHERE id = h.id;
      h := NULL;
    ELSE
      UPDATE public.sandbox_holdings SET
        quantity = quantity - p_quantity,
        total_fees = total_fees - v_fee_share,
        updated_at = NOW()
      WHERE id = h.id RETURNING * INTO h;
    END IF;
  END IF;

  UPDATE public.sandbox_wallets SET balance = balance + v_cash, updated_at = NOW()
  WHERE id = w.id RETURNING * INTO w;

  INSERT INTO public.sandbox_trades (user_id, module, symbol, side, quantity, price, fee, cash_delta,
    realised_pnl, note, sim_date, reset_batch)
  VALUES (v_uid, p_module, p_symbol, p_side, p_quantity, p_price, p_fee, v_cash, v_pnl,
    left(p_note, 200), v_sim, w.current_reset_batch)
  RETURNING id INTO v_trade_id;

  RETURN jsonb_build_object(
    'balance', w.balance,
    'wallet', to_jsonb(w),
    'holding', CASE WHEN h.id IS NULL THEN NULL ELSE to_jsonb(h) END,
    'trade_id', v_trade_id,
    'realised_pnl', v_pnl);
END;
$$;

-- Moves stop-loss / take-profit lines on an open trading position.
CREATE OR REPLACE FUNCTION public.sandbox_set_risk_levels(p_symbol TEXT, p_stop_loss NUMERIC, p_take_profit NUMERIC)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._sandbox_uid();
  h public.sandbox_holdings;
BEGIN
  IF (p_stop_loss IS NOT NULL AND p_stop_loss <= 0) OR (p_take_profit IS NOT NULL AND p_take_profit <= 0) THEN
    RAISE EXCEPTION 'invalid_risk_levels';
  END IF;
  UPDATE public.sandbox_holdings SET stop_loss = p_stop_loss, take_profit = p_take_profit, updated_at = NOW()
  WHERE user_id = v_uid AND module = 'trading' AND symbol = p_symbol
  RETURNING * INTO h;
  IF NOT FOUND THEN RAISE EXCEPTION 'insufficient_holdings'; END IF;
  RETURN to_jsonb(h);
END;
$$;

-- Opens an FD, T-bill or T-bond. Cash leaves the wallet now.
CREATE OR REPLACE FUNCTION public.sandbox_open_position(
  p_module TEXT,
  p_type TEXT,
  p_label TEXT,
  p_principal NUMERIC,
  p_cost NUMERIC,
  p_rate NUMERIC,
  p_payout_type TEXT,
  p_tenure_months INT DEFAULT NULL,
  p_tenure_days INT DEFAULT NULL,
  p_coupon_rate NUMERIC DEFAULT NULL,
  p_auto_renew BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._sandbox_uid();
  w public.sandbox_wallets;
  p public.sandbox_positions;
  v_maturity DATE;
  v_side TEXT;
BEGIN
  IF NOT ((p_module = 'fd' AND p_type = 'fd') OR (p_module = 'gov_securities' AND p_type IN ('tbill', 'tbond'))) THEN
    RAISE EXCEPTION 'invalid_position_type';
  END IF;
  IF p_principal IS NULL OR p_principal <= 0 OR p_cost IS NULL OR p_cost <= 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  IF p_rate IS NULL OR p_rate < 0 OR p_rate > 50 THEN RAISE EXCEPTION 'invalid_rate'; END IF;

  w := public._sandbox_wallet_for_update(v_uid, p_module);

  IF p_type = 'fd' THEN
    IF p_tenure_months NOT IN (1, 3, 6, 12, 24) THEN RAISE EXCEPTION 'invalid_tenure'; END IF;
    IF p_payout_type NOT IN ('maturity', 'monthly') THEN RAISE EXCEPTION 'invalid_payout_type'; END IF;
    IF p_cost <> p_principal THEN RAISE EXCEPTION 'invalid_amount'; END IF;
    v_maturity := (w.sim_date + make_interval(months => p_tenure_months))::date;
    v_side := 'fd_open';
  ELSIF p_type = 'tbill' THEN
    IF p_tenure_days NOT IN (91, 182, 364) THEN RAISE EXCEPTION 'invalid_tenure'; END IF;
    -- Sold at a discount: you pay less than the face value.
    IF p_cost > p_principal THEN RAISE EXCEPTION 'invalid_amount'; END IF;
    p_payout_type := 'discount';
    v_maturity := w.sim_date + p_tenure_days;
    v_side := 'tbill_buy';
  ELSE
    IF p_tenure_months IS NULL OR p_tenure_months % 12 <> 0 OR p_tenure_months < 24 OR p_tenure_months > 240 THEN
      RAISE EXCEPTION 'invalid_tenure';
    END IF;
    IF p_coupon_rate IS NULL OR p_coupon_rate < 0 OR p_coupon_rate > 50 THEN RAISE EXCEPTION 'invalid_rate'; END IF;
    IF p_cost <> p_principal THEN RAISE EXCEPTION 'invalid_amount'; END IF; -- bought at face value
    p_payout_type := 'semi_annual';
    v_maturity := (w.sim_date + make_interval(months => p_tenure_months))::date;
    v_side := 'tbond_buy';
  END IF;

  IF w.balance < p_cost THEN RAISE EXCEPTION 'insufficient_balance'; END IF;

  UPDATE public.sandbox_wallets SET balance = balance - p_cost, updated_at = NOW()
  WHERE id = w.id RETURNING * INTO w;

  INSERT INTO public.sandbox_positions (user_id, module, type, label, principal, cost, rate, coupon_rate,
    payout_type, tenure_months, tenure_days, start_sim_date, maturity_sim_date, auto_renew, reset_batch)
  VALUES (v_uid, p_module, p_type, left(COALESCE(NULLIF(p_label, ''), p_type), 80), p_principal, p_cost, p_rate,
    p_coupon_rate, p_payout_type, p_tenure_months, p_tenure_days, w.sim_date, v_maturity,
    p_type = 'fd' AND COALESCE(p_auto_renew, FALSE), w.current_reset_batch)
  RETURNING * INTO p;

  INSERT INTO public.sandbox_trades (user_id, module, symbol, side, quantity, price, cash_delta, ref_id,
    sim_date, reset_batch)
  VALUES (v_uid, p_module, p.label, v_side, p_principal, p_cost / p_principal * 100, -p_cost, p.id,
    w.sim_date, w.current_reset_batch);

  RETURN jsonb_build_object('balance', w.balance, 'wallet', to_jsonb(w), 'position', to_jsonb(p));
END;
$$;

-- Breaks an FD early (with penalty) or sells a T-bond before maturity at
-- the current market price. p_amount is what the user receives.
CREATE OR REPLACE FUNCTION public.sandbox_close_position(p_position_id UUID, p_amount NUMERIC)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._sandbox_uid();
  w public.sandbox_wallets;
  p public.sandbox_positions;
  v_side TEXT;
  v_pnl NUMERIC;
BEGIN
  IF p_amount IS NULL OR p_amount < 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  SELECT * INTO p FROM public.sandbox_positions WHERE id = p_position_id AND user_id = v_uid;
  IF NOT FOUND THEN RAISE EXCEPTION 'position_not_found'; END IF;
  w := public._sandbox_wallet_for_update(v_uid, p.module);
  -- Re-read under the wallet lock so two closes can't both pay out.
  SELECT * INTO p FROM public.sandbox_positions WHERE id = p_position_id FOR UPDATE;
  IF p.status <> 'open' OR p.reset_batch <> w.current_reset_batch THEN RAISE EXCEPTION 'position_not_open'; END IF;
  IF p.type = 'tbill' THEN RAISE EXCEPTION 'hold_to_maturity'; END IF;
  IF p_amount > p.principal * 2 THEN RAISE EXCEPTION 'invalid_amount'; END IF;

  v_side := CASE WHEN p.type = 'fd' THEN 'fd_break' ELSE 'tbond_sell' END;
  v_pnl := round(p_amount + p.total_paid - p.cost, 2);

  UPDATE public.sandbox_positions SET status = 'closed_early', closed_amount = p_amount,
    closed_sim_date = w.sim_date, updated_at = NOW()
  WHERE id = p.id RETURNING * INTO p;
  UPDATE public.sandbox_wallets SET balance = balance + p_amount, updated_at = NOW()
  WHERE id = w.id RETURNING * INTO w;

  INSERT INTO public.sandbox_trades (user_id, module, symbol, side, quantity, price, cash_delta,
    realised_pnl, ref_id, sim_date, reset_batch)
  VALUES (v_uid, p.module, p.label, v_side, p.principal, p_amount / p.principal * 100, p_amount, v_pnl, p.id,
    w.sim_date, w.current_reset_batch);

  RETURN jsonb_build_object('balance', w.balance, 'wallet', to_jsonb(w), 'position', to_jsonb(p),
    'realised_pnl', v_pnl);
END;
$$;

-- Advances a module's sim clock and applies the payouts the client's
-- simulator computed for that window (interest, coupons, maturities,
-- dividends, FD auto-renewals), all in one transaction.
--
-- p_events: [{ "kind": "fd_interest"|"fd_mature"|"fd_renew"|"tbill_mature"|
--              "tbond_coupon"|"tbond_mature"|"dividend",
--              "position_id": uuid (positions) | "symbol": text (dividend),
--              "amount": number, "sim_date": "YYYY-MM-DD" }]
CREATE OR REPLACE FUNCTION public.sandbox_fast_forward(p_module TEXT, p_days INT, p_events JSONB DEFAULT '[]'::jsonb)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._sandbox_uid();
  w public.sandbox_wallets;
  p public.sandbox_positions;
  h public.sandbox_holdings;
  e JSONB;
  v_kind TEXT;
  v_amount NUMERIC;
  v_date DATE;
  v_new_date DATE;
  v_total NUMERIC := 0;
  v_applied INT := 0;
BEGIN
  IF p_module NOT IN ('cse', 'fd', 'gold', 'gov_securities') THEN RAISE EXCEPTION 'invalid_module'; END IF;
  IF p_days IS NULL OR p_days < 1 OR p_days > 366 THEN RAISE EXCEPTION 'invalid_days'; END IF;
  IF p_events IS NULL OR jsonb_typeof(p_events) <> 'array' THEN p_events := '[]'::jsonb; END IF;
  IF jsonb_array_length(p_events) > 2000 THEN RAISE EXCEPTION 'too_many_events'; END IF;

  w := public._sandbox_wallet_for_update(v_uid, p_module);
  v_new_date := w.sim_date + p_days;

  FOR e IN SELECT * FROM jsonb_array_elements(p_events) LOOP
    v_kind := e->>'kind';
    v_amount := round((e->>'amount')::numeric, 2);
    v_date := (e->>'sim_date')::date;
    IF v_amount IS NULL OR v_amount < 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
    IF v_date IS NULL OR v_date <= w.sim_date OR v_date > v_new_date THEN RAISE EXCEPTION 'invalid_event_date'; END IF;

    IF v_kind = 'dividend' THEN
      IF p_module <> 'cse' THEN RAISE EXCEPTION 'invalid_event'; END IF;
      SELECT * INTO h FROM public.sandbox_holdings
      WHERE user_id = v_uid AND module = 'cse' AND symbol = e->>'symbol';
      -- A single dividend can't exceed 20% of what the shares cost.
      IF NOT FOUND OR v_amount > h.quantity * h.average_price * 0.20 THEN RAISE EXCEPTION 'invalid_event'; END IF;
      INSERT INTO public.sandbox_trades (user_id, module, symbol, side, quantity, price, cash_delta, sim_date, reset_batch)
      VALUES (v_uid, 'cse', h.symbol, 'dividend', h.quantity, v_amount / h.quantity, v_amount, v_date, w.current_reset_batch);
    ELSE
      SELECT * INTO p FROM public.sandbox_positions
      WHERE id = (e->>'position_id')::uuid AND user_id = v_uid AND module = p_module FOR UPDATE;
      IF NOT FOUND OR p.status <> 'open' OR p.reset_batch <> w.current_reset_batch THEN
        RAISE EXCEPTION 'position_not_open';
      END IF;
      IF v_amount > p.principal * 2 THEN RAISE EXCEPTION 'invalid_amount'; END IF;

      IF v_kind IN ('fd_interest', 'tbond_coupon') THEN
        IF (v_kind = 'fd_interest') <> (p.type = 'fd') OR (v_kind = 'tbond_coupon') <> (p.type = 'tbond') THEN
          RAISE EXCEPTION 'invalid_event';
        END IF;
        UPDATE public.sandbox_positions SET total_paid = total_paid + v_amount, payouts_count = payouts_count + 1,
          last_payout_sim_date = v_date, updated_at = NOW() WHERE id = p.id;
      ELSIF v_kind IN ('fd_mature', 'tbill_mature', 'tbond_mature') THEN
        IF v_kind <> p.type || '_mature' THEN RAISE EXCEPTION 'invalid_event'; END IF;
        IF v_date <> p.maturity_sim_date THEN RAISE EXCEPTION 'invalid_event_date'; END IF;
        UPDATE public.sandbox_positions SET status = 'matured', closed_amount = v_amount, closed_sim_date = v_date,
          updated_at = NOW() WHERE id = p.id;
      ELSIF v_kind = 'fd_renew' THEN
        -- Auto-renew: the interest (after tax) joins the principal and a
        -- new term starts on the maturity date — this is compounding.
        IF p.type <> 'fd' OR NOT p.auto_renew OR v_date <> p.maturity_sim_date THEN RAISE EXCEPTION 'invalid_event'; END IF;
        UPDATE public.sandbox_positions SET
          principal = principal + v_amount,  -- not total_paid: the interest stays invested
          start_sim_date = v_date,
          maturity_sim_date = (v_date + make_interval(months => tenure_months))::date,
          renew_count = renew_count + 1,
          last_payout_sim_date = v_date,
          updated_at = NOW()
        WHERE id = p.id;
      ELSE
        RAISE EXCEPTION 'invalid_event';
      END IF;

      INSERT INTO public.sandbox_trades (user_id, module, symbol, side, quantity, price, cash_delta, ref_id,
        sim_date, reset_batch)
      VALUES (v_uid, p_module, p.label, v_kind, p.principal, v_amount / p.principal * 100,
        CASE WHEN v_kind = 'fd_renew' THEN 0 ELSE v_amount END, p.id, v_date, w.current_reset_batch);
    END IF;

    IF v_kind <> 'fd_renew' THEN v_total := v_total + v_amount; END IF;
    v_applied := v_applied + 1;
  END LOOP;

  UPDATE public.sandbox_wallets SET balance = balance + v_total, sim_date = v_new_date, updated_at = NOW()
  WHERE id = w.id RETURNING * INTO w;

  RETURN jsonb_build_object('balance', w.balance, 'wallet', to_jsonb(w), 'applied', v_applied, 'paid', v_total);
END;
$$;

-- Up-or-Down mini-game. The stake leaves the wallet when the round starts;
-- a win pays a fixed 1.8x (less than 2x: the built-in house edge).
CREATE OR REPLACE FUNCTION public.sandbox_updown_stake(p_symbol TEXT, p_stake NUMERIC, p_note TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._sandbox_uid();
  w public.sandbox_wallets;
  v_id UUID;
BEGIN
  IF p_stake IS NULL OR p_stake <= 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  w := public._sandbox_wallet_for_update(v_uid, 'trading');
  IF w.balance < p_stake THEN RAISE EXCEPTION 'insufficient_balance'; END IF;
  UPDATE public.sandbox_wallets SET balance = balance - p_stake, updated_at = NOW()
  WHERE id = w.id RETURNING * INTO w;
  INSERT INTO public.sandbox_trades (user_id, module, symbol, side, quantity, price, cash_delta, note, sim_date, reset_batch)
  VALUES (v_uid, 'trading', p_symbol, 'updown_stake', p_stake, 1, -p_stake, left(p_note, 200), CURRENT_DATE, w.current_reset_batch)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('balance', w.balance, 'wallet', to_jsonb(w), 'stake_id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.sandbox_updown_settle(p_stake_id UUID, p_won BOOLEAN)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._sandbox_uid();
  w public.sandbox_wallets;
  s public.sandbox_trades;
  v_payout NUMERIC;
BEGIN
  w := public._sandbox_wallet_for_update(v_uid, 'trading');
  SELECT * INTO s FROM public.sandbox_trades
  WHERE id = p_stake_id AND user_id = v_uid AND side = 'updown_stake';
  IF NOT FOUND OR s.reset_batch <> w.current_reset_batch THEN RAISE EXCEPTION 'round_not_found'; END IF;
  IF EXISTS (SELECT 1 FROM public.sandbox_trades WHERE ref_id = p_stake_id AND side = 'updown_payout') THEN
    RAISE EXCEPTION 'round_already_settled';
  END IF;
  v_payout := CASE WHEN p_won THEN round(s.quantity * 1.8, 2) ELSE 0 END;
  UPDATE public.sandbox_wallets SET balance = balance + v_payout, updated_at = NOW()
  WHERE id = w.id RETURNING * INTO w;
  -- A lost round still gets a (zero-cash) row so the round is closed.
  INSERT INTO public.sandbox_trades (user_id, module, symbol, side, quantity, price, cash_delta, realised_pnl,
    ref_id, sim_date, reset_batch)
  VALUES (v_uid, 'trading', s.symbol, 'updown_payout', s.quantity, CASE WHEN p_won THEN 1.8 ELSE 0 END,
    v_payout, v_payout - s.quantity, p_stake_id, CURRENT_DATE, w.current_reset_batch);
  RETURN jsonb_build_object('balance', w.balance, 'wallet', to_jsonb(w), 'payout', v_payout);
END;
$$;

-- Reset one module (p_module) or everything (p_module NULL). Trades and
-- positions are archived under the old reset batch, never deleted. XP,
-- badges and lessons are kept unless p_reset_learning (everything only).
CREATE OR REPLACE FUNCTION public.sandbox_reset(p_module TEXT DEFAULT NULL, p_reset_learning BOOLEAN DEFAULT FALSE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._sandbox_uid();
  w public.sandbox_wallets;
  v_count INT := 0;
BEGIN
  IF p_module IS NOT NULL AND p_module NOT IN ('cse', 'fd', 'gold', 'trading', 'gov_securities') THEN
    RAISE EXCEPTION 'invalid_module';
  END IF;
  IF p_module IS NOT NULL AND p_reset_learning THEN RAISE EXCEPTION 'invalid_reset'; END IF;

  FOR w IN SELECT * FROM public.sandbox_wallets
           WHERE user_id = v_uid AND (p_module IS NULL OR module = p_module) FOR UPDATE LOOP
    UPDATE public.sandbox_positions SET status = 'archived', updated_at = NOW()
    WHERE user_id = v_uid AND module = w.module AND status = 'open';
    DELETE FROM public.sandbox_holdings WHERE user_id = v_uid AND module = w.module;
    UPDATE public.sandbox_wallets SET
      balance = 100000.00,
      sim_date = CURRENT_DATE,
      start_date = CURRENT_DATE,
      price_anchors = '{}'::jsonb,     -- re-anchored to today's real data by the app
      reset_count = reset_count + 1,
      current_reset_batch = gen_random_uuid(),
      updated_at = NOW()
    WHERE id = w.id;
    v_count := v_count + 1;
  END LOOP;

  IF p_module IS NULL AND p_reset_learning THEN
    DELETE FROM public.sandbox_lesson_progress WHERE user_id = v_uid;
    DELETE FROM public.sandbox_challenges WHERE user_id = v_uid;
    DELETE FROM public.sandbox_badges WHERE user_id = v_uid;
    UPDATE public.sandbox_progress SET xp = 0, level = 1, streak_count = 0, habit_xp_today = 0, updated_at = NOW()
    WHERE user_id = v_uid;
  END IF;

  RETURN jsonb_build_object('wallets_reset', v_count, 'learning_reset', p_module IS NULL AND p_reset_learning);
END;
$$;

-- Lesson cards finished (10 XP, first time only).
CREATE OR REPLACE FUNCTION public.sandbox_lesson_read(p_module TEXT, p_lesson_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._sandbox_uid();
  v_first BOOLEAN;
BEGIN
  IF p_module NOT IN ('cse', 'fd', 'gold', 'trading', 'gov_securities') THEN RAISE EXCEPTION 'invalid_module'; END IF;
  INSERT INTO public.sandbox_lesson_progress (user_id, module, lesson_id, read_at)
  VALUES (v_uid, p_module, p_lesson_id, NOW())
  ON CONFLICT (user_id, module, lesson_id) DO NOTHING;
  v_first := FOUND;
  IF NOT v_first THEN
    UPDATE public.sandbox_lesson_progress SET read_at = COALESCE(read_at, NOW())
    WHERE user_id = v_uid AND module = p_module AND lesson_id = p_lesson_id AND read_at IS NULL;
    v_first := FOUND;
  END IF;
  RETURN public._sandbox_bump(v_uid, CASE WHEN v_first THEN 10 ELSE 0 END, TRUE);
END;
$$;

-- Quiz result. 70% passes. 20 XP on the first pass, +10 for a first 100%.
CREATE OR REPLACE FUNCTION public.sandbox_submit_quiz(p_module TEXT, p_lesson_id TEXT, p_score NUMERIC)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._sandbox_uid();
  r public.sandbox_lesson_progress;
  v_passed BOOLEAN := p_score >= 70;
  v_xp INT := 0;
BEGIN
  IF p_module NOT IN ('cse', 'fd', 'gold', 'trading', 'gov_securities') THEN RAISE EXCEPTION 'invalid_module'; END IF;
  IF p_score IS NULL OR p_score < 0 OR p_score > 100 THEN RAISE EXCEPTION 'invalid_score'; END IF;
  INSERT INTO public.sandbox_lesson_progress (user_id, module, lesson_id, read_at)
  VALUES (v_uid, p_module, p_lesson_id, NOW())
  ON CONFLICT (user_id, module, lesson_id) DO NOTHING;
  SELECT * INTO r FROM public.sandbox_lesson_progress
  WHERE user_id = v_uid AND module = p_module AND lesson_id = p_lesson_id FOR UPDATE;

  IF v_passed AND r.completed_at IS NULL THEN v_xp := v_xp + 20; END IF;
  IF p_score = 100 AND COALESCE(r.quiz_score, 0) < 100 THEN v_xp := v_xp + 10; END IF;

  UPDATE public.sandbox_lesson_progress SET
    quiz_score = GREATEST(COALESCE(quiz_score, 0), p_score),
    attempts = attempts + 1,
    completed_at = CASE WHEN v_passed THEN COALESCE(completed_at, NOW()) ELSE completed_at END
  WHERE user_id = v_uid AND module = p_module AND lesson_id = p_lesson_id;

  RETURN public._sandbox_bump(v_uid, v_xp, TRUE) || jsonb_build_object('passed', v_passed);
END;
$$;

-- Challenge progress only goes up. Completing one is worth 50 XP.
CREATE OR REPLACE FUNCTION public.sandbox_challenge_progress(p_challenge_id TEXT, p_progress INT, p_target INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._sandbox_uid();
  r public.sandbox_challenges;
  v_done BOOLEAN := FALSE;
BEGIN
  IF p_progress IS NULL OR p_progress < 0 OR p_target IS NULL OR p_target < 1 OR p_target > 1000 THEN
    RAISE EXCEPTION 'invalid_progress';
  END IF;
  INSERT INTO public.sandbox_challenges (user_id, challenge_id, progress, target)
  VALUES (v_uid, p_challenge_id, 0, p_target)
  ON CONFLICT (user_id, challenge_id) DO NOTHING;
  SELECT * INTO r FROM public.sandbox_challenges WHERE user_id = v_uid AND challenge_id = p_challenge_id FOR UPDATE;
  IF r.completed_at IS NULL AND p_progress >= p_target THEN v_done := TRUE; END IF;
  UPDATE public.sandbox_challenges SET
    progress = LEAST(GREATEST(progress, p_progress), p_target),
    target = p_target,
    completed_at = CASE WHEN v_done THEN NOW() ELSE completed_at END,
    updated_at = NOW()
  WHERE user_id = v_uid AND challenge_id = p_challenge_id
  RETURNING * INTO r;
  RETURN public._sandbox_bump(v_uid, CASE WHEN v_done THEN 50 ELSE 0 END, v_done)
    || jsonb_build_object('challenge', to_jsonb(r), 'completed_now', v_done);
END;
$$;

CREATE OR REPLACE FUNCTION public.sandbox_award_badge(p_badge_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._sandbox_uid();
  v_new BOOLEAN;
BEGIN
  IF p_badge_id IS NULL OR length(p_badge_id) NOT BETWEEN 1 AND 64 THEN RAISE EXCEPTION 'invalid_badge'; END IF;
  INSERT INTO public.sandbox_badges (user_id, badge_id) VALUES (v_uid, p_badge_id)
  ON CONFLICT (user_id, badge_id) DO NOTHING;
  v_new := FOUND;
  RETURN public._sandbox_bump(v_uid, CASE WHEN v_new THEN 25 ELSE 0 END, FALSE) || jsonb_build_object('new_badge', v_new);
END;
$$;

-- XP for good habits only (never for trading volume). Max 25 per award,
-- 100 per day.
CREATE OR REPLACE FUNCTION public.sandbox_award_habit_xp(p_reason TEXT, p_amount INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._sandbox_uid();
  r public.sandbox_progress;
  v_grant INT;
BEGIN
  IF p_reason NOT IN ('stop_loss_used', 'low_risk_trade', 'respected_loss_limit', 'took_break', 'read_stats') THEN
    RAISE EXCEPTION 'invalid_reason';
  END IF;
  IF p_amount IS NULL OR p_amount < 1 OR p_amount > 25 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  INSERT INTO public.sandbox_progress (user_id) VALUES (v_uid) ON CONFLICT (user_id) DO NOTHING;
  SELECT * INTO r FROM public.sandbox_progress WHERE user_id = v_uid FOR UPDATE;
  IF r.habit_xp_date IS DISTINCT FROM CURRENT_DATE THEN r.habit_xp_today := 0; END IF;
  v_grant := LEAST(p_amount, GREATEST(100 - r.habit_xp_today, 0));
  UPDATE public.sandbox_progress SET habit_xp_today = r.habit_xp_today + v_grant, habit_xp_date = CURRENT_DATE
  WHERE user_id = v_uid;
  RETURN public._sandbox_bump(v_uid, v_grant, FALSE);
END;
$$;

-- ------------------------------------------------------------
-- 8. Function privileges: helpers are internal; RPCs are for signed-in
-- users only.
-- ------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public._sandbox_uid() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._sandbox_level_for_xp(INT) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._sandbox_bump(UUID, INT, BOOLEAN) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._sandbox_wallet_for_update(UUID, TEXT) FROM PUBLIC, anon, authenticated;

DO $$
DECLARE f TEXT;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.sandbox_unlock_module(TEXT, JSONB)',
    'public.sandbox_trade(TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, TEXT)',
    'public.sandbox_set_risk_levels(TEXT, NUMERIC, NUMERIC)',
    'public.sandbox_open_position(TEXT, TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC, TEXT, INT, INT, NUMERIC, BOOLEAN)',
    'public.sandbox_close_position(UUID, NUMERIC)',
    'public.sandbox_fast_forward(TEXT, INT, JSONB)',
    'public.sandbox_updown_stake(TEXT, NUMERIC, TEXT)',
    'public.sandbox_updown_settle(UUID, BOOLEAN)',
    'public.sandbox_reset(TEXT, BOOLEAN)',
    'public.sandbox_lesson_read(TEXT, TEXT)',
    'public.sandbox_submit_quiz(TEXT, TEXT, NUMERIC)',
    'public.sandbox_challenge_progress(TEXT, INT, INT)',
    'public.sandbox_award_badge(TEXT)',
    'public.sandbox_award_habit_xp(TEXT, INT)'
  ] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f);
  END LOOP;
END $$;

-- ============================================================
-- COMMUNITY & GROUP INVESTMENTS (identical to supabase/migrations/20261013090000_community_groups.sql)
-- ============================================================

-- ============================================================
-- COMMUNITY & GROUP INVESTMENTS
--
-- Mobile SAP records and coordinates. It never holds, collects, transfers
-- or invests real money: members pay each other (or the treasurer)
-- outside the app, the payer marks a payment as paid, and the receiver or
-- treasurer confirms it here. There is no wallet, no payment gateway and
-- no referral reward anywhere in this schema.
--
-- Access model
--  * RLS is on for every table. Clients only SELECT (plus marking their
--    own notifications read). Every state change goes through a SECURITY
--    DEFINER function below that checks role and state.
--  * community_profiles: column grants hide `phone` and the exact
--    `max_contribution`; search and profile reads go through RPCs that
--    apply the visibility rules and show contributions as a bucket.
--  * Group content is readable only by active members (cg_is_member).
--    Non-members see a discoverable group's summary through
--    community_search_groups / community_group_summary.
--  * group_activity_log is append-only for everyone: no write policies,
--    privileges revoked, and a trigger that rejects UPDATE/DELETE.
--
-- Errors are raised with a short code as the message (e.g.
-- 'not_group_officer'); the app maps codes to friendly text, as the
-- sandbox RPCs do.
--
-- Depends only on public.profiles, public.expenses (base columns) and
-- the pg_cron extension.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;

-- ------------------------------------------------------------
-- 1. Profile additions: DOB for the 18+ check on group features.
-- Sign-up already asks for DOB; it is now stored. Existing users without
-- a DOB confirm their age once (community_confirm_age).
-- ------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS date_of_birth DATE,
  ADD COLUMN IF NOT EXISTS age_confirmed_at TIMESTAMPTZ;

-- ------------------------------------------------------------
-- 2. Config (single row). Phone verification is required to appear in
-- search only once Supabase phone OTP is configured; until then users
-- are shown as "Not verified".
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.community_config (
  id BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (id),
  require_phone_verification BOOLEAN NOT NULL DEFAULT FALSE
);
INSERT INTO public.community_config (id) VALUES (TRUE) ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 3. Tables
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.community_profiles (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  available_for_groups BOOLEAN NOT NULL DEFAULT FALSE,
  display_name TEXT NOT NULL CHECK (char_length(btrim(display_name)) BETWEEN 1 AND 60),
  phone TEXT CHECK (phone IS NULL OR phone ~ '^\+?[0-9 ]{9,16}$'),
  phone_visible_in_search BOOLEAN NOT NULL DEFAULT FALSE,
  -- Set only by the server from auth.users.phone_confirmed_at.
  phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
  photo_path TEXT,
  -- Stored exactly; everyone else only ever sees cg_contribution_label().
  max_contribution NUMERIC(14, 2) CHECK (max_contribution IS NULL OR max_contribution > 0),
  experience TEXT NOT NULL DEFAULT 'none' CHECK (experience IN ('none', 'some', 'experienced')),
  interests TEXT[] NOT NULL DEFAULT '{}'
    CHECK (interests <@ ARRAY['seettu', 'cse', 'fd', 'gold', 'gov_securities', 'business']::TEXT[]),
  district TEXT CHECK (district IS NULL OR district IN (
    'Ampara', 'Anuradhapura', 'Badulla', 'Batticaloa', 'Colombo', 'Galle', 'Gampaha',
    'Hambantota', 'Jaffna', 'Kalutara', 'Kandy', 'Kegalle', 'Kilinochchi', 'Kurunegala',
    'Mannar', 'Matale', 'Matara', 'Monaragala', 'Mullaitivu', 'Nuwara Eliya',
    'Polonnaruwa', 'Puttalam', 'Ratnapura', 'Trincomalee', 'Vavuniya')),
  bio TEXT CHECK (bio IS NULL OR char_length(bio) <= 200),
  explainer_seen_at TIMESTAMPTZ,
  last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS community_profiles_name_trgm
  ON public.community_profiles USING gin (display_name extensions.gin_trgm_ops);
CREATE INDEX IF NOT EXISTS community_profiles_available_idx
  ON public.community_profiles (last_active_at DESC) WHERE available_for_groups;
CREATE INDEX IF NOT EXISTS community_profiles_district_idx ON public.community_profiles (district);
CREATE INDEX IF NOT EXISTS community_profiles_interests_idx ON public.community_profiles USING gin (interests);

CREATE TABLE IF NOT EXISTS public.connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  addressee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
  message TEXT CHECK (message IS NULL OR char_length(message) <= 150),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  CHECK (requester_id <> addressee_id)
);
-- One row per pair, whichever way round; a re-request reuses it.
CREATE UNIQUE INDEX IF NOT EXISTS connections_pair_uidx
  ON public.connections (LEAST(requester_id, addressee_id), GREATEST(requester_id, addressee_id));
CREATE INDEX IF NOT EXISTS connections_requester_idx ON public.connections (requester_id, status);
CREATE INDEX IF NOT EXISTS connections_addressee_idx ON public.connections (addressee_id, status);

CREATE TABLE IF NOT EXISTS public.blocks (
  blocker_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);
CREATE INDEX IF NOT EXISTS blocks_blocked_idx ON public.blocks (blocked_id);
-- Nothing in this feature is hard-deleted: unblocking timestamps the row.
ALTER TABLE public.blocks ADD COLUMN IF NOT EXISTS unblocked_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS public.groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN ('seettu', 'investment')),
  name TEXT NOT NULL CHECK (char_length(btrim(name)) BETWEEN 3 AND 60),
  description TEXT CHECK (description IS NULL OR char_length(description) <= 1000),
  photo_path TEXT,
  district TEXT CHECK (district IS NULL OR district IN (
    'Ampara', 'Anuradhapura', 'Badulla', 'Batticaloa', 'Colombo', 'Galle', 'Gampaha',
    'Hambantota', 'Jaffna', 'Kalutara', 'Kandy', 'Kegalle', 'Kilinochchi', 'Kurunegala',
    'Mannar', 'Matale', 'Matara', 'Monaragala', 'Mullaitivu', 'Nuwara Eliya',
    'Polonnaruwa', 'Puttalam', 'Ratnapura', 'Trincomalee', 'Vavuniya')),
  max_members INT NOT NULL CHECK (max_members BETWEEN 2 AND 50),
  discoverable BOOLEAN NOT NULL DEFAULT TRUE,
  join_approval TEXT NOT NULL DEFAULT 'leader' CHECK (join_approval IN ('leader', 'vote')),
  -- Free-text rules. The standard record-keeping notice is shown by the app
  -- above these on every group, so it can't be edited away.
  rules TEXT NOT NULL DEFAULT '' CHECK (char_length(rules) <= 4000),
  voting_method TEXT NOT NULL DEFAULT 'one_member_one_vote'
    CHECK (voting_method IN ('one_member_one_vote', 'weighted')),
  quorum_pct INT NOT NULL DEFAULT 50 CHECK (quorum_pct BETWEEN 1 AND 100),
  -- Default pass rule for ordinary votes. Leader change, rule changes and
  -- voting-method changes always need two thirds (see _cg_open_vote).
  pass_threshold TEXT NOT NULL DEFAULT 'majority' CHECK (pass_threshold IN ('majority', 'two_thirds')),
  vote_hours INT NOT NULL DEFAULT 48 CHECK (vote_hours BETWEEN 12 AND 336),
  status TEXT NOT NULL DEFAULT 'forming' CHECK (status IN ('forming', 'active', 'closed')),
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closed_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS groups_type_name_uidx ON public.groups (type, lower(btrim(name)));
CREATE INDEX IF NOT EXISTS groups_name_trgm ON public.groups USING gin (name extensions.gin_trgm_ops);
CREATE INDEX IF NOT EXISTS groups_discover_idx ON public.groups (type, status) WHERE discoverable;
CREATE INDEX IF NOT EXISTS groups_created_by_idx ON public.groups (created_by);

CREATE TABLE IF NOT EXISTS public.group_members (
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('leader', 'co_leader', 'treasurer', 'member')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'left', 'removed')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  rules_accepted_at TIMESTAMPTZ NOT NULL,
  -- Seettu: member confirmed the rules and the payout-order method.
  seettu_confirmed_at TIMESTAMPTZ,
  -- Seettu with an agreed order: this member's round number.
  payout_position INT CHECK (payout_position IS NULL OR payout_position >= 1),
  chat_muted BOOLEAN NOT NULL DEFAULT FALSE,
  last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Expenditure integration (opt-in). No FK: recurring_expenses lives in
  -- the expenditure migration and may not exist yet.
  recurring_expense_id UUID,
  log_payments_as_expenses BOOLEAN NOT NULL DEFAULT FALSE,
  left_at TIMESTAMPTZ,
  removal_reason TEXT CHECK (removal_reason IS NULL OR char_length(removal_reason) <= 500),
  PRIMARY KEY (group_id, user_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS group_members_one_leader
  ON public.group_members (group_id) WHERE role = 'leader' AND status = 'active';
CREATE INDEX IF NOT EXISTS group_members_user_idx ON public.group_members (user_id, status);

CREATE TABLE IF NOT EXISTS public.group_join_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message TEXT CHECK (message IS NULL OR char_length(message) <= 300),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'declined', 'cancelled')),
  vote_id UUID,
  rules_accepted_at TIMESTAMPTZ NOT NULL,
  decided_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  decided_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS group_join_requests_pending_uidx
  ON public.group_join_requests (group_id, user_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS group_join_requests_user_idx ON public.group_join_requests (user_id, status);
CREATE INDEX IF NOT EXISTS group_join_requests_group_idx ON public.group_join_requests (group_id, status);

CREATE TABLE IF NOT EXISTS public.group_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  inviter_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  invitee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  responded_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS group_invites_pending_uidx
  ON public.group_invites (group_id, invitee_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS group_invites_invitee_idx ON public.group_invites (invitee_id, status);
CREATE INDEX IF NOT EXISTS group_invites_inviter_idx ON public.group_invites (inviter_id);

CREATE TABLE IF NOT EXISTS public.group_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  body TEXT CHECK (body IS NULL OR char_length(body) <= 2000),
  image_path TEXT,
  reply_to UUID REFERENCES public.group_messages(id) ON DELETE SET NULL,
  is_system BOOLEAN NOT NULL DEFAULT FALSE,
  is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS group_messages_group_idx ON public.group_messages (group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS group_messages_sender_idx ON public.group_messages (sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS group_messages_reply_idx ON public.group_messages (reply_to);
CREATE INDEX IF NOT EXISTS group_messages_pinned_idx ON public.group_messages (group_id) WHERE is_pinned;

CREATE TABLE IF NOT EXISTS public.polls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  question TEXT NOT NULL CHECK (char_length(btrim(question)) BETWEEN 3 AND 300),
  multiple_choice BOOLEAN NOT NULL DEFAULT FALSE,
  anonymous BOOLEAN NOT NULL DEFAULT FALSE,
  deadline TIMESTAMPTZ NOT NULL,
  closed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS polls_group_idx ON public.polls (group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS polls_open_idx ON public.polls (deadline) WHERE closed_at IS NULL;

CREATE TABLE IF NOT EXISTS public.poll_options (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  label TEXT NOT NULL CHECK (char_length(btrim(label)) BETWEEN 1 AND 100),
  position INT NOT NULL,
  -- Kept by poll_vote(), so anonymous polls can show live counts.
  vote_count INT NOT NULL DEFAULT 0,
  UNIQUE (poll_id, position)
);
CREATE INDEX IF NOT EXISTS poll_options_group_idx ON public.poll_options (group_id);

CREATE TABLE IF NOT EXISTS public.poll_votes (
  poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  option_id UUID NOT NULL REFERENCES public.poll_options(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (poll_id, option_id, user_id)
);
-- Changing a vote retracts the old choice instead of deleting it.
ALTER TABLE public.poll_votes ADD COLUMN IF NOT EXISTS retracted_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS poll_votes_user_idx ON public.poll_votes (user_id);
CREATE INDEX IF NOT EXISTS poll_votes_option_idx ON public.poll_votes (option_id);
CREATE INDEX IF NOT EXISTS poll_votes_group_idx ON public.poll_votes (group_id);

CREATE TABLE IF NOT EXISTS public.group_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('proposal', 'leader_change', 'rule_change', 'voting_method',
    'member_removal', 'join_request', 'exit', 'close_group', 'custom')),
  title TEXT NOT NULL CHECK (char_length(btrim(title)) BETWEEN 3 AND 200),
  description TEXT CHECK (description IS NULL OR char_length(description) <= 2000),
  -- What the vote acts on, e.g. {"new_leader": uuid}, {"rules": "..."},
  -- {"proposal_id": uuid}, {"request_id": uuid, "user_id": uuid}.
  subject JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  method TEXT NOT NULL CHECK (method IN ('one_member_one_vote', 'weighted')),
  quorum_pct INT NOT NULL CHECK (quorum_pct BETWEEN 1 AND 100),
  threshold TEXT NOT NULL CHECK (threshold IN ('majority', 'two_thirds')),
  -- 'cast': share of yes+no. 'eligible': share of all eligible members.
  threshold_base TEXT NOT NULL CHECK (threshold_base IN ('cast', 'eligible')),
  deadline TIMESTAMPTZ NOT NULL,
  reminder_sent BOOLEAN NOT NULL DEFAULT FALSE,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'passed', 'failed', 'cancelled')),
  yes_weight NUMERIC(16, 2),
  no_weight NUMERIC(16, 2),
  abstain_count INT,
  ballot_count INT,
  eligible_count INT,
  eligible_weight NUMERIC(16, 2),
  result_note TEXT,
  closed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS group_votes_group_idx ON public.group_votes (group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS group_votes_open_idx ON public.group_votes (deadline) WHERE status = 'open';
CREATE INDEX IF NOT EXISTS group_votes_created_by_idx ON public.group_votes (created_by);

CREATE TABLE IF NOT EXISTS public.group_vote_ballots (
  vote_id UUID NOT NULL REFERENCES public.group_votes(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  choice TEXT NOT NULL CHECK (choice IN ('yes', 'no', 'abstain')),
  -- Filled in when the vote closes (weighted voting uses confirmed
  -- contributions at that moment).
  weight NUMERIC(16, 2),
  cast_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (vote_id, user_id)
);
CREATE INDEX IF NOT EXISTS group_vote_ballots_user_idx ON public.group_vote_ballots (user_id);
CREATE INDEX IF NOT EXISTS group_vote_ballots_group_idx ON public.group_vote_ballots (group_id);

ALTER TABLE public.group_join_requests DROP CONSTRAINT IF EXISTS group_join_requests_vote_fk;
ALTER TABLE public.group_join_requests ADD CONSTRAINT group_join_requests_vote_fk
  FOREIGN KEY (vote_id) REFERENCES public.group_votes(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS group_join_requests_vote_idx ON public.group_join_requests (vote_id);

-- Seettu ------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.seettu_settings (
  group_id UUID PRIMARY KEY REFERENCES public.groups(id) ON DELETE CASCADE,
  contribution NUMERIC(14, 2) NOT NULL CHECK (contribution > 0),
  frequency TEXT NOT NULL CHECK (frequency IN ('weekly', 'monthly')),
  start_date DATE NOT NULL,
  -- weekly: ISO day of week (1 = Monday … 7 = Sunday); monthly: 1–28.
  due_day INT NOT NULL,
  payout_method TEXT NOT NULL CHECK (payout_method IN ('agreed', 'random', 'bidding')),
  -- Random draw: all rounds at the start, or one round at a time.
  draw_mode TEXT NOT NULL DEFAULT 'all' CHECK (draw_mode IN ('all', 'each_round')),
  late_rule TEXT CHECK (late_rule IS NULL OR char_length(late_rule) <= 1000),
  -- Recorded only; nobody collects it through the app.
  late_fee NUMERIC(14, 2) CHECK (late_fee IS NULL OR late_fee >= 0),
  CHECK ((frequency = 'weekly' AND due_day BETWEEN 1 AND 7) OR (frequency = 'monthly' AND due_day BETWEEN 1 AND 28))
);

CREATE TABLE IF NOT EXISTS public.seettu_rounds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  round_no INT NOT NULL CHECK (round_no >= 1),
  due_date DATE NOT NULL,
  recipient_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  -- Auction seettu: the winning discount. pot = contribution × members − discount.
  discount NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
  pot NUMERIC(14, 2) NOT NULL CHECK (pot >= 0),
  status TEXT NOT NULL DEFAULT 'upcoming'
    CHECK (status IN ('upcoming', 'bidding', 'collecting', 'handed_over', 'completed')),
  drawn_at TIMESTAMPTZ,
  handed_over_at TIMESTAMPTZ,
  received_at TIMESTAMPTZ,
  UNIQUE (group_id, round_no)
);
CREATE INDEX IF NOT EXISTS seettu_rounds_recipient_idx ON public.seettu_rounds (recipient_id);
CREATE UNIQUE INDEX IF NOT EXISTS seettu_rounds_one_win_uidx
  ON public.seettu_rounds (group_id, recipient_id) WHERE recipient_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.seettu_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id UUID NOT NULL REFERENCES public.seettu_rounds(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  payer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  -- Credit from an auction discount, taken off this instalment.
  credit NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (credit >= 0),
  amount_due NUMERIC(14, 2) NOT NULL CHECK (amount_due >= 0),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'marked_paid', 'confirmed', 'late')),
  receipt_path TEXT,
  marked_at TIMESTAMPTZ,
  confirmed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  confirmed_at TIMESTAMPTZ,
  UNIQUE (round_id, payer_id)
);
CREATE INDEX IF NOT EXISTS seettu_payments_payer_idx ON public.seettu_payments (payer_id, status);
CREATE INDEX IF NOT EXISTS seettu_payments_group_idx ON public.seettu_payments (group_id);
CREATE INDEX IF NOT EXISTS seettu_payments_confirmed_by_idx ON public.seettu_payments (confirmed_by);

CREATE TABLE IF NOT EXISTS public.seettu_bids (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id UUID NOT NULL REFERENCES public.seettu_rounds(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  -- The discount this member accepts on the pot. Biggest discount wins
  -- (= lowest amount taken); ties go to the earlier bid.
  discount NUMERIC(14, 2) NOT NULL CHECK (discount >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (round_id, user_id)
);
CREATE INDEX IF NOT EXISTS seettu_bids_user_idx ON public.seettu_bids (user_id);
CREATE INDEX IF NOT EXISTS seettu_bids_group_idx ON public.seettu_bids (group_id);

-- Investment groups --------------------------------------------
CREATE TABLE IF NOT EXISTS public.investment_settings (
  group_id UUID PRIMARY KEY REFERENCES public.groups(id) ON DELETE CASCADE,
  purpose TEXT CHECK (purpose IS NULL OR char_length(purpose) <= 500),
  target_amount NUMERIC(14, 2) CHECK (target_amount IS NULL OR target_amount > 0),
  min_contribution NUMERIC(14, 2) NOT NULL DEFAULT 1000 CHECK (min_contribution > 0),
  max_contribution NUMERIC(14, 2) CHECK (max_contribution IS NULL OR max_contribution > 0),
  allowed_types TEXT[] NOT NULL DEFAULT ARRAY['cse', 'fd', 'gold', 'gov_securities']::TEXT[]
    CHECK (cardinality(allowed_types) >= 1
       AND allowed_types <@ ARRAY['cse', 'fd', 'gold', 'gov_securities', 'business']::TEXT[]),
  risk_level TEXT NOT NULL DEFAULT 'low' CHECK (risk_level IN ('low', 'medium', 'high')),
  distribution_rule TEXT NOT NULL DEFAULT 'pro_rata' CHECK (distribution_rule IN ('pro_rata', 'equal')),
  lock_in_months INT NOT NULL DEFAULT 0 CHECK (lock_in_months BETWEEN 0 AND 120),
  exit_rule TEXT CHECK (exit_rule IS NULL OR char_length(exit_rule) <= 1000),
  -- How an early exit is calculated: get back what you paid in, or your
  -- share of the group's current value. Penalty applies during lock-in.
  exit_payout_method TEXT NOT NULL DEFAULT 'share_of_value'
    CHECK (exit_payout_method IN ('contribution_back', 'share_of_value')),
  early_exit_penalty_pct NUMERIC(5, 2) NOT NULL DEFAULT 0 CHECK (early_exit_penalty_pct BETWEEN 0 AND 50),
  -- The leader may record an investment up to this amount without a vote.
  decision_threshold NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (decision_threshold >= 0),
  proposals_by TEXT NOT NULL DEFAULT 'any' CHECK (proposals_by IN ('any', 'leader')),
  exit_approval TEXT NOT NULL DEFAULT 'leader' CHECK (exit_approval IN ('leader', 'vote')),
  CHECK (max_contribution IS NULL OR max_contribution >= min_contribution)
);

CREATE TABLE IF NOT EXISTS public.group_contributions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
  status TEXT NOT NULL DEFAULT 'pledged' CHECK (status IN ('pledged', 'marked_paid', 'confirmed', 'cancelled')),
  receipt_path TEXT,
  pledged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  marked_at TIMESTAMPTZ,
  confirmed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  confirmed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS group_contributions_group_idx ON public.group_contributions (group_id, status);
CREATE INDEX IF NOT EXISTS group_contributions_user_idx ON public.group_contributions (user_id, status);
CREATE INDEX IF NOT EXISTS group_contributions_confirmed_by_idx ON public.group_contributions (confirmed_by);

CREATE TABLE IF NOT EXISTS public.group_proposals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  title TEXT NOT NULL CHECK (char_length(btrim(title)) BETWEEN 3 AND 150),
  investment_type TEXT NOT NULL CHECK (investment_type IN ('cse', 'fd', 'gold', 'gov_securities', 'business')),
  amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
  holding_period TEXT CHECK (holding_period IS NULL OR char_length(holding_period) <= 100),
  risk_level TEXT NOT NULL CHECK (risk_level IN ('low', 'medium', 'high')),
  reasoning TEXT NOT NULL CHECK (char_length(btrim(reasoning)) BETWEEN 10 AND 3000),
  links TEXT[] NOT NULL DEFAULT '{}' CHECK (cardinality(links) <= 5),
  -- Optional, always shown as "Estimate — not guaranteed".
  expected_return_pct NUMERIC(6, 2) CHECK (expected_return_pct IS NULL OR expected_return_pct BETWEEN -100 AND 1000),
  vote_id UUID REFERENCES public.group_votes(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'voting'
    CHECK (status IN ('voting', 'approved', 'rejected', 'executed', 'withdrawn')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS group_proposals_group_idx ON public.group_proposals (group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS group_proposals_vote_idx ON public.group_proposals (vote_id);
CREATE INDEX IF NOT EXISTS group_proposals_created_by_idx ON public.group_proposals (created_by);

CREATE TABLE IF NOT EXISTS public.group_investments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  proposal_id UUID REFERENCES public.group_proposals(id) ON DELETE SET NULL,
  title TEXT NOT NULL CHECK (char_length(btrim(title)) BETWEEN 3 AND 150),
  investment_type TEXT NOT NULL CHECK (investment_type IN ('cse', 'fd', 'gold', 'gov_securities', 'business')),
  amount_invested NUMERIC(14, 2) NOT NULL CHECK (amount_invested > 0),
  made_on DATE NOT NULL,
  details TEXT CHECK (details IS NULL OR char_length(details) <= 2000),
  proof_path TEXT,
  approved_via TEXT NOT NULL CHECK (approved_via IN ('vote', 'leader_under_threshold')),
  current_value NUMERIC(14, 2) NOT NULL CHECK (current_value >= 0),
  income_total NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (income_total >= 0),
  closing_value NUMERIC(14, 2) CHECK (closing_value IS NULL OR closing_value >= 0),
  closed_on DATE,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  recorded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS group_investments_group_idx ON public.group_investments (group_id, status);
CREATE INDEX IF NOT EXISTS group_investments_proposal_idx ON public.group_investments (proposal_id);
CREATE INDEX IF NOT EXISTS group_investments_recorded_by_idx ON public.group_investments (recorded_by);

CREATE TABLE IF NOT EXISTS public.group_investment_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  investment_id UUID NOT NULL REFERENCES public.group_investments(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('value', 'income', 'close')),
  amount NUMERIC(14, 2) NOT NULL CHECK (amount >= 0),
  note TEXT CHECK (note IS NULL OR char_length(note) <= 500),
  recorded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS group_investment_updates_inv_idx ON public.group_investment_updates (investment_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS group_investment_updates_group_idx ON public.group_investment_updates (group_id);
CREATE INDEX IF NOT EXISTS group_investment_updates_by_idx ON public.group_investment_updates (recorded_by);

CREATE TABLE IF NOT EXISTS public.group_distributions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  total_amount NUMERIC(14, 2) NOT NULL CHECK (total_amount > 0),
  rule TEXT NOT NULL CHECK (rule IN ('pro_rata', 'equal')),
  note TEXT CHECK (note IS NULL OR char_length(note) <= 500),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'completed')),
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS group_distributions_group_idx ON public.group_distributions (group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS group_distributions_created_by_idx ON public.group_distributions (created_by);

CREATE TABLE IF NOT EXISTS public.group_distribution_shares (
  distribution_id UUID NOT NULL REFERENCES public.group_distributions(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  share_pct NUMERIC(7, 4) NOT NULL CHECK (share_pct BETWEEN 0 AND 100),
  amount NUMERIC(14, 2) NOT NULL CHECK (amount >= 0),
  confirmed_at TIMESTAMPTZ,
  PRIMARY KEY (distribution_id, user_id)
);
CREATE INDEX IF NOT EXISTS group_distribution_shares_user_idx ON public.group_distribution_shares (user_id);
CREATE INDEX IF NOT EXISTS group_distribution_shares_group_idx ON public.group_distribution_shares (group_id);

CREATE TABLE IF NOT EXISTS public.group_exit_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason TEXT CHECK (reason IS NULL OR char_length(reason) <= 500),
  payout_amount NUMERIC(14, 2) NOT NULL CHECK (payout_amount >= 0),
  calculation JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'declined', 'completed', 'cancelled')),
  vote_id UUID REFERENCES public.group_votes(id) ON DELETE SET NULL,
  decided_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  decided_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS group_exit_requests_open_uidx
  ON public.group_exit_requests (group_id, user_id) WHERE status IN ('pending', 'approved');
CREATE INDEX IF NOT EXISTS group_exit_requests_user_idx ON public.group_exit_requests (user_id);
CREATE INDEX IF NOT EXISTS group_exit_requests_vote_idx ON public.group_exit_requests (vote_id);
CREATE INDEX IF NOT EXISTS group_exit_requests_decided_by_idx ON public.group_exit_requests (decided_by);

-- Activity log (append-only) -----------------------------------
CREATE TABLE IF NOT EXISTS public.group_activity_log (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  event TEXT NOT NULL,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS group_activity_log_group_idx ON public.group_activity_log (group_id, id DESC);
CREATE INDEX IF NOT EXISTS group_activity_log_actor_idx ON public.group_activity_log (actor_id);

-- Notifications ---------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN (
    'connection_request', 'connection_accepted', 'join_request', 'join_decision', 'group_invite',
    'chat_message', 'poll_opened', 'vote_opened', 'vote_closing_soon', 'vote_result',
    'seettu_payment_due', 'seettu_payment_overdue', 'seettu_payment_marked', 'seettu_payment_confirmed',
    'seettu_pot_handed', 'seettu_pot_received', 'contribution_marked', 'contribution_confirmed',
    'distribution_created', 'exit_update', 'role_changed', 'removed_from_group', 'group_update')),
  title TEXT NOT NULL,
  body TEXT,
  group_id UUID REFERENCES public.groups(id) ON DELETE CASCADE,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS notifications_user_idx ON public.notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS notifications_unread_idx ON public.notifications (user_id) WHERE read_at IS NULL;
CREATE INDEX IF NOT EXISTS notifications_group_idx ON public.notifications (group_id);

-- Safety -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  target_type TEXT NOT NULL CHECK (target_type IN ('user', 'group', 'message')),
  target_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  target_group_id UUID REFERENCES public.groups(id) ON DELETE SET NULL,
  target_message_id UUID REFERENCES public.group_messages(id) ON DELETE SET NULL,
  reason TEXT NOT NULL CHECK (reason IN ('scam', 'harassment', 'spam', 'fake_profile',
    'payment_dispute', 'inappropriate', 'other')),
  details TEXT CHECK (details IS NULL OR char_length(details) <= 1000),
  is_scam_report BOOLEAN NOT NULL DEFAULT FALSE,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'reviewing', 'upheld', 'dismissed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS reports_reporter_idx ON public.reports (reporter_id, created_at DESC);
CREATE INDEX IF NOT EXISTS reports_user_idx ON public.reports (target_user_id, status);
CREATE INDEX IF NOT EXISTS reports_group_idx ON public.reports (target_group_id);
CREATE INDEX IF NOT EXISTS reports_message_idx ON public.reports (target_message_id);
CREATE INDEX IF NOT EXISTS reports_open_idx ON public.reports (created_at) WHERE status IN ('open', 'reviewing');

-- Admin decisions. No client policies: reviewed in the Supabase dashboard
-- (service role) until the app has an admin role.
CREATE TABLE IF NOT EXISTS public.admin_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES public.reports(id) ON DELETE CASCADE,
  reviewer TEXT NOT NULL,
  decision TEXT NOT NULL CHECK (decision IN ('upheld', 'dismissed', 'needs_info')),
  action_taken TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS admin_reviews_report_idx ON public.admin_reviews (report_id);

-- ------------------------------------------------------------
-- 4. Pure helpers (IMMUTABLE). Mirrored in lib/core/community/ for unit
-- tests; keep the two in sync.
-- ------------------------------------------------------------

-- 0: under 10k, 1: 10k–50k, 2: 50k–100k, 3: 100k–250k, 4: 250k–500k, 5: 500k+
CREATE OR REPLACE FUNCTION public.cg_contribution_bucket(p_amount NUMERIC)
RETURNS INT
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT CASE
    WHEN p_amount IS NULL THEN NULL
    WHEN p_amount < 10000 THEN 0
    WHEN p_amount < 50000 THEN 1
    WHEN p_amount < 100000 THEN 2
    WHEN p_amount < 250000 THEN 3
    WHEN p_amount < 500000 THEN 4
    ELSE 5
  END;
$$;

CREATE OR REPLACE FUNCTION public.cg_contribution_label(p_amount NUMERIC)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT (ARRAY['Under Rs 10k', 'Rs 10k–50k', 'Rs 50k–100k', 'Rs 100k–250k', 'Rs 250k–500k', 'Rs 500k+'])
    [public.cg_contribution_bucket(p_amount) + 1];
$$;

-- Due date of a seettu round. Weekly: the first p_due_day (ISO weekday)
-- on or after the start date, then every 7 days. Monthly: the first
-- p_due_day (1–28) on or after the start date, then every month.
CREATE OR REPLACE FUNCTION public.cg_seettu_due_date(p_start DATE, p_frequency TEXT, p_due_day INT, p_round INT)
RETURNS DATE
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE v_first DATE;
BEGIN
  IF p_round < 1 THEN RAISE EXCEPTION 'invalid_round'; END IF;
  IF p_frequency = 'weekly' THEN
    IF p_due_day NOT BETWEEN 1 AND 7 THEN RAISE EXCEPTION 'invalid_due_day'; END IF;
    v_first := p_start + ((p_due_day - EXTRACT(ISODOW FROM p_start)::INT + 7) % 7);
    RETURN v_first + 7 * (p_round - 1);
  ELSIF p_frequency = 'monthly' THEN
    IF p_due_day NOT BETWEEN 1 AND 28 THEN RAISE EXCEPTION 'invalid_due_day'; END IF;
    v_first := make_date(EXTRACT(YEAR FROM p_start)::INT, EXTRACT(MONTH FROM p_start)::INT, p_due_day);
    IF v_first < p_start THEN v_first := (v_first + INTERVAL '1 month')::DATE; END IF;
    RETURN (v_first + make_interval(months => p_round - 1))::DATE;
  END IF;
  RAISE EXCEPTION 'invalid_frequency';
END;
$$;

-- Splits p_total into amounts proportional to p_weights, rounded to cents
-- so they add up exactly to p_total (largest remainder; ties go to the
-- earlier position). All-zero weights split equally.
CREATE OR REPLACE FUNCTION public.cg_split_amount(p_total NUMERIC, p_weights NUMERIC[])
RETURNS NUMERIC[]
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  n INT := COALESCE(array_length(p_weights, 1), 0);
  v_weights NUMERIC[] := p_weights;
  v_total_cents BIGINT := round(p_total * 100);
  v_sum NUMERIC := 0;
  v_raw NUMERIC;
  v_cents BIGINT[];
  v_rem NUMERIC[];
  v_assigned BIGINT := 0;
  v_order INT[];
  i INT;
BEGIN
  IF n = 0 THEN RETURN '{}'::NUMERIC[]; END IF;
  IF p_total < 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  FOR i IN 1..n LOOP
    IF v_weights[i] IS NULL OR v_weights[i] < 0 THEN RAISE EXCEPTION 'invalid_weight'; END IF;
    v_sum := v_sum + v_weights[i];
  END LOOP;
  IF v_sum = 0 THEN
    v_weights := array_fill(1::NUMERIC, ARRAY[n]);
    v_sum := n;
  END IF;
  v_cents := array_fill(0::BIGINT, ARRAY[n]);
  v_rem := array_fill(0::NUMERIC, ARRAY[n]);
  FOR i IN 1..n LOOP
    v_raw := v_total_cents * v_weights[i] / v_sum;
    v_cents[i] := floor(v_raw);
    v_rem[i] := v_raw - floor(v_raw);
    v_assigned := v_assigned + v_cents[i];
  END LOOP;
  SELECT array_agg(t.idx::INT ORDER BY t.r DESC, t.idx) INTO v_order
  FROM unnest(v_rem) WITH ORDINALITY AS t(r, idx);
  FOR i IN 1..(v_total_cents - v_assigned) LOOP
    v_cents[v_order[i]] := v_cents[v_order[i]] + 1;
  END LOOP;
  RETURN ARRAY(SELECT (c::NUMERIC / 100)::NUMERIC(14, 2) FROM unnest(v_cents) WITH ORDINALITY AS t(c, idx) ORDER BY t.idx);
END;
$$;

-- Formal vote result. Quorum is by headcount (ballots incl. abstain);
-- the threshold is on weights. Ties always fail.
CREATE OR REPLACE FUNCTION public.cg_vote_passes(
  p_yes NUMERIC, p_no NUMERIC, p_ballots INT, p_eligible_count INT, p_eligible_weight NUMERIC,
  p_quorum_pct INT, p_threshold TEXT, p_base TEXT)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT p_eligible_count > 0
    AND p_ballots * 100 >= p_quorum_pct * p_eligible_count
    AND p_yes > p_no
    AND CASE
      WHEN p_base = 'eligible' AND p_threshold = 'two_thirds' THEN 3 * p_yes >= 2 * p_eligible_weight
      WHEN p_base = 'eligible' THEN 2 * p_yes > p_eligible_weight
      WHEN p_threshold = 'two_thirds' THEN 3 * p_yes >= 2 * (p_yes + p_no)
      ELSE TRUE
    END;
$$;

-- Early-exit payout: what the member paid in, or their share of the
-- group's current value; less the early-exit penalty during lock-in.
CREATE OR REPLACE FUNCTION public.cg_exit_payout(
  p_method TEXT, p_contribution NUMERIC, p_share NUMERIC, p_pool_value NUMERIC,
  p_penalty_pct NUMERIC, p_in_lock_in BOOLEAN)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT GREATEST(0, round(
    (CASE WHEN p_method = 'contribution_back' THEN p_contribution ELSE p_share * p_pool_value END)
    * (CASE WHEN p_in_lock_in THEN (100 - p_penalty_pct) / 100 ELSE 1 END), 2))::NUMERIC(14, 2);
$$;

-- True when the text looks like it contains a bank account or card number:
-- 12+ digits in a run (spaces/dashes allowed), or 8+ digits next to words
-- like "account" or "card". Sri Lankan mobile numbers are allowed.
CREATE OR REPLACE FUNCTION public.cg_has_payment_details(p_body TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  m TEXT[];
  v_digits TEXT;
  v_keyword BOOLEAN;
BEGIN
  IF p_body IS NULL THEN RETURN FALSE; END IF;
  v_keyword := lower(p_body) ~ '(a/c|acc|account|bank|branch|card|iban|swift|cvv)';
  FOR m IN SELECT regexp_matches(p_body, '\d(?:[ -]?\d){7,}', 'g') LOOP
    v_digits := regexp_replace(m[1], '\D', '', 'g');
    IF v_digits ~ '^(0?7\d{8}|947\d{8})$' THEN CONTINUE; END IF;
    IF length(v_digits) >= 12 THEN RETURN TRUE; END IF;
    IF v_keyword THEN RETURN TRUE; END IF;
  END LOOP;
  RETURN FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION public._cg_escape_like(p TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT replace(replace(replace(p, '\', '\\'), '%', '\%'), '_', '\_');
$$;

CREATE OR REPLACE FUNCTION public.cg_try_uuid(p TEXT)
RETURNS UUID
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
BEGIN
  RETURN p::UUID;
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$$;

-- ------------------------------------------------------------
-- 5. Access helpers (used by RLS policies; SECURITY DEFINER so policies
-- on group_members don't recurse).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._cg_uid()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE v UUID := auth.uid();
BEGIN
  IF v IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN v;
END;
$$;

CREATE OR REPLACE FUNCTION public.cg_is_member(p_group UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.group_members
    WHERE group_id = p_group AND user_id = auth.uid() AND status = 'active');
$$;

CREATE OR REPLACE FUNCTION public._cg_blocked(p_a UUID, p_b UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.blocks
    WHERE unblocked_at IS NULL
      AND ((blocker_id = p_a AND blocked_id = p_b) OR (blocker_id = p_b AND blocked_id = p_a)));
$$;

CREATE OR REPLACE FUNCTION public._cg_connected(p_a UUID, p_b UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.connections
    WHERE LEAST(requester_id, addressee_id) = LEAST(p_a, p_b)
      AND GREATEST(requester_id, addressee_id) = GREATEST(p_a, p_b)
      AND status = 'accepted');
$$;

CREATE OR REPLACE FUNCTION public._cg_share_group(p_a UUID, p_b UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.group_members a
    JOIN public.group_members b ON b.group_id = a.group_id
    WHERE a.user_id = p_a AND b.user_id = p_b AND a.status = 'active' AND b.status = 'active');
$$;

-- May the caller see this person's community profile at all?
CREATE OR REPLACE FUNCTION public.cg_can_see_profile(p_user UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT p_user = auth.uid() OR (
    NOT public._cg_blocked(auth.uid(), p_user) AND (
      public._cg_connected(auth.uid(), p_user)
      OR public._cg_share_group(auth.uid(), p_user)
      OR EXISTS (
        SELECT 1 FROM public.community_profiles cp, public.community_config cfg
        WHERE cp.user_id = p_user AND cp.available_for_groups
          AND (NOT cfg.require_phone_verification OR cp.phone_verified))
      -- Leaders see people who asked to join their group.
      OR EXISTS (
        SELECT 1 FROM public.group_join_requests r
        JOIN public.group_members m ON m.group_id = r.group_id
        WHERE r.user_id = p_user AND r.status = 'pending'
          AND m.user_id = auth.uid() AND m.status = 'active')));
$$;

-- Phone is shown to connections and fellow group members, or in search
-- when the owner allows it.
CREATE OR REPLACE FUNCTION public._cg_phone_for(p_viewer UUID, p_user UUID)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE
    WHEN p_viewer = p_user
      OR public._cg_connected(p_viewer, p_user)
      OR public._cg_share_group(p_viewer, p_user)
      OR (cp.phone_visible_in_search AND cp.available_for_groups AND NOT public._cg_blocked(p_viewer, p_user))
    THEN cp.phone END
  FROM public.community_profiles cp WHERE cp.user_id = p_user;
$$;

CREATE OR REPLACE FUNCTION public._cg_require_phone_verification()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE((SELECT require_phone_verification FROM public.community_config LIMIT 1), FALSE);
$$;

CREATE OR REPLACE FUNCTION public._cg_age_ok(p_user UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE((
    SELECT NOT COALESCE(p.is_under_18, FALSE) AND (
      (p.date_of_birth IS NOT NULL AND p.date_of_birth <= (CURRENT_DATE - INTERVAL '18 years')::DATE)
      OR (p.date_of_birth IS NULL AND p.age_confirmed_at IS NOT NULL))
    FROM public.profiles p WHERE p.id = p_user), FALSE);
$$;

CREATE OR REPLACE FUNCTION public._cg_name(p_user UUID)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE(
    (SELECT display_name FROM public.community_profiles WHERE user_id = p_user),
    (SELECT NULLIF(btrim(full_name), '') FROM public.profiles WHERE id = p_user),
    'A member');
$$;

-- Returns the caller's role in the group, or raises. Also records that
-- the caller was active (used for the 30-day leader-inactivity rule).
CREATE OR REPLACE FUNCTION public._cg_require_member(p_group UUID, p_roles TEXT[] DEFAULT NULL)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  v_role TEXT;
BEGIN
  SELECT role INTO v_role FROM public.group_members
  WHERE group_id = p_group AND user_id = v_uid AND status = 'active';
  IF v_role IS NULL THEN RAISE EXCEPTION 'not_group_member'; END IF;
  IF p_roles IS NOT NULL AND NOT (v_role = ANY (p_roles)) THEN RAISE EXCEPTION 'not_group_officer'; END IF;
  UPDATE public.group_members SET last_active_at = NOW()
  WHERE group_id = p_group AND user_id = v_uid AND last_active_at < NOW() - INTERVAL '5 minutes';
  RETURN v_role;
END;
$$;

CREATE OR REPLACE FUNCTION public._cg_group_for_update(p_group UUID)
RETURNS public.groups
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE g public.groups;
BEGIN
  SELECT * INTO g FROM public.groups WHERE id = p_group FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'group_not_found'; END IF;
  RETURN g;
END;
$$;

CREATE OR REPLACE FUNCTION public._cg_log(p_group UUID, p_actor UUID, p_event TEXT, p_details JSONB DEFAULT '{}'::jsonb)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  INSERT INTO public.group_activity_log (group_id, actor_id, event, details)
  VALUES (p_group, p_actor, p_event, COALESCE(p_details, '{}'::jsonb));
$$;

CREATE OR REPLACE FUNCTION public._cg_system_message(p_group UUID, p_body TEXT)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  INSERT INTO public.group_messages (group_id, sender_id, body, is_system) VALUES (p_group, NULL, left(p_body, 2000), TRUE);
$$;

CREATE OR REPLACE FUNCTION public._cg_notify(
  p_user UUID, p_kind TEXT, p_title TEXT, p_body TEXT DEFAULT NULL,
  p_group UUID DEFAULT NULL, p_data JSONB DEFAULT '{}'::jsonb)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  INSERT INTO public.notifications (user_id, kind, title, body, group_id, data)
  SELECT p_user, p_kind, p_title, p_body, p_group, COALESCE(p_data, '{}'::jsonb)
  WHERE p_user IS NOT NULL;
$$;

-- Notifies active members, optionally only some roles, skipping one user.
CREATE OR REPLACE FUNCTION public._cg_notify_members(
  p_group UUID, p_kind TEXT, p_title TEXT, p_body TEXT DEFAULT NULL,
  p_data JSONB DEFAULT '{}'::jsonb, p_except UUID DEFAULT NULL, p_roles TEXT[] DEFAULT NULL)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  INSERT INTO public.notifications (user_id, kind, title, body, group_id, data)
  SELECT m.user_id, p_kind, p_title, p_body, p_group, COALESCE(p_data, '{}'::jsonb)
  FROM public.group_members m
  WHERE m.group_id = p_group AND m.status = 'active'
    AND m.user_id IS DISTINCT FROM p_except
    AND (p_roles IS NULL OR m.role = ANY (p_roles));
$$;

CREATE OR REPLACE FUNCTION public._cg_active_count(p_group UUID)
RETURNS INT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COUNT(*)::INT FROM public.group_members WHERE group_id = p_group AND status = 'active';
$$;

-- Trust indicators shown on profiles. Upheld reports are deliberately
-- not included (internal only).
CREATE OR REPLACE FUNCTION public._cg_trust(p_user UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'phone_verified', COALESCE((SELECT phone_verified FROM public.community_profiles WHERE user_id = p_user), FALSE),
    'member_since', (SELECT created_at FROM public.profiles WHERE id = p_user),
    'groups_completed', (
      SELECT COUNT(*) FROM public.group_members m JOIN public.groups g ON g.id = m.group_id
      WHERE m.user_id = p_user AND m.status = 'active' AND g.status = 'closed'),
    'seettu_on_time_pct', (
      SELECT CASE WHEN COUNT(*) = 0 THEN NULL ELSE
        round(100.0 * COUNT(*) FILTER (WHERE sp.status = 'confirmed' AND sp.marked_at::DATE <= r.due_date) / COUNT(*)) END
      FROM public.seettu_payments sp JOIN public.seettu_rounds r ON r.id = sp.round_id
      WHERE sp.payer_id = p_user AND (sp.status = 'confirmed' OR r.due_date < CURRENT_DATE)));
$$;

-- Warnings shown to someone thinking of joining.
CREATE OR REPLACE FUNCTION public._cg_group_warnings(p_group UUID)
RETURNS TEXT[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT ARRAY_REMOVE(ARRAY[
    CASE WHEN p.created_at > NOW() - INTERVAL '7 days' THEN 'leader_new_account' END,
    CASE WHEN NOT COALESCE(cp.phone_verified, FALSE) THEN 'leader_phone_unverified' END,
    CASE WHEN NOT EXISTS (
      SELECT 1 FROM public.group_members m2 JOIN public.groups g2 ON g2.id = m2.group_id
      WHERE m2.user_id = m.user_id AND m2.status = 'active' AND g2.status = 'closed')
      THEN 'leader_no_completed_groups' END
  ], NULL)
  FROM public.group_members m
  JOIN public.profiles p ON p.id = m.user_id
  LEFT JOIN public.community_profiles cp ON cp.user_id = m.user_id
  WHERE m.group_id = p_group AND m.role = 'leader' AND m.status = 'active';
$$;

CREATE OR REPLACE FUNCTION public._cg_seettu_must_complete(p_group UUID, p_user UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
      SELECT 1 FROM public.seettu_rounds
      WHERE group_id = p_group AND recipient_id = p_user AND status IN ('handed_over', 'completed'))
    AND EXISTS (
      SELECT 1 FROM public.seettu_payments
      WHERE group_id = p_group AND payer_id = p_user AND status <> 'confirmed');
$$;

-- Investment group money position. Everything is a record of what
-- members say happened outside the app.
CREATE OR REPLACE FUNCTION public._cg_invest_position(p_group UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH c AS (
    SELECT COALESCE(SUM(amount) FILTER (WHERE status = 'confirmed'), 0) AS confirmed,
           COALESCE(SUM(amount) FILTER (WHERE status IN ('pledged', 'marked_paid')), 0) AS pending
    FROM public.group_contributions WHERE group_id = p_group
  ), i AS (
    SELECT COALESCE(SUM(amount_invested) FILTER (WHERE status = 'open'), 0) AS invested_open,
           COALESCE(SUM(current_value) FILTER (WHERE status = 'open'), 0) AS value_open,
           COALESCE(SUM(amount_invested) FILTER (WHERE status = 'closed'), 0) AS invested_closed,
           COALESCE(SUM(closing_value) FILTER (WHERE status = 'closed'), 0) AS closed_value,
           COALESCE(SUM(income_total), 0) AS income
    FROM public.group_investments WHERE group_id = p_group
  ), d AS (
    SELECT COALESCE(SUM(total_amount), 0) AS distributed FROM public.group_distributions WHERE group_id = p_group
  ), x AS (
    SELECT COALESCE(SUM(payout_amount), 0) AS exits_paid
    FROM public.group_exit_requests WHERE group_id = p_group AND status = 'completed'
  )
  SELECT jsonb_build_object(
    'confirmed_pool', c.confirmed,
    'pending_pledges', c.pending,
    'invested_open', i.invested_open,
    'current_value', i.value_open,
    'unrealised_pl', i.value_open - i.invested_open,
    'realised_pl', i.closed_value - i.invested_closed + i.income,
    'income', i.income,
    'distributed', d.distributed,
    'exits_paid', x.exits_paid,
    'cash', c.confirmed - i.invested_open - i.invested_closed + i.closed_value + i.income - d.distributed - x.exits_paid,
    'pool_value', c.confirmed - i.invested_closed + i.closed_value + i.income - d.distributed - x.exits_paid
                  + (i.value_open - i.invested_open))
  FROM c, i, d, x;
$$;

-- Confirmed contributions of active members, for shares and weights.
CREATE OR REPLACE FUNCTION public._cg_member_contributions(p_group UUID)
RETURNS TABLE (user_id UUID, confirmed NUMERIC)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT m.user_id, COALESCE(SUM(c.amount) FILTER (WHERE c.status = 'confirmed'), 0)
  FROM public.group_members m
  LEFT JOIN public.group_contributions c ON c.group_id = m.group_id AND c.user_id = m.user_id
  WHERE m.group_id = p_group AND m.status = 'active'
  GROUP BY m.user_id
  ORDER BY m.user_id;
$$;

-- ------------------------------------------------------------
-- 6. RLS
-- ------------------------------------------------------------
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'community_config', 'community_profiles', 'connections', 'blocks', 'groups', 'group_members',
    'group_join_requests', 'group_invites', 'group_messages', 'polls', 'poll_options', 'poll_votes',
    'group_votes', 'group_vote_ballots', 'seettu_settings', 'seettu_rounds', 'seettu_payments',
    'seettu_bids', 'investment_settings', 'group_contributions', 'group_proposals',
    'group_investments', 'group_investment_updates', 'group_distributions',
    'group_distribution_shares', 'group_exit_requests', 'group_activity_log', 'notifications',
    'reports', 'admin_reviews'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    -- Writes only through the functions below.
    EXECUTE format('REVOKE ALL ON public.%I FROM anon', t);
    EXECUTE format('REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.%I FROM authenticated', t);
  END LOOP;
END $$;

DROP POLICY IF EXISTS "Signed-in users read community config" ON public.community_config;
CREATE POLICY "Signed-in users read community config" ON public.community_config
  FOR SELECT TO authenticated USING (TRUE);

-- Hide phone and the exact max contribution from direct selects.
REVOKE SELECT ON public.community_profiles FROM authenticated;
GRANT SELECT (user_id, available_for_groups, display_name, phone_verified, photo_path, experience,
  interests, district, bio, last_active_at, created_at) ON public.community_profiles TO authenticated;
DROP POLICY IF EXISTS "Visible community profiles" ON public.community_profiles;
CREATE POLICY "Visible community profiles" ON public.community_profiles
  FOR SELECT TO authenticated USING (public.cg_can_see_profile(user_id));

DROP POLICY IF EXISTS "Own connections" ON public.connections;
CREATE POLICY "Own connections" ON public.connections
  FOR SELECT TO authenticated USING (auth.uid() IN (requester_id, addressee_id));

DROP POLICY IF EXISTS "Own blocks" ON public.blocks;
CREATE POLICY "Own blocks" ON public.blocks
  FOR SELECT TO authenticated USING (blocker_id = auth.uid());

DROP POLICY IF EXISTS "Own reports" ON public.reports;
CREATE POLICY "Own reports" ON public.reports
  FOR SELECT TO authenticated USING (reporter_id = auth.uid());

DROP POLICY IF EXISTS "Own notifications" ON public.notifications;
CREATE POLICY "Own notifications" ON public.notifications
  FOR SELECT TO authenticated USING (user_id = auth.uid());
DROP POLICY IF EXISTS "Mark own notifications read" ON public.notifications;
CREATE POLICY "Mark own notifications read" ON public.notifications
  FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
GRANT UPDATE (read_at) ON public.notifications TO authenticated;

DROP POLICY IF EXISTS "Members read groups" ON public.groups;
CREATE POLICY "Members read groups" ON public.groups
  FOR SELECT TO authenticated USING (public.cg_is_member(id));

DROP POLICY IF EXISTS "Members read members" ON public.group_members;
CREATE POLICY "Members read members" ON public.group_members
  FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.cg_is_member(group_id));

DROP POLICY IF EXISTS "Requester or members read join requests" ON public.group_join_requests;
CREATE POLICY "Requester or members read join requests" ON public.group_join_requests
  FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.cg_is_member(group_id));

DROP POLICY IF EXISTS "Invitee or members read invites" ON public.group_invites;
CREATE POLICY "Invitee or members read invites" ON public.group_invites
  FOR SELECT TO authenticated USING (invitee_id = auth.uid() OR public.cg_is_member(group_id));

DROP POLICY IF EXISTS "Own anonymous votes or members read named votes" ON public.poll_votes;
CREATE POLICY "Own anonymous votes or members read named votes" ON public.poll_votes
  FOR SELECT TO authenticated USING (
    user_id = auth.uid()
    OR (public.cg_is_member(group_id)
        AND EXISTS (SELECT 1 FROM public.polls p WHERE p.id = poll_id AND NOT p.anonymous)));

-- Sealed bids: your own, or everyone's once the round's bidding closed.
DROP POLICY IF EXISTS "Own bids or closed rounds" ON public.seettu_bids;
CREATE POLICY "Own bids or closed rounds" ON public.seettu_bids
  FOR SELECT TO authenticated USING (
    user_id = auth.uid()
    OR (public.cg_is_member(group_id)
        AND EXISTS (SELECT 1 FROM public.seettu_rounds r WHERE r.id = round_id AND r.status <> 'bidding')));

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'group_messages', 'polls', 'poll_options', 'group_votes', 'group_vote_ballots',
    'seettu_settings', 'seettu_rounds', 'seettu_payments', 'investment_settings',
    'group_contributions', 'group_proposals', 'group_investments', 'group_investment_updates',
    'group_distributions', 'group_distribution_shares', 'group_exit_requests', 'group_activity_log'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS "Members read %1$s" ON public.%1$I', t);
    EXECUTE format('CREATE POLICY "Members read %1$s" ON public.%1$I FOR SELECT TO authenticated USING (public.cg_is_member(group_id))', t);
  END LOOP;
END $$;
-- admin_reviews: no policies (service role only).

-- Activity log: nobody edits or deletes. The trigger below blocks every
-- role, including the service role used by the dashboard.
REVOKE UPDATE, DELETE, TRUNCATE ON public.group_activity_log FROM authenticated, anon;
CREATE OR REPLACE FUNCTION public._cg_log_is_append_only()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION 'activity_log_is_append_only';
END;
$$;
DROP TRIGGER IF EXISTS group_activity_log_append_only ON public.group_activity_log;
CREATE TRIGGER group_activity_log_append_only
  BEFORE UPDATE OR DELETE ON public.group_activity_log
  FOR EACH ROW EXECUTE FUNCTION public._cg_log_is_append_only();
DROP TRIGGER IF EXISTS group_activity_log_no_truncate ON public.group_activity_log;
CREATE TRIGGER group_activity_log_no_truncate
  BEFORE TRUNCATE ON public.group_activity_log
  FOR EACH STATEMENT EXECUTE FUNCTION public._cg_log_is_append_only();

-- ------------------------------------------------------------
-- 7. Community profile RPCs
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._cg_sync_phone(p_user UUID)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  -- Verified when Supabase phone OTP confirmed the same number (compared
  -- on the last 9 digits, so 077… and +9477… match).
  UPDATE public.community_profiles cp
  SET phone_verified = EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = p_user AND u.phone_confirmed_at IS NOT NULL AND cp.phone IS NOT NULL
      AND right(regexp_replace(u.phone, '\D', '', 'g'), 9) = right(regexp_replace(cp.phone, '\D', '', 'g'), 9))
  WHERE cp.user_id = p_user;
$$;

CREATE OR REPLACE FUNCTION public.community_my_profile()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  p public.profiles;
  cp public.community_profiles;
BEGIN
  SELECT * INTO p FROM public.profiles WHERE id = v_uid;
  SELECT * INTO cp FROM public.community_profiles WHERE user_id = v_uid;
  RETURN jsonb_build_object(
    'exists', cp.user_id IS NOT NULL,
    'profile', CASE WHEN cp.user_id IS NULL THEN NULL ELSE to_jsonb(cp) END,
    'contribution_label', public.cg_contribution_label(cp.max_contribution),
    'default_display_name', COALESCE(NULLIF(btrim(p.full_name), ''), ''),
    'default_phone', p.mobile_number,
    'is_under_18', COALESCE(p.is_under_18, FALSE),
    'date_of_birth', p.date_of_birth,
    'age_confirmed', p.age_confirmed_at IS NOT NULL,
    'can_be_available', public._cg_age_ok(v_uid),
    'require_phone_verification', public._cg_require_phone_verification(),
    'trust', public._cg_trust(v_uid));
END;
$$;

CREATE OR REPLACE FUNCTION public.community_save_profile(
  p_display_name TEXT,
  p_phone TEXT DEFAULT NULL,
  p_phone_visible_in_search BOOLEAN DEFAULT FALSE,
  p_photo_path TEXT DEFAULT NULL,
  p_max_contribution NUMERIC DEFAULT NULL,
  p_experience TEXT DEFAULT 'none',
  p_interests TEXT[] DEFAULT '{}',
  p_district TEXT DEFAULT NULL,
  p_bio TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  v_photo TEXT := NULLIF(btrim(p_photo_path), '');
BEGIN
  IF v_photo IS NOT NULL AND v_photo NOT LIKE 'avatars/' || v_uid::TEXT || '/%' THEN
    RAISE EXCEPTION 'invalid_photo_path';
  END IF;
  IF NULLIF(btrim(p_display_name), '') IS NULL THEN RAISE EXCEPTION 'display_name_required'; END IF;
  IF p_bio IS NOT NULL AND char_length(btrim(p_bio)) > 200 THEN RAISE EXCEPTION 'bio_too_long'; END IF;
  INSERT INTO public.community_profiles AS cp (
    user_id, display_name, phone, phone_visible_in_search, photo_path, max_contribution,
    experience, interests, district, bio)
  VALUES (
    v_uid, btrim(p_display_name), NULLIF(btrim(p_phone), ''), COALESCE(p_phone_visible_in_search, FALSE),
    v_photo, p_max_contribution, COALESCE(p_experience, 'none'), COALESCE(p_interests, '{}'),
    NULLIF(btrim(p_district), ''), NULLIF(btrim(p_bio), ''))
  ON CONFLICT (user_id) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    phone = EXCLUDED.phone,
    phone_visible_in_search = EXCLUDED.phone_visible_in_search,
    photo_path = EXCLUDED.photo_path,
    max_contribution = EXCLUDED.max_contribution,
    experience = EXCLUDED.experience,
    interests = EXCLUDED.interests,
    district = EXCLUDED.district,
    bio = EXCLUDED.bio,
    last_active_at = NOW(),
    updated_at = NOW();
  PERFORM public._cg_sync_phone(v_uid);
  RETURN public.community_my_profile();
END;
$$;

-- For users without a stored DOB: confirms they are 18 or over.
CREATE OR REPLACE FUNCTION public.community_confirm_age()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  p public.profiles;
BEGIN
  SELECT * INTO p FROM public.profiles WHERE id = v_uid;
  IF COALESCE(p.is_under_18, FALSE)
     OR (p.date_of_birth IS NOT NULL AND p.date_of_birth > (CURRENT_DATE - INTERVAL '18 years')::DATE) THEN
    RAISE EXCEPTION 'under_18';
  END IF;
  UPDATE public.profiles SET age_confirmed_at = COALESCE(age_confirmed_at, NOW()) WHERE id = v_uid;
  RETURN public.community_my_profile();
END;
$$;

-- Turning it off hides the user from search at once; connections and
-- memberships keep working.
CREATE OR REPLACE FUNCTION public.community_set_available(p_available BOOLEAN)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_uid UUID := public._cg_uid();
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.community_profiles WHERE user_id = v_uid) THEN
    RAISE EXCEPTION 'profile_required';
  END IF;
  IF p_available AND NOT public._cg_age_ok(v_uid) THEN
    IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_uid AND (COALESCE(is_under_18, FALSE)
        OR (date_of_birth IS NOT NULL AND date_of_birth > (CURRENT_DATE - INTERVAL '18 years')::DATE))) THEN
      RAISE EXCEPTION 'under_18';
    END IF;
    RAISE EXCEPTION 'age_confirmation_required';
  END IF;
  UPDATE public.community_profiles
  SET available_for_groups = COALESCE(p_available, FALSE), last_active_at = NOW(), updated_at = NOW()
  WHERE user_id = v_uid;
  RETURN public.community_my_profile();
END;
$$;

CREATE OR REPLACE FUNCTION public.community_mark_explainer_seen()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_uid UUID := public._cg_uid();
BEGIN
  UPDATE public.community_profiles SET explainer_seen_at = COALESCE(explainer_seen_at, NOW()) WHERE user_id = v_uid;
END;
$$;

-- Re-checks phone verification after the app completes a Supabase phone OTP.
CREATE OR REPLACE FUNCTION public.community_refresh_phone_verification()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM public._cg_sync_phone(public._cg_uid());
  RETURN public.community_my_profile();
END;
$$;

-- Someone else's profile with the visibility rules applied; NULL when
-- hidden or blocked.
CREATE OR REPLACE FUNCTION public.community_get_profile(p_user UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  cp public.community_profiles;
  c public.connections;
BEGIN
  IF NOT public.cg_can_see_profile(p_user) THEN RETURN NULL; END IF;
  SELECT * INTO cp FROM public.community_profiles WHERE user_id = p_user;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT * INTO c FROM public.connections
  WHERE LEAST(requester_id, addressee_id) = LEAST(v_uid, p_user)
    AND GREATEST(requester_id, addressee_id) = GREATEST(v_uid, p_user);
  RETURN jsonb_build_object(
    'user_id', cp.user_id,
    'display_name', cp.display_name,
    'photo_path', cp.photo_path,
    'contribution_bucket', public.cg_contribution_bucket(cp.max_contribution),
    'contribution_label', public.cg_contribution_label(cp.max_contribution),
    'experience', cp.experience,
    'interests', to_jsonb(cp.interests),
    'district', cp.district,
    'bio', cp.bio,
    'available_for_groups', cp.available_for_groups,
    'phone', public._cg_phone_for(v_uid, p_user),
    'trust', public._cg_trust(p_user),
    'connection', CASE WHEN c.id IS NULL THEN NULL ELSE jsonb_build_object(
      'id', c.id, 'status', c.status,
      'direction', CASE WHEN c.requester_id = v_uid THEN 'outgoing' ELSE 'incoming' END,
      'responded_at', c.responded_at) END);
END;
$$;

CREATE OR REPLACE FUNCTION public.community_search_people(
  p_query TEXT DEFAULT NULL,
  p_min_bucket INT DEFAULT NULL,
  p_max_bucket INT DEFAULT NULL,
  p_experience TEXT[] DEFAULT NULL,
  p_interests TEXT[] DEFAULT NULL,
  p_district TEXT DEFAULT NULL,
  p_verified_only BOOLEAN DEFAULT FALSE,
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0)
RETURNS TABLE (
  user_id UUID, display_name TEXT, photo_path TEXT, contribution_bucket INT, contribution_label TEXT,
  experience TEXT, interests TEXT[], district TEXT, bio TEXT, phone_verified BOOLEAN, phone TEXT,
  member_since TIMESTAMPTZ, connection_status TEXT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
#variable_conflict use_column
DECLARE
  v_uid UUID := public._cg_uid();
  v_query TEXT := NULLIF(btrim(p_query), '');
  v_require_verified BOOLEAN := public._cg_require_phone_verification();
BEGIN
  RETURN QUERY
  SELECT cp.user_id, cp.display_name, cp.photo_path,
         public.cg_contribution_bucket(cp.max_contribution),
         public.cg_contribution_label(cp.max_contribution),
         cp.experience, cp.interests, cp.district, cp.bio, cp.phone_verified,
         public._cg_phone_for(v_uid, cp.user_id),
         p.created_at,
         (SELECT c.status FROM public.connections c
          WHERE LEAST(c.requester_id, c.addressee_id) = LEAST(v_uid, cp.user_id)
            AND GREATEST(c.requester_id, c.addressee_id) = GREATEST(v_uid, cp.user_id))
  FROM public.community_profiles cp
  JOIN public.profiles p ON p.id = cp.user_id
  WHERE cp.available_for_groups
    AND cp.user_id <> v_uid
    AND (NOT v_require_verified OR cp.phone_verified)
    AND NOT public._cg_blocked(v_uid, cp.user_id)
    AND (v_query IS NULL OR cp.display_name ILIKE '%' || public._cg_escape_like(v_query) || '%')
    AND (p_min_bucket IS NULL OR public.cg_contribution_bucket(cp.max_contribution) >= p_min_bucket)
    AND (p_max_bucket IS NULL OR public.cg_contribution_bucket(cp.max_contribution) <= p_max_bucket)
    AND (p_experience IS NULL OR cardinality(p_experience) = 0 OR cp.experience = ANY (p_experience))
    AND (p_interests IS NULL OR cardinality(p_interests) = 0 OR cp.interests && p_interests)
    AND (NULLIF(p_district, '') IS NULL OR cp.district = p_district)
    AND (NOT COALESCE(p_verified_only, FALSE) OR cp.phone_verified)
  ORDER BY cp.phone_verified DESC, cp.last_active_at DESC, cp.user_id
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50)
  OFFSET GREATEST(COALESCE(p_offset, 0), 0);
END;
$$;

-- ------------------------------------------------------------
-- 8. Connections, blocks, reports
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.connection_request(p_user UUID, p_message TEXT DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  v_message TEXT := NULLIF(btrim(p_message), '');
  c public.connections;
  v_id UUID;
BEGIN
  IF p_user = v_uid THEN RAISE EXCEPTION 'cannot_connect_self'; END IF;
  IF v_message IS NOT NULL AND char_length(v_message) > 150 THEN RAISE EXCEPTION 'message_too_long'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.community_profiles WHERE user_id = v_uid) THEN
    RAISE EXCEPTION 'profile_required';
  END IF;
  -- Hidden, blocked and unknown users all look the same to the caller.
  IF public._cg_blocked(v_uid, p_user) OR NOT (
      public._cg_share_group(v_uid, p_user)
      OR EXISTS (SELECT 1 FROM public.community_profiles cp
                 WHERE cp.user_id = p_user AND cp.available_for_groups
                   AND (NOT public._cg_require_phone_verification() OR cp.phone_verified))) THEN
    RAISE EXCEPTION 'user_unavailable';
  END IF;

  SELECT * INTO c FROM public.connections
  WHERE LEAST(requester_id, addressee_id) = LEAST(v_uid, p_user)
    AND GREATEST(requester_id, addressee_id) = GREATEST(v_uid, p_user)
  FOR UPDATE;

  IF c.id IS NOT NULL THEN
    IF c.status = 'accepted' THEN RAISE EXCEPTION 'already_connected'; END IF;
    IF c.status = 'pending' AND c.requester_id = v_uid THEN RAISE EXCEPTION 'request_already_sent'; END IF;
    IF c.status = 'pending' THEN
      -- They already asked us: accept.
      UPDATE public.connections SET status = 'accepted', responded_at = NOW() WHERE id = c.id;
      PERFORM public._cg_notify(p_user, 'connection_accepted',
        public._cg_name(v_uid) || ' accepted your connection request', NULL, NULL, jsonb_build_object('user_id', v_uid));
      RETURN c.id;
    END IF;
    IF c.status = 'declined' AND c.requester_id = v_uid AND c.responded_at > NOW() - INTERVAL '7 days' THEN
      RAISE EXCEPTION 'declined_recently';
    END IF;
  END IF;

  IF (SELECT COUNT(*) FROM public.connections WHERE requester_id = v_uid AND status = 'pending') >= 20 THEN
    RAISE EXCEPTION 'too_many_pending_requests';
  END IF;

  IF c.id IS NOT NULL THEN
    UPDATE public.connections
    SET requester_id = v_uid, addressee_id = p_user, status = 'pending', message = v_message,
        created_at = NOW(), responded_at = NULL
    WHERE id = c.id;
    v_id := c.id;
  ELSE
    INSERT INTO public.connections (requester_id, addressee_id, message)
    VALUES (v_uid, p_user, v_message) RETURNING id INTO v_id;
  END IF;

  PERFORM public._cg_notify(p_user, 'connection_request',
    public._cg_name(v_uid) || ' wants to connect', v_message, NULL,
    jsonb_build_object('connection_id', v_id, 'user_id', v_uid));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.connection_respond(p_connection UUID, p_accept BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  c public.connections;
BEGIN
  SELECT * INTO c FROM public.connections WHERE id = p_connection FOR UPDATE;
  IF NOT FOUND OR c.addressee_id <> v_uid THEN RAISE EXCEPTION 'request_not_found'; END IF;
  IF c.status <> 'pending' THEN RAISE EXCEPTION 'request_not_pending'; END IF;
  UPDATE public.connections
  SET status = CASE WHEN p_accept THEN 'accepted' ELSE 'declined' END, responded_at = NOW()
  WHERE id = c.id;
  IF p_accept THEN
    PERFORM public._cg_notify(c.requester_id, 'connection_accepted',
      public._cg_name(v_uid) || ' accepted your connection request', NULL, NULL, jsonb_build_object('user_id', v_uid));
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.connection_cancel(p_connection UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_uid UUID := public._cg_uid();
BEGIN
  UPDATE public.connections SET status = 'cancelled', responded_at = NOW()
  WHERE id = p_connection AND requester_id = v_uid AND status = 'pending';
  IF NOT FOUND THEN RAISE EXCEPTION 'request_not_found'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.connection_remove(p_user UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_uid UUID := public._cg_uid();
BEGIN
  -- Ends the connection (cancelled); either side may ask again later.
  UPDATE public.connections SET status = 'cancelled', responded_at = NOW()
  WHERE LEAST(requester_id, addressee_id) = LEAST(v_uid, p_user)
    AND GREATEST(requester_id, addressee_id) = GREATEST(v_uid, p_user)
    AND status = 'accepted';
END;
$$;

-- Connections and requests in both directions, with the other person's
-- profile (phone included once accepted).
CREATE OR REPLACE FUNCTION public.community_list_connections()
RETURNS TABLE (
  connection_id UUID, user_id UUID, display_name TEXT, photo_path TEXT, phone TEXT,
  phone_verified BOOLEAN, experience TEXT, district TEXT, status TEXT, direction TEXT,
  message TEXT, created_at TIMESTAMPTZ, responded_at TIMESTAMPTZ)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
#variable_conflict use_column
DECLARE v_uid UUID := public._cg_uid();
BEGIN
  RETURN QUERY
  SELECT c.id, o.other, public._cg_name(o.other), cp.photo_path,
         CASE WHEN c.status = 'accepted' THEN public._cg_phone_for(v_uid, o.other) END,
         COALESCE(cp.phone_verified, FALSE), cp.experience, cp.district, c.status,
         CASE WHEN c.requester_id = v_uid THEN 'outgoing' ELSE 'incoming' END,
         c.message, c.created_at, c.responded_at
  FROM public.connections c
  CROSS JOIN LATERAL (SELECT CASE WHEN c.requester_id = v_uid THEN c.addressee_id ELSE c.requester_id END AS other) o
  LEFT JOIN public.community_profiles cp ON cp.user_id = o.other
  WHERE v_uid IN (c.requester_id, c.addressee_id)
    AND c.status IN ('pending', 'accepted')
    AND NOT public._cg_blocked(v_uid, o.other)
  ORDER BY c.status, c.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.community_block(p_user UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_uid UUID := public._cg_uid();
BEGIN
  IF p_user = v_uid THEN RAISE EXCEPTION 'cannot_block_self'; END IF;
  INSERT INTO public.blocks (blocker_id, blocked_id) VALUES (v_uid, p_user)
  ON CONFLICT (blocker_id, blocked_id) DO UPDATE SET unblocked_at = NULL, created_at = NOW();
  UPDATE public.connections SET status = 'cancelled', responded_at = NOW()
  WHERE LEAST(requester_id, addressee_id) = LEAST(v_uid, p_user)
    AND GREATEST(requester_id, addressee_id) = GREATEST(v_uid, p_user)
    AND status IN ('pending', 'accepted');
  UPDATE public.group_invites SET status = 'cancelled', responded_at = NOW()
  WHERE status = 'pending'
    AND ((inviter_id = v_uid AND invitee_id = p_user) OR (inviter_id = p_user AND invitee_id = v_uid));
END;
$$;

CREATE OR REPLACE FUNCTION public.community_unblock(p_user UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.blocks SET unblocked_at = NOW()
  WHERE blocker_id = public._cg_uid() AND blocked_id = p_user AND unblocked_at IS NULL;
END;
$$;

-- People I blocked (their profiles are otherwise hidden from me).
CREATE OR REPLACE FUNCTION public.community_list_blocked()
RETURNS TABLE (user_id UUID, display_name TEXT, blocked_at TIMESTAMPTZ)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT b.blocked_id, public._cg_name(b.blocked_id), b.created_at
  FROM public.blocks b WHERE b.blocker_id = auth.uid() AND b.unblocked_at IS NULL
  ORDER BY b.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION public.community_report(
  p_target_type TEXT,
  p_reason TEXT,
  p_details TEXT DEFAULT NULL,
  p_target_user UUID DEFAULT NULL,
  p_target_group UUID DEFAULT NULL,
  p_target_message UUID DEFAULT NULL,
  p_is_scam BOOLEAN DEFAULT FALSE)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  v_group UUID := p_target_group;
  v_user UUID := p_target_user;
  v_id UUID;
BEGIN
  IF (SELECT COUNT(*) FROM public.reports WHERE reporter_id = v_uid AND created_at > NOW() - INTERVAL '1 day') >= 20 THEN
    RAISE EXCEPTION 'too_many_reports';
  END IF;
  IF p_target_type = 'message' THEN
    SELECT group_id, sender_id INTO v_group, v_user FROM public.group_messages WHERE id = p_target_message;
    IF v_group IS NULL OR NOT public.cg_is_member(v_group) THEN RAISE EXCEPTION 'message_not_found'; END IF;
  ELSIF p_target_type = 'group' THEN
    IF NOT EXISTS (SELECT 1 FROM public.groups WHERE id = p_target_group) THEN RAISE EXCEPTION 'group_not_found'; END IF;
  ELSIF p_target_type = 'user' THEN
    IF p_target_user IS NULL OR p_target_user = v_uid THEN RAISE EXCEPTION 'invalid_report_target'; END IF;
  ELSE
    RAISE EXCEPTION 'invalid_report_target';
  END IF;
  INSERT INTO public.reports (reporter_id, target_type, target_user_id, target_group_id, target_message_id,
                              reason, details, is_scam_report)
  VALUES (v_uid, p_target_type, v_user, v_group, p_target_message,
          CASE WHEN COALESCE(p_is_scam, FALSE) THEN 'scam' ELSE p_reason END,
          NULLIF(btrim(p_details), ''), COALESCE(p_is_scam, FALSE) OR p_reason = 'scam')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- ------------------------------------------------------------
-- 9. Groups: create, discover, join, roles, leave
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.group_create(
  p_type TEXT,
  p_name TEXT,
  p_description TEXT DEFAULT NULL,
  p_photo_path TEXT DEFAULT NULL,
  p_max_members INT DEFAULT 10,
  p_discoverable BOOLEAN DEFAULT TRUE,
  p_join_approval TEXT DEFAULT 'leader',
  p_rules TEXT DEFAULT '',
  p_voting_method TEXT DEFAULT 'one_member_one_vote',
  p_district TEXT DEFAULT NULL,
  p_seettu JSONB DEFAULT NULL,
  p_investment JSONB DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  v_id UUID;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.community_profiles WHERE user_id = v_uid) THEN RAISE EXCEPTION 'profile_required'; END IF;
  IF NOT public._cg_age_ok(v_uid) THEN RAISE EXCEPTION 'age_confirmation_required'; END IF;
  IF (SELECT COUNT(*) FROM public.group_members m JOIN public.groups g ON g.id = m.group_id
      WHERE m.user_id = v_uid AND m.role = 'leader' AND m.status = 'active' AND g.status <> 'closed') >= 5 THEN
    RAISE EXCEPTION 'too_many_groups_led';
  END IF;
  IF p_type = 'seettu' AND p_seettu IS NULL THEN RAISE EXCEPTION 'seettu_settings_required'; END IF;
  IF p_type = 'investment' AND p_investment IS NULL THEN RAISE EXCEPTION 'investment_settings_required'; END IF;

  BEGIN
    INSERT INTO public.groups (type, name, description, photo_path, district, max_members, discoverable,
                               join_approval, rules, voting_method, created_by)
    VALUES (p_type, btrim(p_name), NULLIF(btrim(p_description), ''), NULL, NULLIF(btrim(p_district), ''),
            p_max_members, COALESCE(p_discoverable, TRUE), COALESCE(p_join_approval, 'leader'),
            COALESCE(btrim(p_rules), ''), COALESCE(p_voting_method, 'one_member_one_vote'), v_uid)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'group_name_taken';
  END;
  -- Photos are uploaded under group-photos/<group id>/ after creation.
  IF NULLIF(btrim(p_photo_path), '') IS NOT NULL THEN
    UPDATE public.groups SET photo_path = p_photo_path WHERE id = v_id AND p_photo_path LIKE 'group-photos/' || v_id::TEXT || '/%';
  END IF;

  INSERT INTO public.group_members (group_id, user_id, role, rules_accepted_at, seettu_confirmed_at)
  VALUES (v_id, v_uid, 'leader', NOW(), NULL);

  IF p_type = 'seettu' THEN
    INSERT INTO public.seettu_settings (group_id, contribution, frequency, start_date, due_day,
                                        payout_method, draw_mode, late_rule, late_fee)
    VALUES (v_id, (p_seettu->>'contribution')::NUMERIC, p_seettu->>'frequency',
            (p_seettu->>'start_date')::DATE, (p_seettu->>'due_day')::INT,
            p_seettu->>'payout_method', COALESCE(p_seettu->>'draw_mode', 'all'),
            NULLIF(btrim(p_seettu->>'late_rule'), ''), (p_seettu->>'late_fee')::NUMERIC);
    IF (p_seettu->>'start_date')::DATE < CURRENT_DATE THEN RAISE EXCEPTION 'start_date_passed'; END IF;
  ELSE
    INSERT INTO public.investment_settings (group_id, purpose, target_amount, min_contribution, max_contribution,
      allowed_types, risk_level, distribution_rule, lock_in_months, exit_rule, exit_payout_method,
      early_exit_penalty_pct, decision_threshold, proposals_by, exit_approval)
    VALUES (v_id, NULLIF(btrim(p_investment->>'purpose'), ''), (p_investment->>'target_amount')::NUMERIC,
      COALESCE((p_investment->>'min_contribution')::NUMERIC, 1000), (p_investment->>'max_contribution')::NUMERIC,
      CASE WHEN jsonb_typeof(p_investment->'allowed_types') = 'array'
           THEN ARRAY(SELECT jsonb_array_elements_text(p_investment->'allowed_types'))
           ELSE ARRAY['cse', 'fd', 'gold', 'gov_securities'] END,
      COALESCE(p_investment->>'risk_level', 'low'), COALESCE(p_investment->>'distribution_rule', 'pro_rata'),
      COALESCE((p_investment->>'lock_in_months')::INT, 0), NULLIF(btrim(p_investment->>'exit_rule'), ''),
      COALESCE(p_investment->>'exit_payout_method', 'share_of_value'),
      COALESCE((p_investment->>'early_exit_penalty_pct')::NUMERIC, 0),
      COALESCE((p_investment->>'decision_threshold')::NUMERIC, 0),
      COALESCE(p_investment->>'proposals_by', 'any'), COALESCE(p_investment->>'exit_approval', 'leader'));
  END IF;

  PERFORM public._cg_log(v_id, v_uid, 'group_created', jsonb_build_object('type', p_type, 'name', btrim(p_name)));
  PERFORM public._cg_system_message(v_id, public._cg_name(v_uid) || ' created the group.');
  RETURN v_id;
END;
$$;

-- Details that don't need a vote. Rules, approval method, quorum and
-- voting method change through group_start_vote.
CREATE OR REPLACE FUNCTION public.group_update_details(
  p_group UUID,
  p_description TEXT DEFAULT NULL,
  p_photo_path TEXT DEFAULT NULL,
  p_discoverable BOOLEAN DEFAULT NULL,
  p_district TEXT DEFAULT NULL,
  p_max_members INT DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  g public.groups;
BEGIN
  PERFORM public._cg_require_member(p_group, ARRAY['leader', 'co_leader']);
  g := public._cg_group_for_update(p_group);
  IF g.status = 'closed' THEN RAISE EXCEPTION 'group_read_only'; END IF;
  IF p_photo_path IS NOT NULL AND p_photo_path <> '' AND p_photo_path NOT LIKE 'group-photos/' || p_group::TEXT || '/%' THEN
    RAISE EXCEPTION 'invalid_photo_path';
  END IF;
  IF p_max_members IS NOT NULL THEN
    IF p_max_members < public._cg_active_count(p_group) THEN RAISE EXCEPTION 'max_below_member_count'; END IF;
    IF g.type = 'seettu' AND g.status <> 'forming' THEN RAISE EXCEPTION 'seettu_already_started'; END IF;
  END IF;
  UPDATE public.groups SET
    description = COALESCE(NULLIF(btrim(p_description), ''), description),
    photo_path = CASE WHEN p_photo_path IS NULL THEN photo_path ELSE NULLIF(p_photo_path, '') END,
    discoverable = COALESCE(p_discoverable, discoverable),
    district = CASE WHEN p_district IS NULL THEN district ELSE NULLIF(btrim(p_district), '') END,
    max_members = COALESCE(p_max_members, max_members),
    updated_at = NOW()
  WHERE id = p_group;
  PERFORM public._cg_log(p_group, v_uid, 'details_updated', jsonb_strip_nulls(jsonb_build_object(
    'discoverable', p_discoverable, 'district', p_district, 'max_members', p_max_members,
    'description_changed', p_description IS NOT NULL, 'photo_changed', p_photo_path IS NOT NULL)));
END;
$$;

-- Seettu terms can change only while forming; everyone re-confirms.
CREATE OR REPLACE FUNCTION public.seettu_update_settings(p_group UUID, p_settings JSONB)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  g public.groups;
BEGIN
  PERFORM public._cg_require_member(p_group, ARRAY['leader', 'co_leader']);
  g := public._cg_group_for_update(p_group);
  IF g.type <> 'seettu' THEN RAISE EXCEPTION 'not_a_seettu'; END IF;
  IF g.status <> 'forming' THEN RAISE EXCEPTION 'seettu_already_started'; END IF;
  IF (p_settings->>'start_date')::DATE < CURRENT_DATE THEN RAISE EXCEPTION 'start_date_passed'; END IF;
  UPDATE public.seettu_settings SET
    contribution = COALESCE((p_settings->>'contribution')::NUMERIC, contribution),
    frequency = COALESCE(p_settings->>'frequency', frequency),
    start_date = COALESCE((p_settings->>'start_date')::DATE, start_date),
    due_day = COALESCE((p_settings->>'due_day')::INT, due_day),
    payout_method = COALESCE(p_settings->>'payout_method', payout_method),
    draw_mode = COALESCE(p_settings->>'draw_mode', draw_mode),
    late_rule = CASE WHEN p_settings ? 'late_rule' THEN NULLIF(btrim(p_settings->>'late_rule'), '') ELSE late_rule END,
    late_fee = CASE WHEN p_settings ? 'late_fee' THEN (p_settings->>'late_fee')::NUMERIC ELSE late_fee END
  WHERE group_id = p_group;
  UPDATE public.group_members SET seettu_confirmed_at = NULL WHERE group_id = p_group;
  PERFORM public._cg_log(p_group, v_uid, 'seettu_settings_changed', p_settings);
  PERFORM public._cg_system_message(p_group, 'The seettu terms changed. Every member needs to confirm them again.');
END;
$$;

-- Summary a non-member may see: discoverable groups, or ones they were
-- invited to or asked to join. Includes the rules to accept before joining.
CREATE OR REPLACE FUNCTION public.community_group_summary(p_group UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  g public.groups;
  v_leader UUID;
BEGIN
  SELECT * INTO g FROM public.groups WHERE id = p_group;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT user_id INTO v_leader FROM public.group_members WHERE group_id = p_group AND role = 'leader' AND status = 'active';
  IF NOT (public.cg_is_member(p_group)
          OR (g.discoverable AND g.status <> 'closed' AND NOT public._cg_blocked(v_uid, v_leader))
          OR EXISTS (SELECT 1 FROM public.group_invites WHERE group_id = p_group AND invitee_id = v_uid AND status = 'pending')
          OR EXISTS (SELECT 1 FROM public.group_join_requests WHERE group_id = p_group AND user_id = v_uid AND status = 'pending')) THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object(
    'id', g.id, 'type', g.type, 'name', g.name, 'description', g.description, 'photo_path', g.photo_path,
    'district', g.district, 'max_members', g.max_members, 'member_count', public._cg_active_count(g.id),
    'discoverable', g.discoverable, 'join_approval', g.join_approval, 'rules', g.rules,
    'voting_method', g.voting_method, 'quorum_pct', g.quorum_pct, 'pass_threshold', g.pass_threshold,
    'status', g.status, 'created_at', g.created_at,
    'leader', jsonb_build_object('user_id', v_leader, 'display_name', public._cg_name(v_leader),
      'experience', (SELECT experience FROM public.community_profiles WHERE user_id = v_leader),
      'trust', public._cg_trust(v_leader)),
    'warnings', to_jsonb(public._cg_group_warnings(g.id)),
    'seettu', (SELECT to_jsonb(s) - 'group_id' FROM public.seettu_settings s WHERE s.group_id = g.id),
    'investment', (SELECT to_jsonb(i) - 'group_id' FROM public.investment_settings i WHERE i.group_id = g.id),
    'is_member', public.cg_is_member(g.id),
    'my_request', (SELECT jsonb_build_object('id', id, 'status', status) FROM public.group_join_requests
                   WHERE group_id = g.id AND user_id = v_uid ORDER BY created_at DESC LIMIT 1),
    'my_invite', (SELECT jsonb_build_object('id', id, 'status', status) FROM public.group_invites
                  WHERE group_id = g.id AND invitee_id = v_uid AND status = 'pending' LIMIT 1));
END;
$$;

CREATE OR REPLACE FUNCTION public.community_search_groups(
  p_query TEXT DEFAULT NULL,
  p_type TEXT DEFAULT NULL,
  p_min_amount NUMERIC DEFAULT NULL,
  p_max_amount NUMERIC DEFAULT NULL,
  p_frequency TEXT DEFAULT NULL,
  p_open_only BOOLEAN DEFAULT FALSE,
  p_district TEXT DEFAULT NULL,
  p_leader_experience TEXT[] DEFAULT NULL,
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0)
RETURNS TABLE (
  group_id UUID, type TEXT, name TEXT, description TEXT, photo_path TEXT, district TEXT,
  member_count INT, max_members INT, contribution NUMERIC, min_contribution NUMERIC,
  max_contribution NUMERIC, frequency TEXT, leader_id UUID, leader_name TEXT,
  leader_experience TEXT, status TEXT, is_open BOOLEAN, is_member BOOLEAN,
  my_request_status TEXT, warnings TEXT[])
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
#variable_conflict use_column
DECLARE
  v_uid UUID := public._cg_uid();
  v_query TEXT := NULLIF(btrim(p_query), '');
BEGIN
  RETURN QUERY
  WITH base AS (
    SELECT g.*, lm.user_id AS leader, public._cg_active_count(g.id) AS members,
           s.contribution AS s_contribution, s.frequency AS s_frequency,
           i.min_contribution AS i_min, i.max_contribution AS i_max
    FROM public.groups g
    JOIN public.group_members lm ON lm.group_id = g.id AND lm.role = 'leader' AND lm.status = 'active'
    LEFT JOIN public.seettu_settings s ON s.group_id = g.id
    LEFT JOIN public.investment_settings i ON i.group_id = g.id
    WHERE g.discoverable AND g.status <> 'closed'
      AND (p_type IS NULL OR g.type = p_type)
      AND (v_query IS NULL OR g.name ILIKE '%' || public._cg_escape_like(v_query) || '%')
      AND (NULLIF(p_district, '') IS NULL OR g.district = p_district)
      AND NOT public._cg_blocked(v_uid, lm.user_id)
  )
  SELECT b.id, b.type, b.name, b.description, b.photo_path, b.district, b.members, b.max_members,
         b.s_contribution, b.i_min, b.i_max, b.s_frequency, b.leader, public._cg_name(b.leader),
         lcp.experience, b.status,
         (b.members < b.max_members AND (b.status = 'forming' OR b.type = 'investment')),
         public.cg_is_member(b.id),
         (SELECT r.status FROM public.group_join_requests r
          WHERE r.group_id = b.id AND r.user_id = v_uid ORDER BY r.created_at DESC LIMIT 1),
         public._cg_group_warnings(b.id)
  FROM base b
  LEFT JOIN public.community_profiles lcp ON lcp.user_id = b.leader
  WHERE (p_frequency IS NULL OR b.s_frequency = p_frequency)
    AND (p_min_amount IS NULL OR COALESCE(b.s_contribution, b.i_max, 'Infinity'::NUMERIC) >= p_min_amount)
    AND (p_max_amount IS NULL OR COALESCE(b.s_contribution, b.i_min) <= p_max_amount)
    AND (NOT COALESCE(p_open_only, FALSE)
         OR (b.members < b.max_members AND (b.status = 'forming' OR b.type = 'investment')))
    AND (p_leader_experience IS NULL OR cardinality(p_leader_experience) = 0
         OR lcp.experience = ANY (p_leader_experience))
  ORDER BY (b.members < b.max_members) DESC, b.created_at DESC, b.id
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50)
  OFFSET GREATEST(COALESCE(p_offset, 0), 0);
END;
$$;

-- Adds or re-activates a member. Caller has checked permissions.
CREATE OR REPLACE FUNCTION public._cg_add_member(p_group UUID, p_user UUID, p_rules_accepted_at TIMESTAMPTZ, p_actor UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE g public.groups;
BEGIN
  g := public._cg_group_for_update(p_group);
  IF g.status = 'closed' OR (g.type = 'seettu' AND g.status <> 'forming') THEN RAISE EXCEPTION 'group_not_open'; END IF;
  IF public._cg_active_count(p_group) >= g.max_members THEN RAISE EXCEPTION 'group_full'; END IF;
  INSERT INTO public.group_members (group_id, user_id, role, status, rules_accepted_at)
  VALUES (p_group, p_user, 'member', 'active', p_rules_accepted_at)
  ON CONFLICT (group_id, user_id) DO UPDATE SET
    role = 'member', status = 'active', joined_at = NOW(), rules_accepted_at = EXCLUDED.rules_accepted_at,
    seettu_confirmed_at = NULL, payout_position = NULL, left_at = NULL, removal_reason = NULL,
    last_read_at = NOW(), last_active_at = NOW();
  UPDATE public.group_invites SET status = 'accepted', responded_at = NOW()
  WHERE group_id = p_group AND invitee_id = p_user AND status = 'pending';
  PERFORM public._cg_log(p_group, p_actor, 'member_joined', jsonb_build_object('user_id', p_user));
  PERFORM public._cg_system_message(p_group, public._cg_name(p_user) || ' joined the group.');
END;
$$;

CREATE OR REPLACE FUNCTION public.group_request_join(p_group UUID, p_message TEXT DEFAULT NULL, p_accept_rules BOOLEAN DEFAULT FALSE)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  g public.groups;
  v_leader UUID;
  v_id UUID;
  v_vote UUID;
BEGIN
  IF NOT COALESCE(p_accept_rules, FALSE) THEN RAISE EXCEPTION 'rules_not_accepted'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.community_profiles WHERE user_id = v_uid) THEN RAISE EXCEPTION 'profile_required'; END IF;
  IF NOT public._cg_age_ok(v_uid) THEN RAISE EXCEPTION 'age_confirmation_required'; END IF;
  IF p_message IS NOT NULL AND char_length(btrim(p_message)) > 300 THEN RAISE EXCEPTION 'message_too_long'; END IF;
  g := public._cg_group_for_update(p_group);
  SELECT user_id INTO v_leader FROM public.group_members WHERE group_id = p_group AND role = 'leader' AND status = 'active';
  IF public.cg_is_member(p_group) THEN RAISE EXCEPTION 'already_member'; END IF;
  IF public._cg_blocked(v_uid, v_leader) THEN RAISE EXCEPTION 'group_unavailable'; END IF;
  IF NOT g.discoverable AND NOT EXISTS (
      SELECT 1 FROM public.group_invites WHERE group_id = p_group AND invitee_id = v_uid AND status = 'pending') THEN
    RAISE EXCEPTION 'group_unavailable';
  END IF;
  IF g.status = 'closed' OR (g.type = 'seettu' AND g.status <> 'forming') THEN RAISE EXCEPTION 'group_not_open'; END IF;
  IF public._cg_active_count(p_group) >= g.max_members THEN RAISE EXCEPTION 'group_full'; END IF;
  IF EXISTS (SELECT 1 FROM public.group_join_requests WHERE group_id = p_group AND user_id = v_uid AND status = 'pending') THEN
    RAISE EXCEPTION 'request_already_sent';
  END IF;
  IF (SELECT COUNT(*) FROM public.group_join_requests WHERE user_id = v_uid AND status = 'pending') >= 10 THEN
    RAISE EXCEPTION 'too_many_pending_requests';
  END IF;

  INSERT INTO public.group_join_requests (group_id, user_id, message, rules_accepted_at)
  VALUES (p_group, v_uid, NULLIF(btrim(p_message), ''), NOW())
  RETURNING id INTO v_id;

  IF g.join_approval = 'vote' THEN
    v_vote := public._cg_open_vote(p_group, 'join_request', 'Accept ' || public._cg_name(v_uid) || ' into the group?',
      NULLIF(btrim(p_message), ''), jsonb_build_object('request_id', v_id, 'user_id', v_uid), v_uid);
    UPDATE public.group_join_requests SET vote_id = v_vote WHERE id = v_id;
  ELSE
    PERFORM public._cg_notify_members(p_group, 'join_request', public._cg_name(v_uid) || ' asked to join ' || g.name,
      NULLIF(btrim(p_message), ''), jsonb_build_object('request_id', v_id, 'user_id', v_uid), NULL,
      ARRAY['leader', 'co_leader']);
  END IF;
  PERFORM public._cg_log(p_group, v_uid, 'join_requested', jsonb_build_object('request_id', v_id));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.group_decide_join(p_request UUID, p_approve BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  r public.group_join_requests;
  v_name TEXT;
BEGIN
  SELECT * INTO r FROM public.group_join_requests WHERE id = p_request FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'request_not_found'; END IF;
  PERFORM public._cg_require_member(r.group_id, ARRAY['leader', 'co_leader']);
  IF r.status <> 'pending' THEN RAISE EXCEPTION 'request_not_pending'; END IF;
  IF r.vote_id IS NOT NULL THEN RAISE EXCEPTION 'decided_by_vote'; END IF;
  SELECT name INTO v_name FROM public.groups WHERE id = r.group_id;
  IF p_approve THEN
    PERFORM public._cg_add_member(r.group_id, r.user_id, r.rules_accepted_at, v_uid);
  END IF;
  UPDATE public.group_join_requests
  SET status = CASE WHEN p_approve THEN 'approved' ELSE 'declined' END, decided_by = v_uid, decided_at = NOW()
  WHERE id = r.id;
  PERFORM public._cg_log(r.group_id, v_uid, CASE WHEN p_approve THEN 'join_approved' ELSE 'join_declined' END,
    jsonb_build_object('user_id', r.user_id));
  PERFORM public._cg_notify(r.user_id, 'join_decision',
    CASE WHEN p_approve THEN 'You joined ' || v_name ELSE 'Your request to join ' || v_name || ' was declined' END,
    NULL, CASE WHEN p_approve THEN r.group_id END, jsonb_build_object('request_id', r.id, 'approved', p_approve));
END;
$$;

CREATE OR REPLACE FUNCTION public.group_cancel_join_request(p_request UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  r public.group_join_requests;
BEGIN
  SELECT * INTO r FROM public.group_join_requests WHERE id = p_request AND user_id = v_uid FOR UPDATE;
  IF NOT FOUND OR r.status <> 'pending' THEN RAISE EXCEPTION 'request_not_found'; END IF;
  UPDATE public.group_join_requests SET status = 'cancelled', decided_at = NOW() WHERE id = r.id;
  UPDATE public.group_votes SET status = 'cancelled', closed_at = NOW(), result_note = 'Request withdrawn'
  WHERE id = r.vote_id AND status = 'open';
END;
$$;

CREATE OR REPLACE FUNCTION public.group_invite(p_group UUID, p_user UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  g public.groups;
  v_id UUID;
BEGIN
  PERFORM public._cg_require_member(p_group);
  SELECT * INTO g FROM public.groups WHERE id = p_group;
  IF g.status = 'closed' OR (g.type = 'seettu' AND g.status <> 'forming') THEN RAISE EXCEPTION 'group_not_open'; END IF;
  IF public._cg_active_count(p_group) >= g.max_members THEN RAISE EXCEPTION 'group_full'; END IF;
  IF EXISTS (SELECT 1 FROM public.group_members WHERE group_id = p_group AND user_id = p_user AND status = 'active') THEN
    RAISE EXCEPTION 'already_member';
  END IF;
  -- Connections can always be invited; others only while they're available.
  IF public._cg_blocked(v_uid, p_user) OR NOT (
      public._cg_connected(v_uid, p_user)
      OR EXISTS (SELECT 1 FROM public.community_profiles WHERE user_id = p_user AND available_for_groups)) THEN
    RAISE EXCEPTION 'user_unavailable';
  END IF;
  SELECT id INTO v_id FROM public.group_invites WHERE group_id = p_group AND invitee_id = p_user AND status = 'pending';
  IF v_id IS NOT NULL THEN RETURN v_id; END IF;
  IF (SELECT COUNT(*) FROM public.group_invites WHERE inviter_id = v_uid AND created_at > NOW() - INTERVAL '1 day') >= 30 THEN
    RAISE EXCEPTION 'too_many_invites';
  END IF;
  INSERT INTO public.group_invites (group_id, inviter_id, invitee_id) VALUES (p_group, v_uid, p_user) RETURNING id INTO v_id;
  PERFORM public._cg_notify(p_user, 'group_invite', public._cg_name(v_uid) || ' invited you to ' || g.name,
    NULL, NULL, jsonb_build_object('invite_id', v_id, 'group_id', p_group));
  PERFORM public._cg_log(p_group, v_uid, 'member_invited', jsonb_build_object('user_id', p_user));
  RETURN v_id;
END;
$$;

-- An invite from the leader or a co-leader joins directly; an invite from
-- another member becomes a join request.
CREATE OR REPLACE FUNCTION public.group_respond_invite(p_invite UUID, p_accept BOOLEAN, p_accept_rules BOOLEAN DEFAULT FALSE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  i public.group_invites;
  v_inviter_role TEXT;
  v_request UUID;
BEGIN
  SELECT * INTO i FROM public.group_invites WHERE id = p_invite AND invitee_id = v_uid FOR UPDATE;
  IF NOT FOUND OR i.status <> 'pending' THEN RAISE EXCEPTION 'invite_not_found'; END IF;
  IF NOT p_accept THEN
    UPDATE public.group_invites SET status = 'declined', responded_at = NOW() WHERE id = i.id;
    RETURN jsonb_build_object('status', 'declined');
  END IF;
  IF NOT COALESCE(p_accept_rules, FALSE) THEN RAISE EXCEPTION 'rules_not_accepted'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.community_profiles WHERE user_id = v_uid) THEN RAISE EXCEPTION 'profile_required'; END IF;
  IF NOT public._cg_age_ok(v_uid) THEN RAISE EXCEPTION 'age_confirmation_required'; END IF;
  SELECT role INTO v_inviter_role FROM public.group_members
  WHERE group_id = i.group_id AND user_id = i.inviter_id AND status = 'active';
  IF v_inviter_role IN ('leader', 'co_leader') THEN
    PERFORM public._cg_add_member(i.group_id, v_uid, NOW(), i.inviter_id);
    RETURN jsonb_build_object('status', 'joined', 'group_id', i.group_id);
  END IF;
  v_request := public.group_request_join(i.group_id, NULL, TRUE);
  UPDATE public.group_invites SET status = 'accepted', responded_at = NOW() WHERE id = i.id;
  RETURN jsonb_build_object('status', 'requested', 'request_id', v_request);
END;
$$;

-- Leader leaving or inactive: the longest-serving co-leader takes over;
-- otherwise the longest-serving member becomes interim leader and a
-- "confirm leader" vote opens.
CREATE OR REPLACE FUNCTION public._cg_replace_leader(p_group UUID, p_old_leader UUID, p_reason TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_new UUID;
  v_was_co BOOLEAN := TRUE;
BEGIN
  SELECT user_id INTO v_new FROM public.group_members
  WHERE group_id = p_group AND status = 'active' AND role = 'co_leader' AND user_id <> p_old_leader
  ORDER BY joined_at LIMIT 1;
  IF v_new IS NULL THEN
    v_was_co := FALSE;
    SELECT user_id INTO v_new FROM public.group_members
    WHERE group_id = p_group AND status = 'active' AND user_id <> p_old_leader
    ORDER BY joined_at LIMIT 1;
  END IF;
  UPDATE public.group_members SET role = 'member' WHERE group_id = p_group AND user_id = p_old_leader;
  IF v_new IS NULL THEN
    -- Nobody left to lead.
    UPDATE public.groups SET status = 'closed', closed_at = NOW(), updated_at = NOW() WHERE id = p_group;
    PERFORM public._cg_log(p_group, NULL, 'group_closed', jsonb_build_object('reason', 'no_members_left'));
    RETURN;
  END IF;
  UPDATE public.group_members SET role = 'leader' WHERE group_id = p_group AND user_id = v_new;
  PERFORM public._cg_log(p_group, NULL, 'leader_replaced',
    jsonb_build_object('old_leader', p_old_leader, 'new_leader', v_new, 'reason', p_reason, 'interim', NOT v_was_co));
  PERFORM public._cg_system_message(p_group, public._cg_name(v_new) || ' is now the leader ('
    || CASE WHEN v_was_co THEN 'co-leader took over' ELSE 'interim, a vote to confirm is open' END || ').');
  PERFORM public._cg_notify(v_new, 'role_changed', 'You are now the leader', NULL, p_group, '{}'::jsonb);
  IF NOT v_was_co AND public._cg_active_count(p_group) > 1 THEN
    PERFORM public._cg_open_vote(p_group, 'leader_change', 'Confirm ' || public._cg_name(v_new) || ' as leader',
      'The previous leader ' || CASE WHEN p_reason = 'inactive' THEN 'was inactive for 30 days' ELSE 'left' END
      || '. Vote no and start a new Change leader vote to choose someone else.',
      jsonb_build_object('new_leader', v_new), NULL);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.group_leave(p_group UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  v_role TEXT;
  g public.groups;
BEGIN
  v_role := public._cg_require_member(p_group);
  g := public._cg_group_for_update(p_group);
  IF g.type = 'seettu' AND g.status = 'active' THEN
    IF public._cg_seettu_must_complete(p_group, v_uid) THEN RAISE EXCEPTION 'must_complete_payments'; END IF;
    RAISE EXCEPTION 'seettu_in_progress';
  END IF;
  IF g.type = 'investment' AND g.status <> 'closed' AND EXISTS (
      SELECT 1 FROM public.group_contributions WHERE group_id = p_group AND user_id = v_uid AND status = 'confirmed')
     AND NOT EXISTS (
      SELECT 1 FROM public.group_exit_requests WHERE group_id = p_group AND user_id = v_uid AND status = 'completed') THEN
    RAISE EXCEPTION 'exit_request_required';
  END IF;
  UPDATE public.group_contributions SET status = 'cancelled'
  WHERE group_id = p_group AND user_id = v_uid AND status IN ('pledged', 'marked_paid');
  UPDATE public.group_members SET status = 'left', left_at = NOW(), role = 'member', payout_position = NULL,
    seettu_confirmed_at = NULL
  WHERE group_id = p_group AND user_id = v_uid;
  PERFORM public._cg_log(p_group, v_uid, 'member_left', '{}'::jsonb);
  PERFORM public._cg_system_message(p_group, public._cg_name(v_uid) || ' left the group.');
  IF v_role = 'leader' THEN PERFORM public._cg_replace_leader(p_group, v_uid, 'left'); END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.group_remove_member(p_group UUID, p_user UUID, p_reason TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  v_role TEXT;
  v_target_role TEXT;
BEGIN
  v_role := public._cg_require_member(p_group, ARRAY['leader', 'co_leader']);
  PERFORM public._cg_group_for_update(p_group);
  IF char_length(btrim(COALESCE(p_reason, ''))) < 3 THEN RAISE EXCEPTION 'reason_required'; END IF;
  IF p_user = v_uid THEN RAISE EXCEPTION 'use_leave_instead'; END IF;
  SELECT role INTO v_target_role FROM public.group_members WHERE group_id = p_group AND user_id = p_user AND status = 'active';
  IF v_target_role IS NULL THEN RAISE EXCEPTION 'not_group_member'; END IF;
  IF v_target_role = 'leader' THEN RAISE EXCEPTION 'cannot_remove_leader'; END IF;
  PERFORM public._cg_remove(p_group, p_user, btrim(p_reason), v_uid);
END;
$$;

CREATE OR REPLACE FUNCTION public._cg_remove(p_group UUID, p_user UUID, p_reason TEXT, p_actor UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_name TEXT;
BEGIN
  SELECT name INTO v_name FROM public.groups WHERE id = p_group;
  -- Records (payments, contributions) stay; only membership ends.
  UPDATE public.group_members SET status = 'removed', left_at = NOW(), removal_reason = left(p_reason, 500),
    role = 'member', payout_position = NULL
  WHERE group_id = p_group AND user_id = p_user AND status = 'active';
  UPDATE public.group_contributions SET status = 'cancelled'
  WHERE group_id = p_group AND user_id = p_user AND status IN ('pledged', 'marked_paid');
  PERFORM public._cg_log(p_group, p_actor, 'member_removed', jsonb_build_object('user_id', p_user, 'reason', p_reason));
  PERFORM public._cg_system_message(p_group, public._cg_name(p_user) || ' was removed from the group. Reason: ' || p_reason);
  PERFORM public._cg_notify(p_user, 'removed_from_group', 'You were removed from ' || v_name, p_reason, NULL,
    jsonb_build_object('group_id', p_group));
  PERFORM public._cg_notify_members(p_group, 'group_update', public._cg_name(p_user) || ' was removed from ' || v_name,
    p_reason, '{}'::jsonb, p_actor);
END;
$$;

CREATE OR REPLACE FUNCTION public.group_set_role(p_group UUID, p_user UUID, p_role TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  v_target_role TEXT;
  v_type TEXT;
BEGIN
  PERFORM public._cg_require_member(p_group, ARRAY['leader', 'co_leader']);
  IF p_role NOT IN ('co_leader', 'treasurer', 'member') THEN RAISE EXCEPTION 'invalid_role'; END IF;
  SELECT type INTO v_type FROM public.groups WHERE id = p_group;
  IF p_role = 'treasurer' AND v_type <> 'investment' THEN RAISE EXCEPTION 'treasurer_investment_only'; END IF;
  SELECT role INTO v_target_role FROM public.group_members WHERE group_id = p_group AND user_id = p_user AND status = 'active' FOR UPDATE;
  IF v_target_role IS NULL THEN RAISE EXCEPTION 'not_group_member'; END IF;
  IF v_target_role = 'leader' THEN RAISE EXCEPTION 'use_transfer_leadership'; END IF;
  IF v_target_role = p_role THEN RETURN; END IF;
  UPDATE public.group_members SET role = p_role WHERE group_id = p_group AND user_id = p_user;
  PERFORM public._cg_log(p_group, v_uid, 'role_changed', jsonb_build_object('user_id', p_user, 'from', v_target_role, 'to', p_role));
  PERFORM public._cg_system_message(p_group, public._cg_name(p_user) || ' is now ' || replace(p_role, '_', '-') || '.');
  PERFORM public._cg_notify(p_user, 'role_changed', 'Your role changed to ' || replace(p_role, '_', '-'), NULL, p_group, '{}'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.group_transfer_leadership(p_group UUID, p_user UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_uid UUID := public._cg_uid();
BEGIN
  PERFORM public._cg_require_member(p_group, ARRAY['leader']);
  PERFORM public._cg_group_for_update(p_group);
  IF p_user = v_uid THEN RETURN; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.group_members WHERE group_id = p_group AND user_id = p_user AND status = 'active') THEN
    RAISE EXCEPTION 'not_group_member';
  END IF;
  PERFORM public._cg_set_leader(p_group, p_user, v_uid, 'co_leader', 'transferred');
END;
$$;

CREATE OR REPLACE FUNCTION public._cg_set_leader(p_group UUID, p_new UUID, p_actor UUID, p_old_role TEXT, p_how TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_old UUID;
BEGIN
  SELECT user_id INTO v_old FROM public.group_members WHERE group_id = p_group AND role = 'leader' AND status = 'active';
  IF v_old = p_new THEN RETURN; END IF;
  UPDATE public.group_members SET role = p_old_role WHERE group_id = p_group AND user_id = v_old;
  UPDATE public.group_members SET role = 'leader' WHERE group_id = p_group AND user_id = p_new;
  PERFORM public._cg_log(p_group, p_actor, 'leader_changed', jsonb_build_object('from', v_old, 'to', p_new, 'how', p_how));
  PERFORM public._cg_system_message(p_group, public._cg_name(p_new) || ' is now the leader.');
  PERFORM public._cg_notify(p_new, 'role_changed', 'You are now the leader', NULL, p_group, '{}'::jsonb);
  PERFORM public._cg_notify(v_old, 'role_changed', 'You are no longer the leader', NULL, p_group, '{}'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.group_set_chat_muted(p_group UUID, p_muted BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM public._cg_require_member(p_group);
  UPDATE public.group_members SET chat_muted = COALESCE(p_muted, FALSE)
  WHERE group_id = p_group AND user_id = auth.uid();
END;
$$;

-- Expenditure integration preferences for this membership.
CREATE OR REPLACE FUNCTION public.group_set_expense_link(p_group UUID, p_recurring_expense UUID, p_log_payments BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM public._cg_require_member(p_group);
  UPDATE public.group_members
  SET recurring_expense_id = p_recurring_expense, log_payments_as_expenses = COALESCE(p_log_payments, FALSE)
  WHERE group_id = p_group AND user_id = auth.uid();
END;
$$;

-- ------------------------------------------------------------
-- 10. Group chat
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.group_send_message(
  p_group UUID, p_body TEXT DEFAULT NULL, p_image_path TEXT DEFAULT NULL, p_reply_to UUID DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  v_body TEXT := NULLIF(btrim(p_body), '');
  v_image TEXT := NULLIF(btrim(p_image_path), '');
  v_status TEXT;
  v_name TEXT;
  v_id UUID;
BEGIN
  PERFORM public._cg_require_member(p_group);
  SELECT status, name INTO v_status, v_name FROM public.groups WHERE id = p_group;
  IF v_status = 'closed' THEN RAISE EXCEPTION 'group_read_only'; END IF;
  IF v_body IS NULL AND v_image IS NULL THEN RAISE EXCEPTION 'empty_message'; END IF;
  IF char_length(v_body) > 2000 THEN RAISE EXCEPTION 'message_too_long'; END IF;
  IF public.cg_has_payment_details(v_body) THEN RAISE EXCEPTION 'payment_details_blocked'; END IF;
  IF v_image IS NOT NULL AND v_image NOT LIKE 'groups/' || p_group::TEXT || '/chat/%' THEN
    RAISE EXCEPTION 'invalid_attachment';
  END IF;
  IF p_reply_to IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.group_messages WHERE id = p_reply_to AND group_id = p_group) THEN
    RAISE EXCEPTION 'reply_not_found';
  END IF;
  -- Flood control: 15 messages a minute per group, 40 across all groups.
  IF (SELECT COUNT(*) FROM public.group_messages
      WHERE sender_id = v_uid AND group_id = p_group AND created_at > NOW() - INTERVAL '1 minute') >= 15
     OR (SELECT COUNT(*) FROM public.group_messages
      WHERE sender_id = v_uid AND created_at > NOW() - INTERVAL '1 minute') >= 40 THEN
    RAISE EXCEPTION 'slow_down';
  END IF;

  INSERT INTO public.group_messages (group_id, sender_id, body, image_path, reply_to)
  VALUES (p_group, v_uid, v_body, v_image, p_reply_to)
  RETURNING id INTO v_id;
  UPDATE public.group_members SET last_read_at = NOW() WHERE group_id = p_group AND user_id = v_uid;

  -- One unread chat notification per member per group, not one per message.
  INSERT INTO public.notifications (user_id, kind, title, body, group_id, data)
  SELECT m.user_id, 'chat_message', 'New messages in ' || v_name,
         public._cg_name(v_uid) || ': ' || COALESCE(left(v_body, 80), 'sent a photo'),
         p_group, jsonb_build_object('message_id', v_id)
  FROM public.group_members m
  WHERE m.group_id = p_group AND m.status = 'active' AND m.user_id <> v_uid AND NOT m.chat_muted
    AND NOT public._cg_blocked(m.user_id, v_uid)
    AND NOT EXISTS (SELECT 1 FROM public.notifications n
                    WHERE n.user_id = m.user_id AND n.group_id = p_group AND n.kind = 'chat_message' AND n.read_at IS NULL);
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.group_delete_message(p_message UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  m public.group_messages;
  v_role TEXT;
BEGIN
  SELECT * INTO m FROM public.group_messages WHERE id = p_message FOR UPDATE;
  IF NOT FOUND OR m.deleted_at IS NOT NULL THEN RAISE EXCEPTION 'message_not_found'; END IF;
  v_role := public._cg_require_member(m.group_id);
  IF m.is_system THEN RAISE EXCEPTION 'cannot_delete_system_message'; END IF;
  IF m.sender_id IS DISTINCT FROM v_uid AND v_role NOT IN ('leader', 'co_leader') THEN RAISE EXCEPTION 'not_group_officer'; END IF;
  UPDATE public.group_messages
  SET body = NULL, image_path = NULL, is_pinned = FALSE, deleted_at = NOW(), deleted_by = v_uid
  WHERE id = m.id;
  IF m.sender_id IS DISTINCT FROM v_uid THEN
    PERFORM public._cg_log(m.group_id, v_uid, 'message_removed', jsonb_build_object('message_id', m.id, 'sender_id', m.sender_id));
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.group_pin_message(p_message UUID, p_pinned BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_group UUID;
BEGIN
  SELECT group_id INTO v_group FROM public.group_messages WHERE id = p_message AND deleted_at IS NULL;
  IF v_group IS NULL THEN RAISE EXCEPTION 'message_not_found'; END IF;
  PERFORM public._cg_require_member(v_group, ARRAY['leader', 'co_leader']);
  UPDATE public.group_messages SET is_pinned = COALESCE(p_pinned, FALSE) WHERE id = p_message;
END;
$$;

CREATE OR REPLACE FUNCTION public.group_mark_read(p_group UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_uid UUID := public._cg_uid();
BEGIN
  UPDATE public.group_members SET last_read_at = NOW()
  WHERE group_id = p_group AND user_id = v_uid AND status = 'active';
  UPDATE public.notifications SET read_at = NOW()
  WHERE user_id = v_uid AND group_id = p_group AND kind = 'chat_message' AND read_at IS NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.community_unread_summary()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_uid UUID := public._cg_uid();
BEGIN
  RETURN jsonb_build_object(
    'notifications', (SELECT COUNT(*) FROM public.notifications WHERE user_id = v_uid AND read_at IS NULL),
    'incoming_requests', (SELECT COUNT(*) FROM public.connections WHERE addressee_id = v_uid AND status = 'pending'),
    'chats', COALESCE((
      SELECT jsonb_object_agg(m.group_id, (
        SELECT COUNT(*) FROM public.group_messages gm
        WHERE gm.group_id = m.group_id AND gm.created_at > m.last_read_at
          AND gm.sender_id IS DISTINCT FROM v_uid AND gm.deleted_at IS NULL))
      FROM public.group_members m WHERE m.user_id = v_uid AND m.status = 'active'), '{}'::jsonb));
END;
$$;

-- ------------------------------------------------------------
-- 11. Polls (informal)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.poll_create(
  p_group UUID, p_question TEXT, p_options TEXT[], p_multiple BOOLEAN DEFAULT FALSE,
  p_anonymous BOOLEAN DEFAULT FALSE, p_deadline TIMESTAMPTZ DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  v_deadline TIMESTAMPTZ := COALESCE(p_deadline, NOW() + INTERVAL '48 hours');
  v_options TEXT[];
  v_id UUID;
  i INT;
BEGIN
  PERFORM public._cg_require_member(p_group, ARRAY['leader', 'co_leader']);
  IF (SELECT status FROM public.groups WHERE id = p_group) = 'closed' THEN RAISE EXCEPTION 'group_read_only'; END IF;
  SELECT array_agg(o ORDER BY ord) INTO v_options
  FROM (SELECT DISTINCT ON (lower(btrim(x))) btrim(x) AS o, ord
        FROM unnest(p_options) WITH ORDINALITY AS t(x, ord)
        WHERE NULLIF(btrim(x), '') IS NOT NULL
        ORDER BY lower(btrim(x)), ord) d;
  IF COALESCE(cardinality(v_options), 0) NOT BETWEEN 2 AND 6 THEN RAISE EXCEPTION 'poll_needs_2_to_6_options'; END IF;
  IF v_deadline < NOW() + INTERVAL '10 minutes' OR v_deadline > NOW() + INTERVAL '30 days' THEN
    RAISE EXCEPTION 'invalid_deadline';
  END IF;
  INSERT INTO public.polls (group_id, created_by, question, multiple_choice, anonymous, deadline)
  VALUES (p_group, v_uid, btrim(p_question), COALESCE(p_multiple, FALSE), COALESCE(p_anonymous, FALSE), v_deadline)
  RETURNING id INTO v_id;
  FOR i IN 1..cardinality(v_options) LOOP
    INSERT INTO public.poll_options (poll_id, group_id, label, position) VALUES (v_id, p_group, v_options[i], i);
  END LOOP;
  PERFORM public._cg_system_message(p_group, public._cg_name(v_uid) || ' started a poll: ' || btrim(p_question));
  PERFORM public._cg_notify_members(p_group, 'poll_opened', 'New poll: ' || left(btrim(p_question), 80), NULL,
    jsonb_build_object('poll_id', v_id), v_uid);
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.poll_vote(p_poll UUID, p_option_ids UUID[])
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  p public.polls;
  v_count INT := COALESCE(cardinality(p_option_ids), 0);
BEGIN
  SELECT * INTO p FROM public.polls WHERE id = p_poll FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'poll_not_found'; END IF;
  PERFORM public._cg_require_member(p.group_id);
  IF p.closed_at IS NOT NULL OR p.deadline <= NOW() THEN RAISE EXCEPTION 'poll_closed'; END IF;
  IF v_count = 0 OR (NOT p.multiple_choice AND v_count > 1) THEN RAISE EXCEPTION 'invalid_choice'; END IF;
  IF (SELECT COUNT(DISTINCT id) FROM public.poll_options WHERE poll_id = p_poll AND id = ANY (p_option_ids)) <> v_count THEN
    RAISE EXCEPTION 'invalid_choice';
  END IF;
  UPDATE public.poll_votes SET retracted_at = NOW()
  WHERE poll_id = p_poll AND user_id = v_uid AND retracted_at IS NULL AND NOT (option_id = ANY (p_option_ids));
  INSERT INTO public.poll_votes (poll_id, option_id, group_id, user_id)
  SELECT p_poll, o, p.group_id, v_uid FROM unnest(p_option_ids) AS o
  ON CONFLICT (poll_id, option_id, user_id) DO UPDATE SET retracted_at = NULL;
  UPDATE public.poll_options o
  SET vote_count = (SELECT COUNT(*) FROM public.poll_votes v WHERE v.option_id = o.id AND v.retracted_at IS NULL)
  WHERE o.poll_id = p_poll;
END;
$$;

CREATE OR REPLACE FUNCTION public.poll_close(p_poll UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_uid UUID := public._cg_uid(); p public.polls; v_role TEXT;
BEGIN
  SELECT * INTO p FROM public.polls WHERE id = p_poll FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'poll_not_found'; END IF;
  v_role := public._cg_require_member(p.group_id);
  IF p.created_by IS DISTINCT FROM v_uid AND v_role NOT IN ('leader', 'co_leader') THEN RAISE EXCEPTION 'not_group_officer'; END IF;
  UPDATE public.polls SET closed_at = COALESCE(closed_at, NOW()) WHERE id = p_poll;
END;
$$;

-- ------------------------------------------------------------
-- 12. Formal votes
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._cg_open_vote(
  p_group UUID, p_kind TEXT, p_title TEXT, p_description TEXT, p_subject JSONB, p_creator UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  g public.groups;
  v_threshold TEXT;
  v_base TEXT := 'cast';
  v_id UUID;
BEGIN
  SELECT * INTO g FROM public.groups WHERE id = p_group;
  v_threshold := CASE
    WHEN p_kind IN ('leader_change', 'rule_change', 'voting_method') THEN 'two_thirds'
    ELSE g.pass_threshold END;
  -- "Change leader passes with 2/3 of all members."
  IF p_kind = 'leader_change' THEN v_base := 'eligible'; END IF;
  INSERT INTO public.group_votes (group_id, kind, title, description, subject, created_by, method,
                                  quorum_pct, threshold, threshold_base, deadline)
  VALUES (p_group, p_kind, left(btrim(p_title), 200), NULLIF(btrim(p_description), ''), COALESCE(p_subject, '{}'::jsonb),
          p_creator, g.voting_method, g.quorum_pct, v_threshold, v_base, NOW() + make_interval(hours => g.vote_hours))
  RETURNING id INTO v_id;
  PERFORM public._cg_log(p_group, p_creator, 'vote_opened', jsonb_build_object('vote_id', v_id, 'kind', p_kind, 'title', p_title));
  PERFORM public._cg_system_message(p_group, 'Vote opened: ' || p_title);
  PERFORM public._cg_notify_members(p_group, 'vote_opened', 'Vote: ' || left(p_title, 80), NULL,
    jsonb_build_object('vote_id', v_id, 'kind', p_kind), p_creator);
  RETURN v_id;
END;
$$;

-- Votes members can start directly. Proposals, join requests and exits
-- open their own votes.
CREATE OR REPLACE FUNCTION public.group_start_vote(
  p_group UUID, p_kind TEXT, p_title TEXT, p_description TEXT DEFAULT NULL, p_subject JSONB DEFAULT '{}'::jsonb)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  v_role TEXT;
  g public.groups;
  v_target UUID;
BEGIN
  v_role := public._cg_require_member(p_group);
  g := public._cg_group_for_update(p_group);
  IF g.status = 'closed' THEN RAISE EXCEPTION 'group_read_only'; END IF;
  IF p_kind NOT IN ('leader_change', 'rule_change', 'voting_method', 'member_removal', 'close_group', 'custom') THEN
    RAISE EXCEPTION 'invalid_vote_kind';
  END IF;
  IF p_kind IN ('close_group', 'custom') AND v_role NOT IN ('leader', 'co_leader') THEN RAISE EXCEPTION 'not_group_officer'; END IF;
  IF (SELECT COUNT(*) FROM public.group_votes WHERE group_id = p_group AND status = 'open') >= 10 THEN
    RAISE EXCEPTION 'too_many_open_votes';
  END IF;
  IF EXISTS (SELECT 1 FROM public.group_votes WHERE group_id = p_group AND status = 'open' AND kind = p_kind
             AND p_kind IN ('leader_change', 'rule_change', 'voting_method', 'close_group')) THEN
    RAISE EXCEPTION 'vote_already_open';
  END IF;

  IF p_kind = 'leader_change' THEN
    v_target := public.cg_try_uuid(p_subject->>'new_leader');
    IF v_target IS NULL OR NOT EXISTS (SELECT 1 FROM public.group_members
        WHERE group_id = p_group AND user_id = v_target AND status = 'active' AND role <> 'leader') THEN
      RAISE EXCEPTION 'invalid_candidate';
    END IF;
  ELSIF p_kind = 'member_removal' THEN
    v_target := public.cg_try_uuid(p_subject->>'user_id');
    IF v_target IS NULL OR v_target = v_uid OR NOT EXISTS (SELECT 1 FROM public.group_members
        WHERE group_id = p_group AND user_id = v_target AND status = 'active' AND role <> 'leader') THEN
      RAISE EXCEPTION 'invalid_target';
    END IF;
    IF char_length(btrim(COALESCE(p_subject->>'reason', ''))) < 3 THEN RAISE EXCEPTION 'reason_required'; END IF;
  ELSIF p_kind = 'voting_method' THEN
    IF COALESCE(p_subject->>'method', '') NOT IN ('one_member_one_vote', 'weighted') OR p_subject->>'method' = g.voting_method THEN
      RAISE EXCEPTION 'invalid_voting_method';
    END IF;
  ELSIF p_kind = 'rule_change' THEN
    IF NOT (p_subject ?| ARRAY['rules', 'join_approval', 'quorum_pct', 'pass_threshold', 'vote_hours']) THEN
      RAISE EXCEPTION 'nothing_to_change';
    END IF;
    IF p_subject ? 'rules' AND char_length(p_subject->>'rules') > 4000 THEN RAISE EXCEPTION 'rules_too_long'; END IF;
    IF p_subject ? 'join_approval' AND p_subject->>'join_approval' NOT IN ('leader', 'vote') THEN RAISE EXCEPTION 'invalid_setting'; END IF;
    IF p_subject ? 'pass_threshold' AND p_subject->>'pass_threshold' NOT IN ('majority', 'two_thirds') THEN RAISE EXCEPTION 'invalid_setting'; END IF;
    IF p_subject ? 'quorum_pct' AND (p_subject->>'quorum_pct')::INT NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_setting'; END IF;
    IF p_subject ? 'vote_hours' AND (p_subject->>'vote_hours')::INT NOT BETWEEN 12 AND 336 THEN RAISE EXCEPTION 'invalid_setting'; END IF;
  END IF;

  -- A group of one decides alone: apply at once, still logged.
  IF public._cg_active_count(p_group) = 1 AND p_kind IN ('rule_change', 'voting_method', 'close_group') THEN
    RETURN public._cg_apply_now(p_group, p_kind, p_title, p_subject, v_uid);
  END IF;
  RETURN public._cg_open_vote(p_group, p_kind, p_title, p_description, p_subject, v_uid);
END;
$$;

-- Records a decision that needed no vote (single-member group) as a
-- passed vote, so the history reads the same.
CREATE OR REPLACE FUNCTION public._cg_apply_now(p_group UUID, p_kind TEXT, p_title TEXT, p_subject JSONB, p_actor UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  g public.groups;
  v public.group_votes;
BEGIN
  SELECT * INTO g FROM public.groups WHERE id = p_group;
  INSERT INTO public.group_votes (group_id, kind, title, subject, created_by, method, quorum_pct, threshold,
    threshold_base, deadline, status, yes_weight, no_weight, abstain_count, ballot_count, eligible_count,
    eligible_weight, result_note, closed_at)
  VALUES (p_group, p_kind, left(btrim(p_title), 200), COALESCE(p_subject, '{}'::jsonb), p_actor, g.voting_method,
    g.quorum_pct, 'majority', 'cast', NOW(), 'passed', 1, 0, 0, 1, 1, 1, 'Only member: applied directly', NOW())
  RETURNING * INTO v;
  INSERT INTO public.group_vote_ballots (vote_id, group_id, user_id, choice, weight) VALUES (v.id, p_group, p_actor, 'yes', 1);
  PERFORM public._cg_apply_vote(v);
  PERFORM public._cg_log(p_group, p_actor, 'vote_closed', jsonb_build_object('vote_id', v.id, 'kind', p_kind, 'passed', TRUE));
  RETURN v.id;
END;
$$;

CREATE OR REPLACE FUNCTION public.vote_cast(p_vote UUID, p_choice TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  v public.group_votes;
BEGIN
  SELECT * INTO v FROM public.group_votes WHERE id = p_vote;
  IF NOT FOUND THEN RAISE EXCEPTION 'vote_not_found'; END IF;
  PERFORM public._cg_require_member(v.group_id);
  IF v.status <> 'open' OR v.deadline <= NOW() THEN RAISE EXCEPTION 'vote_closed'; END IF;
  IF p_choice NOT IN ('yes', 'no', 'abstain') THEN RAISE EXCEPTION 'invalid_choice'; END IF;
  -- People don't vote on their own removal, exit or join request.
  IF v.kind IN ('member_removal', 'exit', 'join_request') AND public.cg_try_uuid(v.subject->>'user_id') = v_uid THEN
    RAISE EXCEPTION 'cannot_vote_on_own_case';
  END IF;
  INSERT INTO public.group_vote_ballots (vote_id, group_id, user_id, choice)
  VALUES (p_vote, v.group_id, v_uid, p_choice)
  ON CONFLICT (vote_id, user_id) DO UPDATE SET choice = EXCLUDED.choice, updated_at = NOW();
END;
$$;

CREATE OR REPLACE FUNCTION public._cg_apply_vote(v public.group_votes)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_target UUID;
  r public.group_join_requests;
  v_note TEXT;
BEGIN
  CASE v.kind
  WHEN 'leader_change' THEN
    v_target := public.cg_try_uuid(v.subject->>'new_leader');
    IF EXISTS (SELECT 1 FROM public.group_members WHERE group_id = v.group_id AND user_id = v_target AND status = 'active') THEN
      PERFORM public._cg_set_leader(v.group_id, v_target, NULL, 'member', 'vote');
    ELSE
      v_note := 'Candidate is no longer a member';
    END IF;
  WHEN 'rule_change' THEN
    UPDATE public.groups SET
      rules = COALESCE(v.subject->>'rules', rules),
      join_approval = COALESCE(v.subject->>'join_approval', join_approval),
      quorum_pct = COALESCE((v.subject->>'quorum_pct')::INT, quorum_pct),
      pass_threshold = COALESCE(v.subject->>'pass_threshold', pass_threshold),
      vote_hours = COALESCE((v.subject->>'vote_hours')::INT, vote_hours),
      updated_at = NOW()
    WHERE id = v.group_id;
    PERFORM public._cg_log(v.group_id, NULL, 'rules_changed', v.subject);
  WHEN 'voting_method' THEN
    UPDATE public.groups SET voting_method = v.subject->>'method', updated_at = NOW() WHERE id = v.group_id;
    PERFORM public._cg_log(v.group_id, NULL, 'voting_method_changed', v.subject);
  WHEN 'member_removal' THEN
    v_target := public.cg_try_uuid(v.subject->>'user_id');
    IF EXISTS (SELECT 1 FROM public.group_members WHERE group_id = v.group_id AND user_id = v_target
               AND status = 'active' AND role <> 'leader') THEN
      PERFORM public._cg_remove(v.group_id, v_target, 'Removed by group vote: ' || COALESCE(v.subject->>'reason', ''), NULL);
    ELSE
      v_note := 'Member already left or is now the leader';
    END IF;
  WHEN 'join_request' THEN
    SELECT * INTO r FROM public.group_join_requests WHERE id = public.cg_try_uuid(v.subject->>'request_id') FOR UPDATE;
    IF r.status = 'pending' THEN
      BEGIN
        PERFORM public._cg_add_member(r.group_id, r.user_id, r.rules_accepted_at, NULL);
        UPDATE public.group_join_requests SET status = 'approved', decided_at = NOW() WHERE id = r.id;
        PERFORM public._cg_notify(r.user_id, 'join_decision', 'Your request to join was accepted', NULL, r.group_id,
          jsonb_build_object('request_id', r.id, 'approved', TRUE));
      EXCEPTION WHEN raise_exception THEN
        UPDATE public.group_join_requests SET status = 'declined', decided_at = NOW() WHERE id = r.id;
        PERFORM public._cg_notify(r.user_id, 'join_decision', 'Your join request could not be completed', SQLERRM, NULL,
          jsonb_build_object('request_id', r.id, 'approved', FALSE));
        v_note := 'Approved but could not join: ' || SQLERRM;
      END;
    END IF;
  WHEN 'proposal' THEN
    UPDATE public.group_proposals SET status = 'approved'
    WHERE id = public.cg_try_uuid(v.subject->>'proposal_id') AND status = 'voting';
  WHEN 'exit' THEN
    PERFORM public._cg_approve_exit(public.cg_try_uuid(v.subject->>'request_id'), NULL);
  WHEN 'close_group' THEN
    v_note := public._cg_close_group(v.group_id);
  ELSE
    NULL;
  END CASE;
  RETURN v_note;
END;
$$;

CREATE OR REPLACE FUNCTION public._cg_reject_vote_subject(v public.group_votes)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE r public.group_join_requests;
BEGIN
  IF v.kind = 'join_request' THEN
    UPDATE public.group_join_requests SET status = 'declined', decided_at = NOW()
    WHERE id = public.cg_try_uuid(v.subject->>'request_id') AND status = 'pending'
    RETURNING * INTO r;
    IF r.id IS NOT NULL THEN
      PERFORM public._cg_notify(r.user_id, 'join_decision', 'Your request to join was not accepted', NULL, NULL,
        jsonb_build_object('request_id', r.id, 'approved', FALSE));
    END IF;
  ELSIF v.kind = 'proposal' THEN
    UPDATE public.group_proposals SET status = 'rejected'
    WHERE id = public.cg_try_uuid(v.subject->>'proposal_id') AND status = 'voting';
  ELSIF v.kind = 'exit' THEN
    UPDATE public.group_exit_requests SET status = 'declined', decided_at = NOW()
    WHERE id = public.cg_try_uuid(v.subject->>'request_id') AND status = 'pending';
  END IF;
END;
$$;

-- Tallies and applies a vote whose deadline has passed.
CREATE OR REPLACE FUNCTION public._cg_close_vote(p_vote UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v public.group_votes;
  v_type TEXT;
  v_excluded UUID;
  v_use_weights BOOLEAN;
  v_eligible_count INT;
  v_eligible_weight NUMERIC;
  v_yes NUMERIC;
  v_no NUMERIC;
  v_abstain INT;
  v_ballots INT;
  v_passed BOOLEAN;
  v_note TEXT;
BEGIN
  SELECT * INTO v FROM public.group_votes WHERE id = p_vote FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'vote_not_found'; END IF;
  IF v.status <> 'open' THEN RETURN to_jsonb(v); END IF;
  IF v.deadline > NOW() THEN RAISE EXCEPTION 'vote_still_open'; END IF;
  SELECT type INTO v_type FROM public.groups WHERE id = v.group_id;
  IF v.kind IN ('member_removal', 'exit', 'join_request') THEN
    v_excluded := public.cg_try_uuid(v.subject->>'user_id');
  END IF;

  -- Eligible: active members at close, minus the person the vote is about.
  -- Weights: one each, or confirmed contributions in a weighted
  -- investment group (one each if nobody has contributed yet).
  SELECT COUNT(*), COALESCE(SUM(mc.confirmed), 0) INTO v_eligible_count, v_eligible_weight
  FROM public._cg_member_contributions(v.group_id) mc WHERE mc.user_id IS DISTINCT FROM v_excluded;
  v_use_weights := v.method = 'weighted' AND v_type = 'investment' AND v_eligible_weight > 0;
  IF NOT v_use_weights THEN v_eligible_weight := v_eligible_count; END IF;

  -- Ballots from people no longer eligible keep a NULL weight and don't count.
  UPDATE public.group_vote_ballots b
  SET weight = CASE WHEN v_use_weights THEN mc.confirmed ELSE 1 END
  FROM public._cg_member_contributions(v.group_id) mc
  WHERE b.vote_id = v.id AND b.user_id = mc.user_id AND mc.user_id IS DISTINCT FROM v_excluded;

  SELECT COALESCE(SUM(b.weight) FILTER (WHERE b.choice = 'yes'), 0),
         COALESCE(SUM(b.weight) FILTER (WHERE b.choice = 'no'), 0),
         COUNT(*) FILTER (WHERE b.choice = 'abstain'),
         COUNT(*)
  INTO v_yes, v_no, v_abstain, v_ballots
  FROM public.group_vote_ballots b
  WHERE b.vote_id = v.id AND b.weight IS NOT NULL;

  v_passed := public.cg_vote_passes(v_yes, v_no, v_ballots, v_eligible_count, v_eligible_weight,
                                    v.quorum_pct, v.threshold, v.threshold_base);
  UPDATE public.group_votes SET
    status = CASE WHEN v_passed THEN 'passed' ELSE 'failed' END,
    yes_weight = v_yes, no_weight = v_no, abstain_count = v_abstain, ballot_count = v_ballots,
    eligible_count = v_eligible_count, eligible_weight = v_eligible_weight, closed_at = NOW()
  WHERE id = v.id
  RETURNING * INTO v;

  IF v_passed THEN
    v_note := public._cg_apply_vote(v);
  ELSE
    PERFORM public._cg_reject_vote_subject(v);
    v_note := CASE WHEN v_ballots * 100 < v.quorum_pct * v_eligible_count THEN 'Quorum not reached' END;
  END IF;
  UPDATE public.group_votes SET result_note = v_note WHERE id = v.id RETURNING * INTO v;

  PERFORM public._cg_log(v.group_id, NULL, 'vote_closed', jsonb_build_object(
    'vote_id', v.id, 'kind', v.kind, 'passed', v_passed, 'yes', v_yes, 'no', v_no,
    'abstain', v_abstain, 'eligible', v_eligible_count, 'note', v_note));
  PERFORM public._cg_system_message(v.group_id, 'Vote ' || CASE WHEN v_passed THEN 'passed' ELSE 'failed' END
    || ': ' || v.title || ' (yes ' || v_yes || ', no ' || v_no || ', abstain ' || v_abstain || ')'
    || COALESCE('. ' || v_note, ''));
  PERFORM public._cg_notify_members(v.group_id, 'vote_result',
    CASE WHEN v_passed THEN 'Passed: ' ELSE 'Failed: ' END || left(v.title, 80), v_note,
    jsonb_build_object('vote_id', v.id, 'passed', v_passed));
  RETURN to_jsonb(v);
END;
$$;

-- Any member can close a vote once its deadline has passed (the cron job
-- also does it every few minutes).
CREATE OR REPLACE FUNCTION public.vote_close(p_vote UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_group UUID;
BEGIN
  SELECT group_id INTO v_group FROM public.group_votes WHERE id = p_vote;
  IF v_group IS NULL THEN RAISE EXCEPTION 'vote_not_found'; END IF;
  PERFORM public._cg_require_member(v_group);
  RETURN public._cg_close_vote(p_vote);
END;
$$;

-- Closing needs every investment closed and every distribution confirmed.
CREATE OR REPLACE FUNCTION public._cg_close_group(p_group UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE g public.groups;
BEGIN
  SELECT * INTO g FROM public.groups WHERE id = p_group FOR UPDATE;
  IF EXISTS (SELECT 1 FROM public.group_investments WHERE group_id = p_group AND status = 'open') THEN
    RETURN 'Not closed: some investments are still open';
  END IF;
  IF EXISTS (SELECT 1 FROM public.group_distribution_shares WHERE group_id = p_group AND confirmed_at IS NULL) THEN
    RETURN 'Not closed: some distributions are not confirmed';
  END IF;
  IF g.type = 'seettu' AND g.status = 'active'
     AND EXISTS (SELECT 1 FROM public.seettu_rounds WHERE group_id = p_group AND status <> 'completed') THEN
    RETURN 'Not closed: seettu rounds are still running';
  END IF;
  UPDATE public.groups SET status = 'closed', closed_at = NOW(), updated_at = NOW() WHERE id = p_group;
  UPDATE public.group_join_requests SET status = 'cancelled', decided_at = NOW() WHERE group_id = p_group AND status = 'pending';
  UPDATE public.group_invites SET status = 'cancelled', responded_at = NOW() WHERE group_id = p_group AND status = 'pending';
  PERFORM public._cg_log(p_group, NULL, 'group_closed', '{}'::jsonb);
  PERFORM public._cg_system_message(p_group, 'The group is closed. Its history stays available to members (read-only).');
  RETURN NULL;
END;
$$;

-- ------------------------------------------------------------
-- 13. Seettu
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.seettu_set_order(p_group UUID, p_user_ids UUID[])
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  g public.groups;
  s public.seettu_settings;
  i INT;
BEGIN
  PERFORM public._cg_require_member(p_group, ARRAY['leader', 'co_leader']);
  g := public._cg_group_for_update(p_group);
  SELECT * INTO s FROM public.seettu_settings WHERE group_id = p_group;
  IF g.type <> 'seettu' THEN RAISE EXCEPTION 'not_a_seettu'; END IF;
  IF g.status <> 'forming' THEN RAISE EXCEPTION 'seettu_already_started'; END IF;
  IF s.payout_method <> 'agreed' THEN RAISE EXCEPTION 'order_is_not_agreed'; END IF;
  IF cardinality(p_user_ids) <> public._cg_active_count(p_group)
     OR (SELECT COUNT(DISTINCT u) FROM unnest(p_user_ids) u) <> cardinality(p_user_ids)
     OR EXISTS (SELECT 1 FROM unnest(p_user_ids) u WHERE NOT EXISTS (
       SELECT 1 FROM public.group_members WHERE group_id = p_group AND user_id = u AND status = 'active')) THEN
    RAISE EXCEPTION 'order_must_list_every_member';
  END IF;
  UPDATE public.group_members SET payout_position = NULL, seettu_confirmed_at = NULL WHERE group_id = p_group;
  FOR i IN 1..cardinality(p_user_ids) LOOP
    UPDATE public.group_members SET payout_position = i WHERE group_id = p_group AND user_id = p_user_ids[i];
  END LOOP;
  UPDATE public.group_members SET seettu_confirmed_at = NOW() WHERE group_id = p_group AND user_id = v_uid;
  PERFORM public._cg_log(p_group, v_uid, 'payout_order_set', jsonb_build_object('order', to_jsonb(p_user_ids)));
  PERFORM public._cg_system_message(p_group, 'The payout order was set. Every member needs to confirm it.');
  PERFORM public._cg_notify_members(p_group, 'group_update', 'Confirm the seettu payout order', NULL, '{}'::jsonb, v_uid);
END;
$$;

CREATE OR REPLACE FUNCTION public.seettu_confirm(p_group UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  g public.groups;
  v_method TEXT;
BEGIN
  PERFORM public._cg_require_member(p_group);
  SELECT * INTO g FROM public.groups WHERE id = p_group;
  IF g.type <> 'seettu' THEN RAISE EXCEPTION 'not_a_seettu'; END IF;
  IF g.status <> 'forming' THEN RAISE EXCEPTION 'seettu_already_started'; END IF;
  SELECT payout_method INTO v_method FROM public.seettu_settings WHERE group_id = p_group;
  IF v_method = 'agreed' AND EXISTS (SELECT 1 FROM public.group_members
      WHERE group_id = p_group AND status = 'active' AND payout_position IS NULL) THEN
    RAISE EXCEPTION 'order_not_set';
  END IF;
  UPDATE public.group_members SET seettu_confirmed_at = NOW() WHERE group_id = p_group AND user_id = v_uid;
  PERFORM public._cg_log(p_group, v_uid, 'seettu_terms_confirmed', '{}'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.seettu_start(p_group UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  g public.groups;
  s public.seettu_settings;
  v_n INT;
  v_round UUID;
  v_recipient UUID;
  i INT;
BEGIN
  PERFORM public._cg_require_member(p_group, ARRAY['leader', 'co_leader']);
  g := public._cg_group_for_update(p_group);
  SELECT * INTO s FROM public.seettu_settings WHERE group_id = p_group;
  IF g.type <> 'seettu' THEN RAISE EXCEPTION 'not_a_seettu'; END IF;
  IF g.status <> 'forming' THEN RAISE EXCEPTION 'seettu_already_started'; END IF;
  v_n := public._cg_active_count(p_group);
  IF v_n < g.max_members THEN RAISE EXCEPTION 'seats_not_filled'; END IF;
  IF EXISTS (SELECT 1 FROM public.group_members WHERE group_id = p_group AND status = 'active' AND seettu_confirmed_at IS NULL) THEN
    RAISE EXCEPTION 'not_all_confirmed';
  END IF;
  IF s.start_date < CURRENT_DATE THEN RAISE EXCEPTION 'start_date_passed'; END IF;

  FOR i IN 1..v_n LOOP
    v_recipient := NULL;
    IF s.payout_method = 'agreed' THEN
      SELECT user_id INTO v_recipient FROM public.group_members
      WHERE group_id = p_group AND status = 'active' AND payout_position = i;
    END IF;
    INSERT INTO public.seettu_rounds (group_id, round_no, due_date, recipient_id, pot, status, drawn_at)
    VALUES (p_group, i, public.cg_seettu_due_date(s.start_date, s.frequency, s.due_day, i), v_recipient,
            s.contribution * v_n, CASE WHEN v_recipient IS NULL THEN 'upcoming' ELSE 'collecting' END,
            CASE WHEN v_recipient IS NULL THEN NULL ELSE NOW() END)
    RETURNING id INTO v_round;
    INSERT INTO public.seettu_payments (round_id, group_id, payer_id, amount_due)
    SELECT v_round, p_group, m.user_id, s.contribution
    FROM public.group_members m WHERE m.group_id = p_group AND m.status = 'active';
  END LOOP;

  UPDATE public.groups SET status = 'active', updated_at = NOW() WHERE id = p_group;
  PERFORM public._cg_log(p_group, v_uid, 'seettu_started', jsonb_build_object(
    'members', v_n, 'contribution', s.contribution, 'frequency', s.frequency, 'start_date', s.start_date,
    'payout_method', s.payout_method));
  PERFORM public._cg_system_message(p_group, 'The seettu has started: ' || v_n || ' rounds of Rs '
    || to_char(s.contribution, 'FM999,999,999,990.00') || ' per member.');
  PERFORM public._cg_notify_members(p_group, 'group_update', g.name || ' has started', NULL, '{}'::jsonb, v_uid);
END;
$$;

-- Server-side random draw. 'all' assigns every round at once (draw_mode
-- 'all'); otherwise draws the next round only.
CREATE OR REPLACE FUNCTION public.seettu_draw(p_group UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  g public.groups;
  s public.seettu_settings;
  r RECORD;
  v_winner UUID;
  v_result JSONB := '[]'::jsonb;
BEGIN
  PERFORM public._cg_require_member(p_group, ARRAY['leader', 'co_leader']);
  g := public._cg_group_for_update(p_group);
  SELECT * INTO s FROM public.seettu_settings WHERE group_id = p_group;
  IF g.type <> 'seettu' OR s.payout_method <> 'random' THEN RAISE EXCEPTION 'not_a_random_seettu'; END IF;
  IF g.status <> 'active' THEN RAISE EXCEPTION 'seettu_not_started'; END IF;
  FOR r IN SELECT * FROM public.seettu_rounds WHERE group_id = p_group AND recipient_id IS NULL ORDER BY round_no LOOP
    SELECT m.user_id INTO v_winner FROM public.group_members m
    WHERE m.group_id = p_group AND m.status = 'active'
      AND NOT EXISTS (SELECT 1 FROM public.seettu_rounds x WHERE x.group_id = p_group AND x.recipient_id = m.user_id)
    ORDER BY random() LIMIT 1;
    IF v_winner IS NULL THEN RAISE EXCEPTION 'no_eligible_members'; END IF;
    UPDATE public.seettu_rounds SET recipient_id = v_winner, status = 'collecting', drawn_at = NOW() WHERE id = r.id;
    v_result := v_result || jsonb_build_object('round_no', r.round_no, 'recipient_id', v_winner,
                                               'recipient_name', public._cg_name(v_winner));
    PERFORM public._cg_log(p_group, v_uid, 'seettu_draw', jsonb_build_object('round_no', r.round_no, 'recipient_id', v_winner));
    PERFORM public._cg_system_message(p_group, 'Draw for round ' || r.round_no || ': ' || public._cg_name(v_winner));
    EXIT WHEN s.draw_mode = 'each_round';
  END LOOP;
  IF jsonb_array_length(v_result) = 0 THEN RAISE EXCEPTION 'nothing_to_draw'; END IF;
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public._cg_next_unassigned_round(p_group UUID)
RETURNS public.seettu_rounds
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT * FROM public.seettu_rounds WHERE group_id = p_group AND recipient_id IS NULL ORDER BY round_no LIMIT 1;
$$;

-- Auction seettu: opens bidding for the next round. With one eligible
-- member left they get the pot without bidding.
CREATE OR REPLACE FUNCTION public.seettu_open_bidding(p_group UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  g public.groups;
  s public.seettu_settings;
  r public.seettu_rounds;
  v_eligible INT;
  v_last UUID;
BEGIN
  PERFORM public._cg_require_member(p_group, ARRAY['leader', 'co_leader']);
  g := public._cg_group_for_update(p_group);
  SELECT * INTO s FROM public.seettu_settings WHERE group_id = p_group;
  IF g.type <> 'seettu' OR s.payout_method <> 'bidding' THEN RAISE EXCEPTION 'not_an_auction_seettu'; END IF;
  IF g.status <> 'active' THEN RAISE EXCEPTION 'seettu_not_started'; END IF;
  r := public._cg_next_unassigned_round(p_group);
  IF r.id IS NULL THEN RAISE EXCEPTION 'nothing_to_draw'; END IF;
  IF r.status = 'bidding' THEN RAISE EXCEPTION 'bidding_already_open'; END IF;
  SELECT COUNT(*), MIN(m.user_id::TEXT)::UUID INTO v_eligible, v_last FROM public.group_members m
  WHERE m.group_id = p_group AND m.status = 'active'
    AND NOT EXISTS (SELECT 1 FROM public.seettu_rounds x WHERE x.group_id = p_group AND x.recipient_id = m.user_id);
  IF v_eligible = 1 THEN
    UPDATE public.seettu_rounds SET recipient_id = v_last, status = 'collecting', drawn_at = NOW() WHERE id = r.id;
    PERFORM public._cg_log(p_group, v_uid, 'seettu_last_round_assigned', jsonb_build_object('round_no', r.round_no, 'recipient_id', v_last));
    PERFORM public._cg_system_message(p_group, 'Round ' || r.round_no || ' goes to ' || public._cg_name(v_last) || ' (last member, no bidding).');
    RETURN jsonb_build_object('round_no', r.round_no, 'recipient_id', v_last, 'bidding', FALSE);
  END IF;
  UPDATE public.seettu_rounds SET status = 'bidding' WHERE id = r.id;
  PERFORM public._cg_log(p_group, v_uid, 'seettu_bidding_opened', jsonb_build_object('round_no', r.round_no));
  PERFORM public._cg_system_message(p_group, 'Bidding is open for round ' || r.round_no || '.');
  PERFORM public._cg_notify_members(p_group, 'group_update', 'Bidding open for round ' || r.round_no, NULL,
    jsonb_build_object('round_id', r.id), v_uid);
  RETURN jsonb_build_object('round_no', r.round_no, 'round_id', r.id, 'bidding', TRUE);
END;
$$;

CREATE OR REPLACE FUNCTION public.seettu_place_bid(p_round UUID, p_discount NUMERIC)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  r public.seettu_rounds;
BEGIN
  SELECT * INTO r FROM public.seettu_rounds WHERE id = p_round;
  IF NOT FOUND THEN RAISE EXCEPTION 'round_not_found'; END IF;
  PERFORM public._cg_require_member(r.group_id);
  IF r.status <> 'bidding' THEN RAISE EXCEPTION 'bidding_closed'; END IF;
  IF EXISTS (SELECT 1 FROM public.seettu_rounds WHERE group_id = r.group_id AND recipient_id = v_uid) THEN
    RAISE EXCEPTION 'already_received_pot';
  END IF;
  -- A discount above half the pot is almost certainly a typo.
  IF p_discount IS NULL OR p_discount < 0 OR p_discount > r.pot / 2 THEN RAISE EXCEPTION 'invalid_bid'; END IF;
  INSERT INTO public.seettu_bids (round_id, group_id, user_id, discount)
  VALUES (p_round, r.group_id, v_uid, round(p_discount, 2))
  ON CONFLICT (round_id, user_id) DO UPDATE SET discount = EXCLUDED.discount, created_at = NOW();
END;
$$;

-- Biggest discount wins (earliest on a tie). The discount is shared
-- equally among the other members as a credit on this round's
-- instalment, so collections still add up to the (smaller) pot.
CREATE OR REPLACE FUNCTION public.seettu_close_bidding(p_round UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  r public.seettu_rounds;
  s public.seettu_settings;
  v_winner UUID;
  v_discount NUMERIC := 0;
  v_others UUID[];
  v_credits NUMERIC[];
  v_n INT;
  i INT;
BEGIN
  SELECT * INTO r FROM public.seettu_rounds WHERE id = p_round FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'round_not_found'; END IF;
  PERFORM public._cg_require_member(r.group_id, ARRAY['leader', 'co_leader']);
  IF r.status <> 'bidding' THEN RAISE EXCEPTION 'bidding_closed'; END IF;
  SELECT * INTO s FROM public.seettu_settings WHERE group_id = r.group_id;

  SELECT b.user_id, b.discount INTO v_winner, v_discount
  FROM public.seettu_bids b
  WHERE b.round_id = r.id
    AND NOT EXISTS (SELECT 1 FROM public.seettu_rounds x WHERE x.group_id = r.group_id AND x.recipient_id = b.user_id)
    AND EXISTS (SELECT 1 FROM public.group_members m WHERE m.group_id = r.group_id AND m.user_id = b.user_id AND m.status = 'active')
  ORDER BY b.discount DESC, b.created_at
  LIMIT 1;
  IF v_winner IS NULL THEN
    -- No bids: random among eligible members, no discount.
    v_discount := 0;
    SELECT m.user_id INTO v_winner FROM public.group_members m
    WHERE m.group_id = r.group_id AND m.status = 'active'
      AND NOT EXISTS (SELECT 1 FROM public.seettu_rounds x WHERE x.group_id = r.group_id AND x.recipient_id = m.user_id)
    ORDER BY random() LIMIT 1;
  END IF;

  SELECT COUNT(*) INTO v_n FROM public.seettu_payments WHERE round_id = r.id;
  UPDATE public.seettu_rounds
  SET recipient_id = v_winner, discount = v_discount, pot = s.contribution * v_n - v_discount,
      status = 'collecting', drawn_at = NOW()
  WHERE id = r.id;

  IF v_discount > 0 THEN
    SELECT array_agg(payer_id ORDER BY payer_id) INTO v_others
    FROM public.seettu_payments WHERE round_id = r.id AND payer_id <> v_winner;
    v_credits := public.cg_split_amount(v_discount, array_fill(1::NUMERIC, ARRAY[cardinality(v_others)]));
    FOR i IN 1..cardinality(v_others) LOOP
      UPDATE public.seettu_payments SET credit = v_credits[i], amount_due = s.contribution - v_credits[i]
      WHERE round_id = r.id AND payer_id = v_others[i];
    END LOOP;
  END IF;

  PERFORM public._cg_log(r.group_id, v_uid, 'seettu_bidding_closed', jsonb_build_object(
    'round_no', r.round_no, 'recipient_id', v_winner, 'discount', v_discount));
  PERFORM public._cg_system_message(r.group_id, 'Round ' || r.round_no || ' goes to ' || public._cg_name(v_winner)
    || CASE WHEN v_discount > 0 THEN ' with a discount of Rs ' || to_char(v_discount, 'FM999,999,990.00')
         || ', shared as a credit on everyone else''s instalment' ELSE ' (no bids, drawn at random)' END || '.');
  RETURN jsonb_build_object('round_no', r.round_no, 'recipient_id', v_winner, 'discount', v_discount);
END;
$$;

CREATE OR REPLACE FUNCTION public.seettu_mark_paid(p_payment UUID, p_receipt_path TEXT DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  p public.seettu_payments;
  r public.seettu_rounds;
  v_receipt TEXT := NULLIF(btrim(p_receipt_path), '');
BEGIN
  SELECT * INTO p FROM public.seettu_payments WHERE id = p_payment FOR UPDATE;
  IF NOT FOUND OR p.payer_id <> v_uid THEN RAISE EXCEPTION 'payment_not_found'; END IF;
  PERFORM public._cg_require_member(p.group_id);
  SELECT * INTO r FROM public.seettu_rounds WHERE id = p.round_id;
  IF r.recipient_id IS NULL THEN RAISE EXCEPTION 'recipient_not_decided'; END IF;
  IF p.status NOT IN ('pending', 'late') THEN RAISE EXCEPTION 'payment_already_marked'; END IF;
  IF v_receipt IS NOT NULL AND v_receipt NOT LIKE 'groups/' || p.group_id::TEXT || '/receipts/%' THEN
    RAISE EXCEPTION 'invalid_attachment';
  END IF;
  UPDATE public.seettu_payments SET status = 'marked_paid', marked_at = NOW(), receipt_path = v_receipt WHERE id = p.id;
  PERFORM public._cg_log(p.group_id, v_uid, 'seettu_payment_marked', jsonb_build_object('round_no', r.round_no, 'payment_id', p.id));
  -- Tell whoever can confirm: officers and this round's recipient.
  INSERT INTO public.notifications (user_id, kind, title, group_id, data)
  SELECT DISTINCT m.user_id, 'seettu_payment_marked',
         public._cg_name(v_uid) || ' marked round ' || r.round_no || ' as paid', p.group_id,
         jsonb_build_object('payment_id', p.id)
  FROM public.group_members m
  WHERE m.group_id = p.group_id AND m.status = 'active' AND m.user_id <> v_uid
    AND (m.role IN ('leader', 'co_leader', 'treasurer') OR m.user_id = r.recipient_id);
END;
$$;

-- Officers or the round's recipient confirm; never the payer.
CREATE OR REPLACE FUNCTION public.seettu_confirm_payment(p_payment UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  p public.seettu_payments;
  r public.seettu_rounds;
  v_role TEXT;
  v_group_name TEXT;
  v_log BOOLEAN;
BEGIN
  SELECT * INTO p FROM public.seettu_payments WHERE id = p_payment FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'payment_not_found'; END IF;
  v_role := public._cg_require_member(p.group_id);
  SELECT * INTO r FROM public.seettu_rounds WHERE id = p.round_id;
  IF p.payer_id = v_uid THEN RAISE EXCEPTION 'cannot_confirm_own_payment'; END IF;
  IF v_role NOT IN ('leader', 'co_leader', 'treasurer') AND r.recipient_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'not_group_officer';
  END IF;
  IF r.recipient_id IS NULL THEN RAISE EXCEPTION 'recipient_not_decided'; END IF;
  IF p.status = 'confirmed' THEN RAISE EXCEPTION 'payment_already_confirmed'; END IF;
  UPDATE public.seettu_payments
  SET status = 'confirmed', confirmed_by = v_uid, confirmed_at = NOW(), marked_at = COALESCE(marked_at, NOW())
  WHERE id = p.id;
  SELECT name INTO v_group_name FROM public.groups WHERE id = p.group_id;
  PERFORM public._cg_log(p.group_id, v_uid, 'seettu_payment_confirmed',
    jsonb_build_object('round_no', r.round_no, 'payment_id', p.id, 'payer_id', p.payer_id, 'amount', p.amount_due));
  PERFORM public._cg_system_message(p.group_id, public._cg_name(v_uid) || ' confirmed ' || public._cg_name(p.payer_id)
    || '''s payment for Round ' || r.round_no || '.');
  PERFORM public._cg_notify(p.payer_id, 'seettu_payment_confirmed',
    'Your round ' || r.round_no || ' payment was confirmed', v_group_name, p.group_id, jsonb_build_object('payment_id', p.id));
  -- Opt-in: log the confirmed instalment in Expenditure.
  SELECT log_payments_as_expenses INTO v_log FROM public.group_members WHERE group_id = p.group_id AND user_id = p.payer_id;
  IF COALESCE(v_log, FALSE) AND p.amount_due > 0 THEN
    INSERT INTO public.expenses (user_id, category, amount, note, expense_date)
    VALUES (p.payer_id, 'Seettu', p.amount_due, 'Seettu: ' || v_group_name || ', round ' || r.round_no,
            COALESCE(p.marked_at, NOW())::DATE);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.seettu_hand_over(p_round UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  r public.seettu_rounds;
BEGIN
  SELECT * INTO r FROM public.seettu_rounds WHERE id = p_round FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'round_not_found'; END IF;
  PERFORM public._cg_require_member(r.group_id, ARRAY['leader', 'co_leader', 'treasurer']);
  IF r.status <> 'collecting' THEN RAISE EXCEPTION 'round_not_collecting'; END IF;
  IF EXISTS (SELECT 1 FROM public.seettu_rounds WHERE group_id = r.group_id AND round_no < r.round_no AND status <> 'completed') THEN
    RAISE EXCEPTION 'previous_round_open';
  END IF;
  -- Unpaid instalments of removed members don't block the round; they
  -- stay on record as unpaid.
  IF EXISTS (SELECT 1 FROM public.seettu_payments p
             JOIN public.group_members m ON m.group_id = p.group_id AND m.user_id = p.payer_id AND m.status = 'active'
             WHERE p.round_id = r.id AND p.status <> 'confirmed') THEN
    RAISE EXCEPTION 'payments_outstanding';
  END IF;
  UPDATE public.seettu_rounds SET status = 'handed_over', handed_over_at = NOW() WHERE id = r.id;
  PERFORM public._cg_log(r.group_id, v_uid, 'seettu_pot_handed_over', jsonb_build_object('round_no', r.round_no, 'pot', r.pot, 'recipient_id', r.recipient_id));
  PERFORM public._cg_system_message(r.group_id, 'The round ' || r.round_no || ' pot of Rs ' || to_char(r.pot, 'FM999,999,999,990.00')
    || ' was handed over to ' || public._cg_name(r.recipient_id) || '. Waiting for them to confirm.');
  PERFORM public._cg_notify(r.recipient_id, 'seettu_pot_handed', 'Confirm you received the round ' || r.round_no || ' pot',
    NULL, r.group_id, jsonb_build_object('round_id', r.id));
END;
$$;

CREATE OR REPLACE FUNCTION public.seettu_confirm_received(p_round UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  r public.seettu_rounds;
BEGIN
  SELECT * INTO r FROM public.seettu_rounds WHERE id = p_round FOR UPDATE;
  IF NOT FOUND OR r.recipient_id IS DISTINCT FROM v_uid THEN RAISE EXCEPTION 'round_not_found'; END IF;
  PERFORM public._cg_require_member(r.group_id);
  IF r.status <> 'handed_over' THEN RAISE EXCEPTION 'pot_not_handed_over'; END IF;
  UPDATE public.seettu_rounds SET status = 'completed', received_at = NOW() WHERE id = r.id;
  PERFORM public._cg_log(r.group_id, v_uid, 'seettu_pot_received', jsonb_build_object('round_no', r.round_no, 'pot', r.pot));
  PERFORM public._cg_system_message(r.group_id, public._cg_name(v_uid) || ' confirmed receiving the round ' || r.round_no || ' pot.');
  PERFORM public._cg_notify_members(r.group_id, 'seettu_pot_received',
    public._cg_name(v_uid) || ' received the round ' || r.round_no || ' pot', NULL, jsonb_build_object('round_id', r.id), v_uid);
  IF NOT EXISTS (SELECT 1 FROM public.seettu_rounds WHERE group_id = r.group_id AND status <> 'completed') THEN
    PERFORM public._cg_close_group(r.group_id);
  END IF;
END;
$$;

-- ------------------------------------------------------------
-- 14. Investment groups
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.invest_pledge(p_group UUID, p_amount NUMERIC)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  g public.groups;
  s public.investment_settings;
  v_total NUMERIC;
  v_id UUID;
BEGIN
  PERFORM public._cg_require_member(p_group);
  SELECT * INTO g FROM public.groups WHERE id = p_group;
  IF g.type <> 'investment' THEN RAISE EXCEPTION 'not_an_investment_group'; END IF;
  IF g.status = 'closed' THEN RAISE EXCEPTION 'group_read_only'; END IF;
  SELECT * INTO s FROM public.investment_settings WHERE group_id = p_group;
  IF p_amount IS NULL OR p_amount <= 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  SELECT COALESCE(SUM(amount), 0) INTO v_total FROM public.group_contributions
  WHERE group_id = p_group AND user_id = v_uid AND status <> 'cancelled';
  IF v_total + p_amount < s.min_contribution THEN RAISE EXCEPTION 'below_minimum_contribution'; END IF;
  IF s.max_contribution IS NOT NULL AND v_total + p_amount > s.max_contribution THEN RAISE EXCEPTION 'above_maximum_contribution'; END IF;
  INSERT INTO public.group_contributions (group_id, user_id, amount) VALUES (p_group, v_uid, round(p_amount, 2)) RETURNING id INTO v_id;
  PERFORM public._cg_log(p_group, v_uid, 'contribution_pledged', jsonb_build_object('contribution_id', v_id, 'amount', round(p_amount, 2)));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.invest_mark_paid(p_contribution UUID, p_receipt_path TEXT DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  c public.group_contributions;
  v_receipt TEXT := NULLIF(btrim(p_receipt_path), '');
BEGIN
  SELECT * INTO c FROM public.group_contributions WHERE id = p_contribution FOR UPDATE;
  IF NOT FOUND OR c.user_id <> v_uid THEN RAISE EXCEPTION 'contribution_not_found'; END IF;
  PERFORM public._cg_require_member(c.group_id);
  IF c.status <> 'pledged' THEN RAISE EXCEPTION 'contribution_not_pledged'; END IF;
  IF v_receipt IS NOT NULL AND v_receipt NOT LIKE 'groups/' || c.group_id::TEXT || '/receipts/%' THEN
    RAISE EXCEPTION 'invalid_attachment';
  END IF;
  UPDATE public.group_contributions SET status = 'marked_paid', marked_at = NOW(), receipt_path = v_receipt WHERE id = c.id;
  PERFORM public._cg_log(c.group_id, v_uid, 'contribution_marked_paid', jsonb_build_object('contribution_id', c.id, 'amount', c.amount));
  PERFORM public._cg_notify_members(c.group_id, 'contribution_marked',
    public._cg_name(v_uid) || ' marked a Rs ' || to_char(c.amount, 'FM999,999,999,990.00') || ' contribution as paid',
    NULL, jsonb_build_object('contribution_id', c.id), v_uid, ARRAY['leader', 'co_leader', 'treasurer']);
END;
$$;

CREATE OR REPLACE FUNCTION public.invest_confirm_contribution(p_contribution UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  c public.group_contributions;
BEGIN
  SELECT * INTO c FROM public.group_contributions WHERE id = p_contribution FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'contribution_not_found'; END IF;
  PERFORM public._cg_require_member(c.group_id, ARRAY['leader', 'co_leader', 'treasurer']);
  IF c.user_id = v_uid THEN RAISE EXCEPTION 'cannot_confirm_own_payment'; END IF;
  IF c.status NOT IN ('pledged', 'marked_paid') THEN RAISE EXCEPTION 'contribution_not_pending'; END IF;
  UPDATE public.group_contributions
  SET status = 'confirmed', confirmed_by = v_uid, confirmed_at = NOW(), marked_at = COALESCE(marked_at, NOW())
  WHERE id = c.id;
  PERFORM public._cg_log(c.group_id, v_uid, 'contribution_confirmed',
    jsonb_build_object('contribution_id', c.id, 'user_id', c.user_id, 'amount', c.amount));
  PERFORM public._cg_system_message(c.group_id, public._cg_name(v_uid) || ' confirmed ' || public._cg_name(c.user_id)
    || '''s contribution of Rs ' || to_char(c.amount, 'FM999,999,999,990.00') || '.');
  PERFORM public._cg_notify(c.user_id, 'contribution_confirmed',
    'Your contribution of Rs ' || to_char(c.amount, 'FM999,999,999,990.00') || ' was confirmed', NULL, c.group_id,
    jsonb_build_object('contribution_id', c.id));
END;
$$;

CREATE OR REPLACE FUNCTION public.invest_cancel_pledge(p_contribution UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_uid UUID := public._cg_uid(); c public.group_contributions;
BEGIN
  SELECT * INTO c FROM public.group_contributions WHERE id = p_contribution FOR UPDATE;
  IF NOT FOUND OR c.user_id <> v_uid THEN RAISE EXCEPTION 'contribution_not_found'; END IF;
  IF c.status NOT IN ('pledged', 'marked_paid') THEN RAISE EXCEPTION 'contribution_not_pending'; END IF;
  UPDATE public.group_contributions SET status = 'cancelled' WHERE id = c.id;
  PERFORM public._cg_log(c.group_id, v_uid, 'contribution_cancelled', jsonb_build_object('contribution_id', c.id, 'amount', c.amount));
END;
$$;

CREATE OR REPLACE FUNCTION public.invest_create_proposal(
  p_group UUID, p_title TEXT, p_investment_type TEXT, p_amount NUMERIC, p_risk_level TEXT, p_reasoning TEXT,
  p_holding_period TEXT DEFAULT NULL, p_links TEXT[] DEFAULT '{}', p_expected_return_pct NUMERIC DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  v_role TEXT;
  g public.groups;
  s public.investment_settings;
  v_id UUID;
  v_vote UUID;
BEGIN
  v_role := public._cg_require_member(p_group);
  g := public._cg_group_for_update(p_group);
  SELECT * INTO s FROM public.investment_settings WHERE group_id = p_group;
  IF g.type <> 'investment' THEN RAISE EXCEPTION 'not_an_investment_group'; END IF;
  IF g.status = 'closed' THEN RAISE EXCEPTION 'group_read_only'; END IF;
  IF s.proposals_by = 'leader' AND v_role NOT IN ('leader', 'co_leader') THEN RAISE EXCEPTION 'not_group_officer'; END IF;
  IF p_risk_level IS NULL THEN RAISE EXCEPTION 'risk_level_required'; END IF;
  IF NOT (p_investment_type = ANY (s.allowed_types)) THEN RAISE EXCEPTION 'investment_type_not_allowed'; END IF;
  INSERT INTO public.group_proposals (group_id, created_by, title, investment_type, amount, holding_period,
    risk_level, reasoning, links, expected_return_pct)
  VALUES (p_group, v_uid, btrim(p_title), p_investment_type, round(p_amount, 2), NULLIF(btrim(p_holding_period), ''),
    p_risk_level, btrim(p_reasoning), COALESCE(p_links, '{}'), p_expected_return_pct)
  RETURNING id INTO v_id;
  v_vote := public._cg_open_vote(p_group, 'proposal', 'Proposal: ' || btrim(p_title),
    'Rs ' || to_char(p_amount, 'FM999,999,999,990.00') || ' in ' || p_investment_type || ', ' || p_risk_level || ' risk.',
    jsonb_build_object('proposal_id', v_id), v_uid);
  UPDATE public.group_proposals SET vote_id = v_vote WHERE id = v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.invest_withdraw_proposal(p_proposal UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_uid UUID := public._cg_uid(); p public.group_proposals; v_role TEXT;
BEGIN
  SELECT * INTO p FROM public.group_proposals WHERE id = p_proposal FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'proposal_not_found'; END IF;
  v_role := public._cg_require_member(p.group_id);
  IF p.created_by IS DISTINCT FROM v_uid AND v_role NOT IN ('leader', 'co_leader') THEN RAISE EXCEPTION 'not_group_officer'; END IF;
  IF p.status NOT IN ('voting', 'approved') THEN RAISE EXCEPTION 'proposal_not_open'; END IF;
  UPDATE public.group_proposals SET status = 'withdrawn' WHERE id = p.id;
  UPDATE public.group_votes SET status = 'cancelled', closed_at = NOW(), result_note = 'Proposal withdrawn'
  WHERE id = p.vote_id AND status = 'open';
  PERFORM public._cg_log(p.group_id, v_uid, 'proposal_withdrawn', jsonb_build_object('proposal_id', p.id));
END;
$$;

-- Records an investment the group made (outside the app). Needs a passed
-- proposal, unless the amount is within the leader's decision threshold.
CREATE OR REPLACE FUNCTION public.invest_record_investment(
  p_group UUID, p_title TEXT, p_investment_type TEXT, p_amount NUMERIC, p_made_on DATE,
  p_details TEXT DEFAULT NULL, p_proof_path TEXT DEFAULT NULL, p_proposal UUID DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  g public.groups;
  s public.investment_settings;
  pr public.group_proposals;
  v_cash NUMERIC;
  v_id UUID;
  v_proof TEXT := NULLIF(btrim(p_proof_path), '');
BEGIN
  PERFORM public._cg_require_member(p_group, ARRAY['leader', 'co_leader', 'treasurer']);
  g := public._cg_group_for_update(p_group);
  SELECT * INTO s FROM public.investment_settings WHERE group_id = p_group;
  IF g.type <> 'investment' THEN RAISE EXCEPTION 'not_an_investment_group'; END IF;
  IF g.status = 'closed' THEN RAISE EXCEPTION 'group_read_only'; END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  IF p_made_on IS NULL OR p_made_on > CURRENT_DATE THEN RAISE EXCEPTION 'invalid_date'; END IF;
  IF NOT (p_investment_type = ANY (s.allowed_types)) THEN RAISE EXCEPTION 'investment_type_not_allowed'; END IF;
  IF v_proof IS NOT NULL AND v_proof NOT LIKE 'groups/' || p_group::TEXT || '/receipts/%' THEN RAISE EXCEPTION 'invalid_attachment'; END IF;
  IF p_proposal IS NOT NULL THEN
    SELECT * INTO pr FROM public.group_proposals WHERE id = p_proposal AND group_id = p_group FOR UPDATE;
    IF NOT FOUND OR pr.status <> 'approved' THEN RAISE EXCEPTION 'proposal_not_approved'; END IF;
    IF p_amount > pr.amount THEN RAISE EXCEPTION 'above_approved_amount'; END IF;
  ELSIF p_amount > s.decision_threshold THEN
    RAISE EXCEPTION 'vote_required';
  END IF;
  v_cash := (public._cg_invest_position(p_group)->>'cash')::NUMERIC;
  IF p_amount > v_cash THEN RAISE EXCEPTION 'insufficient_pool'; END IF;
  INSERT INTO public.group_investments (group_id, proposal_id, title, investment_type, amount_invested, made_on,
    details, proof_path, approved_via, current_value, recorded_by)
  VALUES (p_group, p_proposal, btrim(p_title), p_investment_type, round(p_amount, 2), p_made_on,
    NULLIF(btrim(p_details), ''), v_proof, CASE WHEN p_proposal IS NULL THEN 'leader_under_threshold' ELSE 'vote' END,
    round(p_amount, 2), v_uid)
  RETURNING id INTO v_id;
  IF p_proposal IS NOT NULL THEN UPDATE public.group_proposals SET status = 'executed' WHERE id = p_proposal; END IF;
  PERFORM public._cg_log(p_group, v_uid, 'investment_recorded', jsonb_build_object(
    'investment_id', v_id, 'amount', round(p_amount, 2), 'type', p_investment_type, 'proposal_id', p_proposal));
  PERFORM public._cg_system_message(p_group, public._cg_name(v_uid) || ' recorded an investment: ' || btrim(p_title)
    || ' (Rs ' || to_char(p_amount, 'FM999,999,999,990.00') || ').');
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.invest_record_update(p_investment UUID, p_kind TEXT, p_amount NUMERIC, p_note TEXT DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  i public.group_investments;
BEGIN
  SELECT * INTO i FROM public.group_investments WHERE id = p_investment FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'investment_not_found'; END IF;
  PERFORM public._cg_require_member(i.group_id, ARRAY['leader', 'co_leader', 'treasurer']);
  IF i.status <> 'open' THEN RAISE EXCEPTION 'investment_closed'; END IF;
  IF p_kind NOT IN ('value', 'income', 'close') THEN RAISE EXCEPTION 'invalid_update'; END IF;
  IF p_amount IS NULL OR p_amount < 0 OR (p_kind = 'income' AND p_amount = 0) THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  INSERT INTO public.group_investment_updates (investment_id, group_id, kind, amount, note, recorded_by)
  VALUES (i.id, i.group_id, p_kind, round(p_amount, 2), NULLIF(btrim(p_note), ''), v_uid);
  IF p_kind = 'value' THEN
    UPDATE public.group_investments SET current_value = round(p_amount, 2) WHERE id = i.id;
  ELSIF p_kind = 'income' THEN
    UPDATE public.group_investments SET income_total = income_total + round(p_amount, 2) WHERE id = i.id;
  ELSE
    UPDATE public.group_investments
    SET closing_value = round(p_amount, 2), current_value = round(p_amount, 2), status = 'closed', closed_on = CURRENT_DATE
    WHERE id = i.id;
  END IF;
  PERFORM public._cg_log(i.group_id, v_uid, 'investment_' || p_kind,
    jsonb_build_object('investment_id', i.id, 'amount', round(p_amount, 2), 'note', NULLIF(btrim(p_note), '')));
  IF p_kind = 'close' THEN
    PERFORM public._cg_system_message(i.group_id, i.title || ' was closed at Rs ' || to_char(p_amount, 'FM999,999,999,990.00') || '.');
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.invest_dashboard(p_group UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_position JSONB;
  v_total NUMERIC;
BEGIN
  IF NOT public.cg_is_member(p_group) THEN RAISE EXCEPTION 'not_group_member'; END IF;
  v_position := public._cg_invest_position(p_group);
  SELECT COALESCE(SUM(confirmed), 0) INTO v_total FROM public._cg_member_contributions(p_group);
  RETURN v_position || jsonb_build_object('members', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'user_id', mc.user_id, 'display_name', public._cg_name(mc.user_id), 'confirmed', mc.confirmed,
      'share_pct', CASE WHEN v_total > 0 THEN round(100 * mc.confirmed / v_total, 4) ELSE 0 END,
      'pending', (SELECT COALESCE(SUM(amount), 0) FROM public.group_contributions c
                  WHERE c.group_id = p_group AND c.user_id = mc.user_id AND c.status IN ('pledged', 'marked_paid'))))
    FROM public._cg_member_contributions(p_group) mc), '[]'::jsonb));
END;
$$;

-- Splits a distribution by the group's rule. Members with no confirmed
-- contribution get nothing.
CREATE OR REPLACE FUNCTION public.invest_create_distribution(p_group UUID, p_total NUMERIC, p_note TEXT DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  g public.groups;
  s public.investment_settings;
  v_users UUID[];
  v_weights NUMERIC[];
  v_amounts NUMERIC[];
  v_sum NUMERIC;
  v_id UUID;
  i INT;
BEGIN
  PERFORM public._cg_require_member(p_group, ARRAY['leader', 'co_leader', 'treasurer']);
  g := public._cg_group_for_update(p_group);
  SELECT * INTO s FROM public.investment_settings WHERE group_id = p_group;
  IF g.type <> 'investment' THEN RAISE EXCEPTION 'not_an_investment_group'; END IF;
  IF g.status = 'closed' THEN RAISE EXCEPTION 'group_read_only'; END IF;
  IF p_total IS NULL OR p_total <= 0 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  IF round(p_total, 2) > (public._cg_invest_position(p_group)->>'cash')::NUMERIC THEN RAISE EXCEPTION 'insufficient_pool'; END IF;
  SELECT array_agg(mc.user_id ORDER BY mc.user_id),
         array_agg(CASE WHEN s.distribution_rule = 'equal' THEN 1 ELSE mc.confirmed END ORDER BY mc.user_id),
         SUM(mc.confirmed)
  INTO v_users, v_weights, v_sum
  FROM public._cg_member_contributions(p_group) mc WHERE mc.confirmed > 0;
  IF v_users IS NULL THEN RAISE EXCEPTION 'no_contributions'; END IF;
  v_amounts := public.cg_split_amount(round(p_total, 2), v_weights);
  INSERT INTO public.group_distributions (group_id, total_amount, rule, note, created_by)
  VALUES (p_group, round(p_total, 2), s.distribution_rule, NULLIF(btrim(p_note), ''), v_uid)
  RETURNING id INTO v_id;
  FOR i IN 1..cardinality(v_users) LOOP
    INSERT INTO public.group_distribution_shares (distribution_id, group_id, user_id, share_pct, amount)
    VALUES (v_id, p_group, v_users[i],
            round(100 * v_amounts[i] / round(p_total, 2), 4), v_amounts[i]);
    PERFORM public._cg_notify(v_users[i], 'distribution_created',
      'Distribution: your share is Rs ' || to_char(v_amounts[i], 'FM999,999,999,990.00'),
      'Confirm once you have received it.', p_group, jsonb_build_object('distribution_id', v_id));
  END LOOP;
  PERFORM public._cg_log(p_group, v_uid, 'distribution_created', jsonb_build_object(
    'distribution_id', v_id, 'total', round(p_total, 2), 'rule', s.distribution_rule));
  PERFORM public._cg_system_message(p_group, public._cg_name(v_uid) || ' created a distribution of Rs '
    || to_char(p_total, 'FM999,999,999,990.00') || ' (' || replace(s.distribution_rule, '_', '-') || ').');
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.invest_confirm_distribution(p_distribution UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  sh public.group_distribution_shares;
BEGIN
  SELECT * INTO sh FROM public.group_distribution_shares WHERE distribution_id = p_distribution AND user_id = v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'share_not_found'; END IF;
  IF sh.confirmed_at IS NOT NULL THEN RETURN; END IF;
  UPDATE public.group_distribution_shares SET confirmed_at = NOW() WHERE distribution_id = p_distribution AND user_id = v_uid;
  PERFORM public._cg_log(sh.group_id, v_uid, 'distribution_received', jsonb_build_object('distribution_id', p_distribution, 'amount', sh.amount));
  IF NOT EXISTS (SELECT 1 FROM public.group_distribution_shares WHERE distribution_id = p_distribution AND confirmed_at IS NULL) THEN
    UPDATE public.group_distributions SET status = 'completed' WHERE id = p_distribution;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public._cg_exit_quote(p_group UUID, p_user UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  s public.investment_settings;
  v_contribution NUMERIC;
  v_total NUMERIC;
  v_share NUMERIC;
  v_pool NUMERIC;
  v_joined TIMESTAMPTZ;
  v_lock BOOLEAN;
BEGIN
  SELECT * INTO s FROM public.investment_settings WHERE group_id = p_group;
  SELECT COALESCE(SUM(confirmed) FILTER (WHERE user_id = p_user), 0), COALESCE(SUM(confirmed), 0)
  INTO v_contribution, v_total FROM public._cg_member_contributions(p_group);
  v_share := CASE WHEN v_total > 0 THEN v_contribution / v_total ELSE 0 END;
  v_pool := (public._cg_invest_position(p_group)->>'pool_value')::NUMERIC;
  SELECT joined_at INTO v_joined FROM public.group_members WHERE group_id = p_group AND user_id = p_user;
  v_lock := v_joined + make_interval(months => s.lock_in_months) > NOW();
  RETURN jsonb_build_object(
    'method', s.exit_payout_method, 'contribution', v_contribution, 'share', round(v_share, 6),
    'pool_value', v_pool, 'in_lock_in', v_lock, 'penalty_pct', s.early_exit_penalty_pct,
    'payout', public.cg_exit_payout(s.exit_payout_method, v_contribution, v_share, v_pool, s.early_exit_penalty_pct, v_lock));
END;
$$;

CREATE OR REPLACE FUNCTION public.invest_request_exit(p_group UUID, p_reason TEXT DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  g public.groups;
  s public.investment_settings;
  v_quote JSONB;
  v_id UUID;
  v_vote UUID;
BEGIN
  PERFORM public._cg_require_member(p_group);
  g := public._cg_group_for_update(p_group);
  SELECT * INTO s FROM public.investment_settings WHERE group_id = p_group;
  IF g.type <> 'investment' THEN RAISE EXCEPTION 'not_an_investment_group'; END IF;
  IF g.status = 'closed' THEN RAISE EXCEPTION 'group_read_only'; END IF;
  IF EXISTS (SELECT 1 FROM public.group_exit_requests WHERE group_id = p_group AND user_id = v_uid AND status IN ('pending', 'approved')) THEN
    RAISE EXCEPTION 'exit_already_requested';
  END IF;
  v_quote := public._cg_exit_quote(p_group, v_uid);
  INSERT INTO public.group_exit_requests (group_id, user_id, reason, payout_amount, calculation)
  VALUES (p_group, v_uid, NULLIF(btrim(p_reason), ''), (v_quote->>'payout')::NUMERIC, v_quote)
  RETURNING id INTO v_id;
  PERFORM public._cg_log(p_group, v_uid, 'exit_requested', jsonb_build_object('request_id', v_id, 'quote', v_quote));
  IF s.exit_approval = 'vote' AND public._cg_active_count(p_group) > 1 THEN
    v_vote := public._cg_open_vote(p_group, 'exit', 'Approve ' || public._cg_name(v_uid) || '''s exit (Rs '
      || to_char((v_quote->>'payout')::NUMERIC, 'FM999,999,999,990.00') || ')', NULLIF(btrim(p_reason), ''),
      jsonb_build_object('request_id', v_id, 'user_id', v_uid), v_uid);
    UPDATE public.group_exit_requests SET vote_id = v_vote WHERE id = v_id;
  ELSE
    PERFORM public._cg_notify_members(p_group, 'exit_update', public._cg_name(v_uid) || ' asked to exit the group',
      NULLIF(btrim(p_reason), ''), jsonb_build_object('request_id', v_id), v_uid, ARRAY['leader', 'co_leader']);
  END IF;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public._cg_approve_exit(p_request UUID, p_actor UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  x public.group_exit_requests;
  v_quote JSONB;
BEGIN
  SELECT * INTO x FROM public.group_exit_requests WHERE id = p_request FOR UPDATE;
  IF NOT FOUND OR x.status <> 'pending' THEN RETURN; END IF;
  -- Recalculate at approval time so the payout reflects current values.
  v_quote := public._cg_exit_quote(x.group_id, x.user_id);
  UPDATE public.group_exit_requests
  SET status = 'approved', payout_amount = (v_quote->>'payout')::NUMERIC, calculation = v_quote,
      decided_by = p_actor, decided_at = NOW()
  WHERE id = x.id;
  PERFORM public._cg_log(x.group_id, p_actor, 'exit_approved', jsonb_build_object('request_id', x.id, 'quote', v_quote));
  PERFORM public._cg_notify(x.user_id, 'exit_update', 'Your exit was approved: Rs '
    || to_char((v_quote->>'payout')::NUMERIC, 'FM999,999,999,990.00'), 'Confirm once you have received it.',
    x.group_id, jsonb_build_object('request_id', x.id));
END;
$$;

CREATE OR REPLACE FUNCTION public.invest_decide_exit(p_request UUID, p_approve BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  x public.group_exit_requests;
BEGIN
  SELECT * INTO x FROM public.group_exit_requests WHERE id = p_request FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'request_not_found'; END IF;
  PERFORM public._cg_require_member(x.group_id, ARRAY['leader', 'co_leader']);
  IF x.user_id = v_uid THEN RAISE EXCEPTION 'cannot_decide_own_exit'; END IF;
  IF x.status <> 'pending' THEN RAISE EXCEPTION 'request_not_pending'; END IF;
  IF x.vote_id IS NOT NULL THEN RAISE EXCEPTION 'decided_by_vote'; END IF;
  IF p_approve THEN
    PERFORM public._cg_approve_exit(x.id, v_uid);
  ELSE
    UPDATE public.group_exit_requests SET status = 'declined', decided_by = v_uid, decided_at = NOW() WHERE id = x.id;
    PERFORM public._cg_log(x.group_id, v_uid, 'exit_declined', jsonb_build_object('request_id', x.id));
    PERFORM public._cg_notify(x.user_id, 'exit_update', 'Your exit request was declined', NULL, x.group_id,
      jsonb_build_object('request_id', x.id));
  END IF;
END;
$$;

-- The leaving member confirms they were paid; membership then ends.
CREATE OR REPLACE FUNCTION public.invest_confirm_exit_payout(p_request UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._cg_uid();
  x public.group_exit_requests;
  v_role TEXT;
BEGIN
  SELECT * INTO x FROM public.group_exit_requests WHERE id = p_request AND user_id = v_uid FOR UPDATE;
  IF NOT FOUND OR x.status <> 'approved' THEN RAISE EXCEPTION 'request_not_found'; END IF;
  v_role := public._cg_require_member(x.group_id);
  PERFORM public._cg_group_for_update(x.group_id);
  UPDATE public.group_exit_requests SET status = 'completed', completed_at = NOW() WHERE id = x.id;
  UPDATE public.group_contributions SET status = 'cancelled'
  WHERE group_id = x.group_id AND user_id = v_uid AND status IN ('pledged', 'marked_paid');
  UPDATE public.group_members SET status = 'left', left_at = NOW(), role = 'member' WHERE group_id = x.group_id AND user_id = v_uid;
  PERFORM public._cg_log(x.group_id, v_uid, 'exit_completed', jsonb_build_object('request_id', x.id, 'payout', x.payout_amount));
  PERFORM public._cg_system_message(x.group_id, public._cg_name(v_uid) || ' confirmed their exit payout of Rs '
    || to_char(x.payout_amount, 'FM999,999,999,990.00') || ' and left the group.');
  IF v_role = 'leader' THEN PERFORM public._cg_replace_leader(x.group_id, v_uid, 'left'); END IF;
END;
$$;

-- ------------------------------------------------------------
-- 15. FinBot snapshot (the caller's own figures only)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.community_my_snapshot()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_uid UUID := public._cg_uid();
BEGIN
  RETURN jsonb_build_object(
    'groups', (SELECT COUNT(*) FROM public.group_members m JOIN public.groups g ON g.id = m.group_id
               WHERE m.user_id = v_uid AND m.status = 'active' AND g.status <> 'closed'),
    'next_seettu_payment', (
      SELECT jsonb_build_object('group', g.name, 'round_no', r.round_no, 'due_date', r.due_date, 'amount', p.amount_due, 'status', p.status)
      FROM public.seettu_payments p
      JOIN public.seettu_rounds r ON r.id = p.round_id
      JOIN public.groups g ON g.id = p.group_id
      JOIN public.group_members m ON m.group_id = p.group_id AND m.user_id = v_uid AND m.status = 'active'
      WHERE p.payer_id = v_uid AND p.status IN ('pending', 'late', 'marked_paid')
      ORDER BY r.due_date LIMIT 1),
    'confirmed_contributions', (
      SELECT COALESCE(SUM(c.amount), 0) FROM public.group_contributions c
      JOIN public.group_members m ON m.group_id = c.group_id AND m.user_id = v_uid AND m.status = 'active'
      WHERE c.user_id = v_uid AND c.status = 'confirmed'));
END;
$$;

-- ------------------------------------------------------------
-- 16. Scheduled work (pg_cron). Not callable by clients.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._cg_cron_frequent()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v RECORD;
BEGIN
  FOR v IN SELECT id FROM public.group_votes WHERE status = 'open' AND deadline <= NOW() ORDER BY deadline LIMIT 200 LOOP
    BEGIN
      PERFORM public._cg_close_vote(v.id);
    EXCEPTION WHEN others THEN
      RAISE WARNING 'closing vote % failed: %', v.id, SQLERRM;
    END;
  END LOOP;
  -- Reminder 12 hours before a vote closes, to members who haven't voted.
  FOR v IN SELECT * FROM public.group_votes
           WHERE status = 'open' AND NOT reminder_sent AND deadline <= NOW() + INTERVAL '12 hours' AND deadline > NOW() LOOP
    INSERT INTO public.notifications (user_id, kind, title, group_id, data)
    SELECT m.user_id, 'vote_closing_soon', 'Closing soon: ' || left(v.title, 80), v.group_id, jsonb_build_object('vote_id', v.id)
    FROM public.group_members m
    WHERE m.group_id = v.group_id AND m.status = 'active'
      AND NOT EXISTS (SELECT 1 FROM public.group_vote_ballots b WHERE b.vote_id = v.id AND b.user_id = m.user_id);
    UPDATE public.group_votes SET reminder_sent = TRUE WHERE id = v.id;
  END LOOP;
  UPDATE public.polls SET closed_at = deadline WHERE closed_at IS NULL AND deadline <= NOW();
END;
$$;

CREATE OR REPLACE FUNCTION public._cg_cron_daily()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE rec RECORD;
BEGIN
  -- Seettu reminders: 3 days and 1 day before, and on the due date.
  INSERT INTO public.notifications (user_id, kind, title, body, group_id, data)
  SELECT p.payer_id, 'seettu_payment_due',
         CASE r.due_date - CURRENT_DATE WHEN 0 THEN 'Seettu payment due today'
           ELSE 'Seettu payment due in ' || (r.due_date - CURRENT_DATE) || ' day' || CASE WHEN r.due_date - CURRENT_DATE > 1 THEN 's' ELSE '' END END,
         g.name || ': Rs ' || to_char(p.amount_due, 'FM999,999,999,990.00') || ' for round ' || r.round_no,
         p.group_id, jsonb_build_object('payment_id', p.id)
  FROM public.seettu_payments p
  JOIN public.seettu_rounds r ON r.id = p.round_id
  JOIN public.groups g ON g.id = p.group_id AND g.status = 'active'
  WHERE p.status = 'pending' AND r.due_date - CURRENT_DATE IN (0, 1, 3);

  -- Overdue: mark late once, tell the payer and the group.
  FOR rec IN
    UPDATE public.seettu_payments p SET status = 'late'
    FROM public.seettu_rounds rd
    WHERE rd.id = p.round_id AND p.status = 'pending' AND rd.due_date < CURRENT_DATE
    RETURNING p.id, p.group_id, p.payer_id, rd.round_no
  LOOP
    PERFORM public._cg_notify(rec.payer_id, 'seettu_payment_overdue', 'Your round ' || rec.round_no || ' seettu payment is overdue',
      NULL, rec.group_id, jsonb_build_object('payment_id', rec.id));
    PERFORM public._cg_system_message(rec.group_id, public._cg_name(rec.payer_id) || '''s round ' || rec.round_no || ' payment is overdue.');
    PERFORM public._cg_log(rec.group_id, NULL, 'seettu_payment_late', jsonb_build_object('payment_id', rec.id, 'payer_id', rec.payer_id, 'round_no', rec.round_no));
  END LOOP;

  -- Leaders inactive for 30 days are replaced.
  FOR rec IN
    SELECT m.group_id, m.user_id FROM public.group_members m JOIN public.groups g ON g.id = m.group_id
    WHERE m.role = 'leader' AND m.status = 'active' AND g.status <> 'closed'
      AND m.last_active_at < NOW() - INTERVAL '30 days'
      AND EXISTS (SELECT 1 FROM public.group_members o WHERE o.group_id = m.group_id AND o.status = 'active' AND o.user_id <> m.user_id)
  LOOP
    PERFORM public._cg_replace_leader(rec.group_id, rec.user_id, 'inactive');
  END LOOP;
END;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'community-frequent') THEN
      PERFORM cron.schedule('community-frequent', '*/5 * * * *', 'SELECT public._cg_cron_frequent()');
    END IF;
    -- 02:30 UTC = 08:00 in Sri Lanka.
    IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'community-daily') THEN
      PERFORM cron.schedule('community-daily', '30 2 * * *', 'SELECT public._cg_cron_daily()');
    END IF;
  END IF;
END $$;

-- ------------------------------------------------------------
-- 17. Storage: one private bucket.
--   avatars/<user id>/…            profile photos (any signed-in user reads)
--   group-photos/<group id>/…      group photos (any signed-in user reads)
--   groups/<group id>/chat/…       chat images (members only)
--   groups/<group id>/receipts/…   receipts and proofs (members only)
-- ------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('community', 'community', FALSE, 5242880,
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "community read" ON storage.objects;
CREATE POLICY "community read" ON storage.objects FOR SELECT TO authenticated USING (
  bucket_id = 'community' AND (
    (storage.foldername(name))[1] IN ('avatars', 'group-photos')
    OR ((storage.foldername(name))[1] = 'groups'
        AND public.cg_is_member(public.cg_try_uuid((storage.foldername(name))[2])))));

DROP POLICY IF EXISTS "community upload" ON storage.objects;
CREATE POLICY "community upload" ON storage.objects FOR INSERT TO authenticated WITH CHECK (
  bucket_id = 'community' AND (
    ((storage.foldername(name))[1] = 'avatars' AND (storage.foldername(name))[2] = auth.uid()::TEXT)
    OR ((storage.foldername(name))[1] = 'group-photos'
        AND EXISTS (SELECT 1 FROM public.group_members m
                    WHERE m.group_id = public.cg_try_uuid((storage.foldername(name))[2])
                      AND m.user_id = auth.uid() AND m.status = 'active' AND m.role IN ('leader', 'co_leader')))
    OR ((storage.foldername(name))[1] = 'groups'
        AND (storage.foldername(name))[3] IN ('chat', 'receipts')
        AND public.cg_is_member(public.cg_try_uuid((storage.foldername(name))[2])))));
-- No delete policy: receipts and chat images are part of the group record.

-- ------------------------------------------------------------
-- 18. Realtime
-- ------------------------------------------------------------
DO $$
DECLARE t TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN RETURN; END IF;
  FOREACH t IN ARRAY ARRAY['group_messages', 'poll_votes', 'poll_options', 'group_votes',
                           'group_vote_ballots', 'notifications', 'seettu_payments'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                   WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;

-- ------------------------------------------------------------
-- 19. Function privileges: internal helpers are not callable by clients;
-- RPCs only by signed-in users.
-- ------------------------------------------------------------
DO $$
DECLARE f RECORD;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS sig, p.proname
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND (p.proname LIKE '\_cg\_%' OR p.proname LIKE 'cg\_%' OR p.proname LIKE 'community\_%'
           OR p.proname LIKE 'connection\_%' OR p.proname LIKE 'group\_%' OR p.proname LIKE 'poll\_%'
           OR p.proname LIKE 'vote\_%' OR p.proname LIKE 'seettu\_%' OR p.proname LIKE 'invest\_%')
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', f.sig);
    IF f.proname LIKE '\_cg\_%' THEN
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM authenticated', f.sig);
    ELSE
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f.sig);
    END IF;
  END LOOP;
END $$;
