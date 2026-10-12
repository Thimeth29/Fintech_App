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
    IF FOUND AND h.direction <> (CASE WHEN p_side = 'buy' THEN 'long' ELSE 'short' END) THEN
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
    IF NOT FOUND OR h.direction <> (CASE WHEN p_side = 'sell' THEN 'long' ELSE 'short' END)
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
