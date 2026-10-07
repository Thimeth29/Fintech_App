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
  guardian_status TEXT DEFAULT 'pending',
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
