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
