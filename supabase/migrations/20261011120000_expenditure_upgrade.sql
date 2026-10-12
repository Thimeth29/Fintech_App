-- ============================================================
-- Expenditure upgrade: expense dates/priorities, recurring expenses,
-- budgets delete, finance settings, savings goals, debts & loans.
--
-- Additive only: no existing column is changed or dropped, so the
-- current expense rows keep working. Safe to run once; guarded with
-- IF NOT EXISTS where Postgres allows it.
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
