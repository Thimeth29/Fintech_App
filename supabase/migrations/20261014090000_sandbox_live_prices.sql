-- ============================================================
-- INVESTMENT TRAINER: LIVE PRICES, FOREX AND COMMUNITY FUND
--
-- 1. market_prices / market_price_history: real Sri Lankan market data
--    written by the scheduled scraper (scraper/, service-role key) and
--    only ever READ by the app. The app subscribes to market_prices with
--    Supabase Realtime, so a new scrape shows up on screen without polling.
--    Symbols share one key space with the trainer:
--      stock        JKH.N, COMB.N ...        LKR per share   (CSE)
--      gold         GOLD24K                  LKR per gram    (CBSL XAU / 31.1035)
--      forex        USDLKR, EURLKR ...       LKR per 1 unit  (CBSL indicative)
--      fd_rate      FD|<institution>|<m>     % p.a.          (bank websites)
--      tbill_yield  TBILL_91/182/364         % p.a.          (BOC weekly table)
--      tbond_yield  TBOND_2Y/5Y/10Y          % p.a.
-- 2. Two new trainer modules: 'forex' (tradable, like gold) and
--    'community_fund' (a simulated seettu, see sandbox_circles).
-- 3. Term instruments (FD, T-bill, T-bond) withdrawn early now pay what
--    has accrued so far at the locked rate, computed HERE on the server
--    (_sandbox_withdrawal_amount). The client's amount is display only.
--
-- Runs after 20261012090000_sandbox_trainer.sql. Safe to re-run.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Market data
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.market_prices (
  symbol TEXT PRIMARY KEY CHECK (length(symbol) BETWEEN 1 AND 64),
  kind TEXT NOT NULL CHECK (kind IN ('stock', 'gold', 'forex', 'fd_rate', 'tbill_yield', 'tbond_yield')),
  name TEXT NOT NULL,
  -- LKR for stock/gold/forex, % p.a. for the *_rate / *_yield kinds.
  price NUMERIC(18, 6) NOT NULL CHECK (price > 0),
  unit TEXT NOT NULL,
  change_pct NUMERIC(9, 4),
  source TEXT NOT NULL,          -- 'CBSL', 'CSE', 'Bank of Ceylon', ...
  source_url TEXT,
  as_of TIMESTAMPTZ NOT NULL,    -- when the source published the value
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- One row per symbol per day (the last scrape of the day wins), for charts.
CREATE TABLE IF NOT EXISTS public.market_price_history (
  symbol TEXT NOT NULL CHECK (length(symbol) BETWEEN 1 AND 64),
  price_date DATE NOT NULL,
  price NUMERIC(18, 6) NOT NULL CHECK (price > 0),
  source TEXT NOT NULL,
  PRIMARY KEY (symbol, price_date)
);
CREATE INDEX IF NOT EXISTS market_prices_kind_idx ON public.market_prices (kind);

ALTER TABLE public.market_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.market_price_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read market prices" ON public.market_prices;
CREATE POLICY "Anyone can read market prices" ON public.market_prices FOR SELECT USING (true);
DROP POLICY IF EXISTS "Anyone can read market price history" ON public.market_price_history;
CREATE POLICY "Anyone can read market price history" ON public.market_price_history FOR SELECT USING (true);
-- Only the scraper (service_role, which bypasses RLS) writes.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.market_prices, public.market_price_history FROM anon, authenticated;
GRANT SELECT ON public.market_prices, public.market_price_history TO anon, authenticated;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN RETURN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                 WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'market_prices') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.market_prices;
  END IF;
END $$;

-- ------------------------------------------------------------
-- 2. New modules in the CHECK constraints
-- ------------------------------------------------------------
-- Drops whichever CHECK on [p_table] mentions [p_column] (the original ones
-- were unnamed column constraints), so the new named one replaces it.
CREATE OR REPLACE FUNCTION public._sandbox_drop_checks(p_table TEXT, p_column TEXT)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE c RECORD;
BEGIN
  FOR c IN
    SELECT con.conname
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace ns ON ns.oid = rel.relnamespace
    WHERE ns.nspname = 'public' AND rel.relname = p_table AND con.contype = 'c'
      AND pg_get_constraintdef(con.oid) ~ ('\m' || p_column || '\M')
      AND pg_get_constraintdef(con.oid) ~* '\mIN\M|ANY'
  LOOP
    EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT %I', p_table, c.conname);
  END LOOP;
END;
$$;

SELECT public._sandbox_drop_checks('sandbox_wallets', 'module');
ALTER TABLE public.sandbox_wallets ADD CONSTRAINT sandbox_wallets_module_check
  CHECK (module IN ('cse', 'fd', 'gold', 'trading', 'gov_securities', 'forex', 'community_fund'));

SELECT public._sandbox_drop_checks('sandbox_holdings', 'module');
ALTER TABLE public.sandbox_holdings ADD CONSTRAINT sandbox_holdings_module_check
  CHECK (module IN ('cse', 'gold', 'trading', 'forex'));

SELECT public._sandbox_drop_checks('sandbox_lesson_progress', 'module');
ALTER TABLE public.sandbox_lesson_progress ADD CONSTRAINT sandbox_lesson_progress_module_check
  CHECK (module IN ('cse', 'fd', 'gold', 'trading', 'gov_securities', 'forex', 'community_fund'));

SELECT public._sandbox_drop_checks('sandbox_trades', 'module');
ALTER TABLE public.sandbox_trades ADD CONSTRAINT sandbox_trades_module_check
  CHECK (module IN ('cse', 'fd', 'gold', 'trading', 'gov_securities', 'forex', 'community_fund'));

SELECT public._sandbox_drop_checks('sandbox_trades', 'side');
ALTER TABLE public.sandbox_trades ADD CONSTRAINT sandbox_trades_side_check CHECK (side IN (
  'buy', 'sell', 'short', 'cover',
  'fd_open', 'fd_interest', 'fd_mature', 'fd_renew', 'fd_break',
  'tbill_buy', 'tbill_mature', 'tbill_break', 'tbond_buy', 'tbond_coupon', 'tbond_mature', 'tbond_sell',
  'dividend', 'updown_stake', 'updown_payout',
  'seettu_pay', 'seettu_pot'));

DROP FUNCTION public._sandbox_drop_checks(TEXT, TEXT);

-- ------------------------------------------------------------
-- 3. Community fund: simulated seettu circles
--
-- The user is one of [members]. Round k (1..members) falls on
-- start_sim_date + (k-1) months: everyone pays [contribution] and one
-- member takes the pot. The user's pot comes in round [my_turn]. Round 1
-- happens when the user joins; later rounds happen during fast-forward.
-- Simulated members who already took their pot may stop paying (more
-- likely with 'strangers'), which shrinks later pots: the client works
-- that out and the server checks the pot stays within bounds.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sandbox_circles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 60),
  members INT NOT NULL CHECK (members BETWEEN 3 AND 24),
  contribution NUMERIC(14, 2) NOT NULL CHECK (contribution > 0),
  my_turn INT NOT NULL CHECK (my_turn >= 1),
  trust TEXT NOT NULL CHECK (trust IN ('known', 'strangers')),
  start_sim_date DATE NOT NULL,
  rounds_paid INT NOT NULL DEFAULT 0 CHECK (rounds_paid >= 0),
  total_paid NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (total_paid >= 0),
  pot_received NUMERIC(14, 2) CHECK (pot_received >= 0),  -- NULL until the user's turn
  pot_sim_date DATE,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'completed', 'archived')),
  reset_batch UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (my_turn <= members),
  CHECK (rounds_paid <= members)
);
CREATE INDEX IF NOT EXISTS sandbox_circles_user_idx ON public.sandbox_circles (user_id, status);

ALTER TABLE public.sandbox_circles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own sandbox_circles" ON public.sandbox_circles;
CREATE POLICY "Users can view own sandbox_circles" ON public.sandbox_circles FOR SELECT USING (auth.uid() = user_id);
REVOKE INSERT, UPDATE, DELETE ON public.sandbox_circles FROM anon, authenticated;

-- ------------------------------------------------------------
-- 4. Helpers (not callable by clients)
-- ------------------------------------------------------------
-- What an open FD / T-bill / T-bond pays if withdrawn on [p_now]: the
-- principal (or, for a T-bill, the price paid) plus interest accrued so far
-- at the rate locked in when it was opened, after the 10% withholding tax
-- (kInterestWhtRate / kGovSecWhtRate in sandbox_config.dart). Interest
-- already paid out (monthly FD interest, bond coupons) isn't paid twice.
-- Must match TermEngine.withdrawalAmount() in trading_engine.dart.
CREATE OR REPLACE FUNCTION public._sandbox_withdrawal_amount(p public.sandbox_positions, p_now DATE)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  v_from DATE;
  v_days INT;
  v_total INT;
  v_rate NUMERIC;
BEGIN
  IF p.type = 'tbill' THEN
    v_total := p.maturity_sim_date - p.start_sim_date;
    v_days := LEAST(GREATEST(p_now - p.start_sim_date, 0), v_total);
    RETURN round(p.cost + (p.principal - p.cost) * 0.9 * v_days / GREATEST(v_total, 1), 2);
  END IF;
  -- Interest-at-maturity FDs accrue from the start of the current term;
  -- payout products accrue from their last payout.
  v_from := CASE WHEN p.type = 'fd' AND p.payout_type = 'maturity' THEN p.start_sim_date
                 ELSE COALESCE(p.last_payout_sim_date, p.start_sim_date) END;
  v_days := LEAST(GREATEST(p_now - v_from, 0), GREATEST(p.maturity_sim_date - v_from, 0));
  v_rate := CASE WHEN p.type = 'tbond' THEN COALESCE(p.coupon_rate, p.rate) ELSE p.rate END;
  RETURN round(p.principal + p.principal * v_rate / 100 * v_days / 365 * 0.9, 2);
END;
$$;

-- Round [p_round] (1-based) of a circle.
CREATE OR REPLACE FUNCTION public._sandbox_circle_round_date(p_start DATE, p_round INT)
RETURNS DATE
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT (p_start + make_interval(months => p_round - 1))::date;
$$;

-- ------------------------------------------------------------
-- 5. RPCs updated for the new modules
-- ------------------------------------------------------------
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
  IF p_module NOT IN ('cse', 'fd', 'gold', 'trading', 'gov_securities', 'forex', 'community_fund') THEN
    RAISE EXCEPTION 'invalid_module';
  END IF;
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
    UPDATE public.sandbox_wallets SET price_anchors = p_anchors || price_anchors, updated_at = NOW()
    WHERE id = w.id RETURNING * INTO w;
  END IF;
  RETURN to_jsonb(w);
END;
$$;

-- Buy / sell (cse, gold, forex, trading) and short / cover (trading only).
-- Same as the sandbox_trainer version, plus the forex module.
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
  IF p_module NOT IN ('cse', 'gold', 'trading', 'forex') THEN RAISE EXCEPTION 'invalid_module'; END IF;
  IF p_side NOT IN ('buy', 'sell', 'short', 'cover') THEN RAISE EXCEPTION 'invalid_side'; END IF;
  IF p_quantity IS NULL OR p_quantity <= 0 THEN RAISE EXCEPTION 'invalid_quantity'; END IF;
  IF p_module = 'cse' AND p_quantity <> trunc(p_quantity) THEN RAISE EXCEPTION 'whole_shares_only'; END IF;
  IF p_price IS NULL OR p_price <= 0 THEN RAISE EXCEPTION 'invalid_price'; END IF;
  p_fee := COALESCE(p_fee, 0);
  v_gross := round(p_price * p_quantity, 2);
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

-- Withdraws an FD, T-bill or T-bond before maturity. The server computes
-- the payout (_sandbox_withdrawal_amount): principal + interest accrued so
-- far at the locked rate. You give up the rest of the return, not your
-- principal. p_amount (the client's estimate) is accepted for backwards
-- compatibility but ignored.
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
  v_amount NUMERIC;
  v_side TEXT;
  v_pnl NUMERIC;
BEGIN
  SELECT * INTO p FROM public.sandbox_positions WHERE id = p_position_id AND user_id = v_uid;
  IF NOT FOUND THEN RAISE EXCEPTION 'position_not_found'; END IF;
  w := public._sandbox_wallet_for_update(v_uid, p.module);
  SELECT * INTO p FROM public.sandbox_positions WHERE id = p_position_id FOR UPDATE;
  IF p.status <> 'open' OR p.reset_batch <> w.current_reset_batch THEN RAISE EXCEPTION 'position_not_open'; END IF;
  IF w.sim_date >= p.maturity_sim_date THEN RAISE EXCEPTION 'position_matured'; END IF;

  v_amount := public._sandbox_withdrawal_amount(p, w.sim_date);
  v_side := CASE p.type WHEN 'fd' THEN 'fd_break' WHEN 'tbill' THEN 'tbill_break' ELSE 'tbond_sell' END;
  v_pnl := round(v_amount + p.total_paid - p.cost, 2);

  UPDATE public.sandbox_positions SET status = 'closed_early', closed_amount = v_amount,
    closed_sim_date = w.sim_date, updated_at = NOW()
  WHERE id = p.id RETURNING * INTO p;
  UPDATE public.sandbox_wallets SET balance = balance + v_amount, updated_at = NOW()
  WHERE id = w.id RETURNING * INTO w;

  INSERT INTO public.sandbox_trades (user_id, module, symbol, side, quantity, price, cash_delta,
    realised_pnl, ref_id, sim_date, reset_batch)
  VALUES (v_uid, p.module, p.label, v_side, p.principal, v_amount / p.principal * 100, v_amount, v_pnl, p.id,
    w.sim_date, w.current_reset_batch);

  RETURN jsonb_build_object('balance', w.balance, 'wallet', to_jsonb(w), 'position', to_jsonb(p),
    'amount', v_amount, 'realised_pnl', v_pnl);
END;
$$;

-- Joins a simulated seettu. Round 1 happens now: the user pays their first
-- contribution and, if their turn is 1, takes the pot straight away.
-- The wallet must be able to cover every contribution still owed across all
-- open circles (a seettu is a promise to keep paying, even after your pot).
CREATE OR REPLACE FUNCTION public.sandbox_join_circle(
  p_name TEXT,
  p_members INT,
  p_contribution NUMERIC,
  p_my_turn INT,
  p_trust TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := public._sandbox_uid();
  w public.sandbox_wallets;
  c public.sandbox_circles;
  v_committed NUMERIC;
  v_pot NUMERIC;
BEGIN
  IF p_members IS NULL OR p_members < 3 OR p_members > 24 THEN RAISE EXCEPTION 'invalid_members'; END IF;
  IF p_contribution IS NULL OR p_contribution <= 0 OR p_contribution > 100000 THEN RAISE EXCEPTION 'invalid_amount'; END IF;
  p_contribution := round(p_contribution, 2);
  IF p_my_turn IS NULL OR p_my_turn < 1 OR p_my_turn > p_members THEN RAISE EXCEPTION 'invalid_turn'; END IF;
  IF p_trust NOT IN ('known', 'strangers') THEN RAISE EXCEPTION 'invalid_trust'; END IF;

  w := public._sandbox_wallet_for_update(v_uid, 'community_fund');
  SELECT COALESCE(SUM(contribution * (members - rounds_paid)), 0) INTO v_committed
  FROM public.sandbox_circles
  WHERE user_id = v_uid AND status = 'open' AND reset_batch = w.current_reset_batch;
  IF w.balance < v_committed + p_contribution * p_members THEN RAISE EXCEPTION 'seettu_unaffordable'; END IF;

  INSERT INTO public.sandbox_circles (user_id, name, members, contribution, my_turn, trust, start_sim_date,
    rounds_paid, total_paid, reset_batch)
  VALUES (v_uid, left(COALESCE(NULLIF(trim(p_name), ''), 'Seettu'), 60), p_members, p_contribution, p_my_turn,
    p_trust, w.sim_date, 1, p_contribution, w.current_reset_batch)
  RETURNING * INTO c;

  UPDATE public.sandbox_wallets SET balance = balance - p_contribution, updated_at = NOW()
  WHERE id = w.id RETURNING * INTO w;
  INSERT INTO public.sandbox_trades (user_id, module, symbol, side, quantity, price, cash_delta, ref_id, sim_date, reset_batch)
  VALUES (v_uid, 'community_fund', c.name, 'seettu_pay', 1, p_contribution, -p_contribution, c.id, w.sim_date,
    w.current_reset_batch);

  IF p_my_turn = 1 THEN
    -- Nobody has had a chance to default yet, so the first pot is full.
    v_pot := p_contribution * p_members;
    UPDATE public.sandbox_circles SET pot_received = v_pot, pot_sim_date = w.sim_date, updated_at = NOW()
    WHERE id = c.id RETURNING * INTO c;
    UPDATE public.sandbox_wallets SET balance = balance + v_pot, updated_at = NOW()
    WHERE id = w.id RETURNING * INTO w;
    INSERT INTO public.sandbox_trades (user_id, module, symbol, side, quantity, price, cash_delta, ref_id, sim_date, reset_batch)
    VALUES (v_uid, 'community_fund', c.name, 'seettu_pot', 1, v_pot, v_pot, c.id, w.sim_date, w.current_reset_batch);
  END IF;

  RETURN jsonb_build_object('balance', w.balance, 'wallet', to_jsonb(w), 'circle', to_jsonb(c));
END;
$$;

-- Fast-forward, now also for forex (clock only) and the community fund
-- (seettu rounds). Seettu events:
--   {"kind": "seettu_pay", "circle_id": uuid, "amount": contribution, "sim_date": round date}
--   {"kind": "seettu_pot", "circle_id": uuid, "amount": pot, "sim_date": the user's round date}
-- Payments take money OUT of the wallet; the running balance may never go
-- below zero.
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
  c public.sandbox_circles;
  e JSONB;
  v_kind TEXT;
  v_amount NUMERIC;
  v_date DATE;
  v_new_date DATE;
  v_total NUMERIC := 0;
  v_applied INT := 0;
BEGIN
  IF p_module NOT IN ('cse', 'fd', 'gold', 'gov_securities', 'forex', 'community_fund') THEN
    RAISE EXCEPTION 'invalid_module';
  END IF;
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

    IF v_kind IN ('seettu_pay', 'seettu_pot') THEN
      IF p_module <> 'community_fund' THEN RAISE EXCEPTION 'invalid_event'; END IF;
      SELECT * INTO c FROM public.sandbox_circles
      WHERE id = (e->>'circle_id')::uuid AND user_id = v_uid FOR UPDATE;
      IF NOT FOUND OR c.status <> 'open' OR c.reset_batch <> w.current_reset_batch THEN
        RAISE EXCEPTION 'circle_not_open';
      END IF;
      IF v_kind = 'seettu_pay' THEN
        IF c.rounds_paid >= c.members OR v_amount <> c.contribution THEN RAISE EXCEPTION 'invalid_event'; END IF;
        IF v_date <> public._sandbox_circle_round_date(c.start_sim_date, c.rounds_paid + 1) THEN
          RAISE EXCEPTION 'invalid_event_date';
        END IF;
        UPDATE public.sandbox_circles SET rounds_paid = rounds_paid + 1, total_paid = total_paid + v_amount,
          updated_at = NOW() WHERE id = c.id RETURNING * INTO c;
        v_total := v_total - v_amount;
      ELSE
        -- The pot is everyone still paying that round: at least the user's
        -- own contribution, at most the whole circle's.
        IF c.pot_received IS NOT NULL OR c.rounds_paid < c.my_turn
           OR v_amount < c.contribution OR v_amount > c.contribution * c.members THEN
          RAISE EXCEPTION 'invalid_event';
        END IF;
        IF v_date <> public._sandbox_circle_round_date(c.start_sim_date, c.my_turn) THEN
          RAISE EXCEPTION 'invalid_event_date';
        END IF;
        UPDATE public.sandbox_circles SET pot_received = v_amount, pot_sim_date = v_date, updated_at = NOW()
        WHERE id = c.id RETURNING * INTO c;
        v_total := v_total + v_amount;
      END IF;
      IF w.balance + v_total < 0 THEN RAISE EXCEPTION 'insufficient_balance'; END IF;
      IF c.rounds_paid = c.members AND c.pot_received IS NOT NULL THEN
        UPDATE public.sandbox_circles SET status = 'completed', updated_at = NOW() WHERE id = c.id;
      END IF;
      INSERT INTO public.sandbox_trades (user_id, module, symbol, side, quantity, price, cash_delta, ref_id,
        sim_date, reset_batch)
      VALUES (v_uid, 'community_fund', c.name, v_kind, 1, v_amount,
        CASE WHEN v_kind = 'seettu_pay' THEN -v_amount ELSE v_amount END, c.id, v_date, w.current_reset_batch);

    ELSIF v_kind = 'dividend' THEN
      IF p_module <> 'cse' THEN RAISE EXCEPTION 'invalid_event'; END IF;
      SELECT * INTO h FROM public.sandbox_holdings
      WHERE user_id = v_uid AND module = 'cse' AND symbol = e->>'symbol';
      IF NOT FOUND OR v_amount > h.quantity * h.average_price * 0.20 THEN RAISE EXCEPTION 'invalid_event'; END IF;
      INSERT INTO public.sandbox_trades (user_id, module, symbol, side, quantity, price, cash_delta, sim_date, reset_batch)
      VALUES (v_uid, 'cse', h.symbol, 'dividend', h.quantity, v_amount / h.quantity, v_amount, v_date, w.current_reset_batch);
      v_total := v_total + v_amount;

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
        IF p.type <> 'fd' OR NOT p.auto_renew OR v_date <> p.maturity_sim_date THEN RAISE EXCEPTION 'invalid_event'; END IF;
        UPDATE public.sandbox_positions SET
          principal = principal + v_amount,
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
      IF v_kind <> 'fd_renew' THEN v_total := v_total + v_amount; END IF;
    END IF;

    v_applied := v_applied + 1;
  END LOOP;

  UPDATE public.sandbox_wallets SET balance = balance + v_total, sim_date = v_new_date, updated_at = NOW()
  WHERE id = w.id RETURNING * INTO w;

  RETURN jsonb_build_object('balance', w.balance, 'wallet', to_jsonb(w), 'applied', v_applied, 'paid', v_total);
END;
$$;

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
  IF p_module IS NOT NULL
     AND p_module NOT IN ('cse', 'fd', 'gold', 'trading', 'gov_securities', 'forex', 'community_fund') THEN
    RAISE EXCEPTION 'invalid_module';
  END IF;
  IF p_module IS NOT NULL AND p_reset_learning THEN RAISE EXCEPTION 'invalid_reset'; END IF;

  FOR w IN SELECT * FROM public.sandbox_wallets
           WHERE user_id = v_uid AND (p_module IS NULL OR module = p_module) FOR UPDATE LOOP
    UPDATE public.sandbox_positions SET status = 'archived', updated_at = NOW()
    WHERE user_id = v_uid AND module = w.module AND status = 'open';
    IF w.module = 'community_fund' THEN
      UPDATE public.sandbox_circles SET status = 'archived', updated_at = NOW()
      WHERE user_id = v_uid AND status = 'open';
    END IF;
    DELETE FROM public.sandbox_holdings WHERE user_id = v_uid AND module = w.module;
    UPDATE public.sandbox_wallets SET
      balance = 100000.00,
      sim_date = CURRENT_DATE,
      start_date = CURRENT_DATE,
      price_anchors = '{}'::jsonb,
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
  IF p_module NOT IN ('cse', 'fd', 'gold', 'trading', 'gov_securities', 'forex', 'community_fund') THEN
    RAISE EXCEPTION 'invalid_module';
  END IF;
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
  IF p_module NOT IN ('cse', 'fd', 'gold', 'trading', 'gov_securities', 'forex', 'community_fund') THEN
    RAISE EXCEPTION 'invalid_module';
  END IF;
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

-- ------------------------------------------------------------
-- 6. Function privileges
-- ------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public._sandbox_withdrawal_amount(public.sandbox_positions, DATE) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public._sandbox_circle_round_date(DATE, INT) FROM PUBLIC, anon, authenticated;

DO $$
DECLARE f TEXT;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.sandbox_unlock_module(TEXT, JSONB)',
    'public.sandbox_trade(TEXT, TEXT, TEXT, TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC, TEXT)',
    'public.sandbox_close_position(UUID, NUMERIC)',
    'public.sandbox_join_circle(TEXT, INT, NUMERIC, INT, TEXT)',
    'public.sandbox_fast_forward(TEXT, INT, JSONB)',
    'public.sandbox_reset(TEXT, BOOLEAN)',
    'public.sandbox_lesson_read(TEXT, TEXT)',
    'public.sandbox_submit_quiz(TEXT, TEXT, NUMERIC)'
  ] LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f);
  END LOOP;
END $$;
