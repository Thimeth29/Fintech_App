-- ============================================================
-- Tests for 20261014090000_sandbox_live_prices.sql: market data access,
-- the forex module, accrued-only early withdrawal of term instruments and
-- the community fund (seettu). Run AFTER the migration, in the SQL editor
-- (or psql) as postgres. Everything is rolled back at the end. Each check
-- RAISEs if it fails; success prints NOTICEs only.
-- ============================================================
BEGIN;

INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
VALUES ('00000000-0000-4000-8000-00000000f00d', 'live-prices-test@example.com', '{"full_name":"Live Test"}',
        'authenticated', 'authenticated');

-- The scraper writes with the service role (bypasses RLS).
SET LOCAL ROLE service_role;
INSERT INTO public.market_prices (symbol, kind, name, price, unit, source, as_of)
VALUES ('USDLKR', 'forex', 'US Dollar', 298.8165, 'LKR', 'CBSL', NOW())
ON CONFLICT (symbol) DO UPDATE SET price = EXCLUDED.price;
INSERT INTO public.market_price_history (symbol, price_date, price, source)
VALUES ('USDLKR', CURRENT_DATE, 298.8165, 'CBSL')
ON CONFLICT (symbol, price_date) DO UPDATE SET price = EXCLUDED.price;
RESET ROLE;

-- Anyone can read prices; nobody but the scraper can write them.
SET LOCAL ROLE anon;
DO $$ BEGIN
  IF (SELECT price FROM public.market_prices WHERE symbol = 'USDLKR') <> 298.8165 THEN
    RAISE EXCEPTION 'FAIL: anon cannot read market_prices';
  END IF;
  BEGIN
    UPDATE public.market_prices SET price = 1 WHERE symbol = 'USDLKR';
    RAISE EXCEPTION 'FAIL: anon could update market_prices';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RAISE NOTICE 'ok: market_prices readable by anon, not writable';
END $$;
RESET ROLE;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000f00d","role":"authenticated"}', true);

DO $$ BEGIN
  BEGIN
    INSERT INTO public.market_prices (symbol, kind, name, price, unit, source, as_of)
    VALUES ('FAKE', 'stock', 'Fake', 1, 'LKR', 'me', NOW());
    RAISE EXCEPTION 'FAIL: user could insert a market price';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    DELETE FROM public.market_price_history WHERE symbol = 'USDLKR';
    RAISE EXCEPTION 'FAIL: user could delete price history';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  IF NOT EXISTS (SELECT 1 FROM public.market_price_history WHERE symbol = 'USDLKR') THEN
    RAISE EXCEPTION 'FAIL: user cannot read price history';
  END IF;
  RAISE NOTICE 'ok: users read but cannot write market data';
END $$;

-- Forex: unlock after the first quiz, buy fractional units, sell with P&L.
DO $$
DECLARE r JSONB;
BEGIN
  BEGIN
    PERFORM public.sandbox_unlock_module('forex', '{}'::jsonb);
    RAISE EXCEPTION 'FAIL: forex unlocked without a lesson';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'lesson_required' THEN RAISE; END IF;
  END;
  PERFORM public.sandbox_lesson_read('forex', 'fx_basics');
  PERFORM public.sandbox_submit_quiz('forex', 'fx_basics', 100);
  PERFORM public.sandbox_unlock_module('forex', '{"USDLKR": 298.8165}'::jsonb);
  r := public.sandbox_trade('forex', 'USDLKR', 'US Dollar', 'forex', 'buy', 100.5, 300, 0);
  IF (r->>'balance')::numeric <> 69850 THEN RAISE EXCEPTION 'FAIL: forex buy balance %', r->>'balance'; END IF;
  IF (r->'holding'->>'module') <> 'forex' THEN RAISE EXCEPTION 'FAIL: forex holding module'; END IF;
  r := public.sandbox_trade('forex', 'USDLKR', 'US Dollar', 'forex', 'sell', 100.5, 302, 0);
  IF (r->>'realised_pnl')::numeric <> 201 THEN RAISE EXCEPTION 'FAIL: forex pnl %', r->>'realised_pnl'; END IF;
  BEGIN
    PERFORM public.sandbox_trade('forex', 'USDLKR', 'US Dollar', 'forex', 'short', 10, 300, 0);
    RAISE EXCEPTION 'FAIL: forex short accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM NOT IN ('short_not_allowed', 'short_locked') THEN RAISE; END IF;
  END;
  RAISE NOTICE 'ok: forex buy/sell';
END $$;

-- Term instruments: withdrawing early pays principal + interest accrued so
-- far at the locked rate (after 10% tax). The client's amount is ignored.
DO $$
DECLARE r JSONB; fd UUID; bill UUID; bond UUID;
BEGIN
  PERFORM public.sandbox_lesson_read('fd', 'fd_basics');
  PERFORM public.sandbox_submit_quiz('fd', 'fd_basics', 100);
  PERFORM public.sandbox_unlock_module('fd', '{}'::jsonb);
  r := public.sandbox_open_position('fd', 'fd', 'Test Bank', 50000, 50000, 10, 'maturity', 12);
  fd := (r->'position'->>'id')::uuid;
  PERFORM public.sandbox_fast_forward('fd', 73, '[]'::jsonb);
  r := public.sandbox_close_position(fd, 999999);
  -- 50,000 x 10% x 73/365 = 1,000 interest, 900 after tax.
  IF (r->>'amount')::numeric <> 50900 THEN RAISE EXCEPTION 'FAIL: FD early amount %', r->>'amount'; END IF;
  IF (r->>'balance')::numeric <> 100900 THEN RAISE EXCEPTION 'FAIL: FD balance %', r->>'balance'; END IF;
  IF (r->>'realised_pnl')::numeric <> 900 THEN RAISE EXCEPTION 'FAIL: FD pnl %', r->>'realised_pnl'; END IF;
  BEGIN
    PERFORM public.sandbox_close_position(fd, 0);
    RAISE EXCEPTION 'FAIL: closed twice';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'position_not_open' THEN RAISE; END IF;
  END;

  PERFORM public.sandbox_lesson_read('gov_securities', 'gov_basics');
  PERFORM public.sandbox_submit_quiz('gov_securities', 'gov_basics', 100);
  PERFORM public.sandbox_unlock_module('gov_securities', '{}'::jsonb);
  r := public.sandbox_open_position('gov_securities', 'tbill', '364-day T-Bill', 50000, 46000, 8.65, 'discount', NULL, 364);
  bill := (r->'position'->>'id')::uuid;
  r := public.sandbox_open_position('gov_securities', 'tbond', '5-year T-Bond', 50000, 50000, 10, 'semi_annual', 60, NULL, 10);
  bond := (r->'position'->>'id')::uuid;
  PERFORM public.sandbox_fast_forward('gov_securities', 100, '[]'::jsonb);
  r := public.sandbox_close_position(bill, 0);
  -- 46,000 + 4,000 discount x 90% x 100/364 = 46,000 + 989.01
  IF (r->>'amount')::numeric <> 46989.01 THEN RAISE EXCEPTION 'FAIL: T-bill early amount %', r->>'amount'; END IF;
  r := public.sandbox_close_position(bond, 0);
  -- 50,000 x 10% x 100/365 x 90% = 1,232.88
  IF (r->>'amount')::numeric <> 51232.88 THEN RAISE EXCEPTION 'FAIL: T-bond early amount %', r->>'amount'; END IF;
  IF (SELECT count(*) FROM public.sandbox_trades
      WHERE user_id = '00000000-0000-4000-8000-00000000f00d' AND side IN ('fd_break', 'tbill_break', 'tbond_sell')) <> 3 THEN
    RAISE EXCEPTION 'FAIL: early withdrawals not all in history';
  END IF;
  RAISE NOTICE 'ok: accrued-only early withdrawal (FD, T-bill, T-bond)';
END $$;

-- Community fund: join, commitments, rounds, pot and completion.
DO $$
DECLARE r JSONB; c1 UUID; c2 UUID; s DATE; v_bal NUMERIC;
BEGIN
  PERFORM public.sandbox_lesson_read('community_fund', 'cf_seettu');
  PERFORM public.sandbox_submit_quiz('community_fund', 'cf_seettu', 100);
  PERFORM public.sandbox_unlock_module('community_fund', '{}'::jsonb);

  -- 5 members x Rs 10,000, my turn is 3. Round 1 is paid on joining.
  r := public.sandbox_join_circle('Office seettu', 5, 10000, 3, 'known');
  c1 := (r->'circle'->>'id')::uuid;
  s := (r->'circle'->>'start_sim_date')::date;
  IF (r->>'balance')::numeric <> 90000 THEN RAISE EXCEPTION 'FAIL: join balance %', r->>'balance'; END IF;

  -- Still owe 4 x 10,000 = 40,000; another 10 x 6,000 = 60,000 can't be covered by 90,000.
  BEGIN
    PERFORM public.sandbox_join_circle('Too big', 10, 6000, 5, 'strangers');
    RAISE EXCEPTION 'FAIL: unaffordable circle accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'seettu_unaffordable' THEN RAISE; END IF;
  END;

  -- Turn 1 takes the full pot on joining: -5,000 + 25,000.
  r := public.sandbox_join_circle('Neighbours', 5, 5000, 1, 'known');
  c2 := (r->'circle'->>'id')::uuid;
  IF (r->>'balance')::numeric <> 110000 THEN RAISE EXCEPTION 'FAIL: turn-1 pot balance %', r->>'balance'; END IF;
  IF (r->'circle'->>'pot_received')::numeric <> 25000 THEN RAISE EXCEPTION 'FAIL: turn-1 pot'; END IF;

  -- Wrong date and wrong amount are rejected.
  BEGIN
    PERFORM public.sandbox_fast_forward('community_fund', 40, jsonb_build_array(jsonb_build_object(
      'kind', 'seettu_pay', 'circle_id', c1, 'amount', 10000, 'sim_date', s + 5)));
    RAISE EXCEPTION 'FAIL: payment on the wrong date accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'invalid_event_date' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.sandbox_fast_forward('community_fund', 40, jsonb_build_array(jsonb_build_object(
      'kind', 'seettu_pay', 'circle_id', c1, 'amount', 1, 'sim_date', (s + interval '1 month')::date)));
    RAISE EXCEPTION 'FAIL: wrong contribution accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'invalid_event' THEN RAISE; END IF;
  END;
  -- A pot before the user's turn is rejected.
  BEGIN
    PERFORM public.sandbox_fast_forward('community_fund', 40, jsonb_build_array(jsonb_build_object(
      'kind', 'seettu_pot', 'circle_id', c1, 'amount', 50000, 'sim_date', (s + interval '1 month')::date)));
    RAISE EXCEPTION 'FAIL: early pot accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'invalid_event' THEN RAISE; END IF;
  END;

  -- Round 2 (both circles pay), then round 3 where the user's pot arrives.
  r := public.sandbox_fast_forward('community_fund', ((s + interval '2 months')::date - s), jsonb_build_array(
    jsonb_build_object('kind', 'seettu_pay', 'circle_id', c1, 'amount', 10000, 'sim_date', (s + interval '1 month')::date),
    jsonb_build_object('kind', 'seettu_pay', 'circle_id', c2, 'amount', 5000, 'sim_date', (s + interval '1 month')::date),
    jsonb_build_object('kind', 'seettu_pay', 'circle_id', c1, 'amount', 10000, 'sim_date', (s + interval '2 months')::date),
    jsonb_build_object('kind', 'seettu_pay', 'circle_id', c2, 'amount', 5000, 'sim_date', (s + interval '2 months')::date),
    jsonb_build_object('kind', 'seettu_pot', 'circle_id', c1, 'amount', 40000, 'sim_date', (s + interval '2 months')::date)));
  -- 110,000 - 30,000 paid + 40,000 pot (one member stopped paying).
  IF (r->>'balance')::numeric <> 120000 THEN RAISE EXCEPTION 'FAIL: after round 3 balance %', r->>'balance'; END IF;

  -- A second pot is rejected.
  BEGIN
    PERFORM public.sandbox_fast_forward('community_fund', 40, jsonb_build_array(jsonb_build_object(
      'kind', 'seettu_pot', 'circle_id', c1, 'amount', 10000, 'sim_date', (s + interval '3 months')::date)));
    RAISE EXCEPTION 'FAIL: second pot accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'invalid_event' THEN RAISE; END IF;
  END;

  -- Rounds 4 and 5 complete both circles.
  SELECT start_sim_date INTO s FROM public.sandbox_circles WHERE id = c1;
  r := public.sandbox_fast_forward('community_fund', ((s + interval '4 months')::date - (s + interval '2 months')::date),
    jsonb_build_array(
      jsonb_build_object('kind', 'seettu_pay', 'circle_id', c1, 'amount', 10000, 'sim_date', (s + interval '3 months')::date),
      jsonb_build_object('kind', 'seettu_pay', 'circle_id', c2, 'amount', 5000, 'sim_date', (s + interval '3 months')::date),
      jsonb_build_object('kind', 'seettu_pay', 'circle_id', c1, 'amount', 10000, 'sim_date', (s + interval '4 months')::date),
      jsonb_build_object('kind', 'seettu_pay', 'circle_id', c2, 'amount', 5000, 'sim_date', (s + interval '4 months')::date)));
  -- Paid 5 x 10,000 + 5 x 5,000, received 40,000 + 25,000: 100,000 - 75,000 + 65,000 = 90,000.
  v_bal := (r->>'balance')::numeric;
  IF v_bal <> 90000 THEN RAISE EXCEPTION 'FAIL: final balance %', v_bal; END IF;
  IF (SELECT count(*) FROM public.sandbox_circles WHERE user_id = '00000000-0000-4000-8000-00000000f00d'
      AND status = 'completed') <> 2 THEN
    RAISE EXCEPTION 'FAIL: circles not completed';
  END IF;
  RAISE NOTICE 'ok: seettu join, rounds, pot, defaults and completion';
END $$;

-- Circles can't be written directly; reset archives open ones.
DO $$
DECLARE r JSONB;
BEGIN
  BEGIN
    UPDATE public.sandbox_circles SET pot_received = 1e6 WHERE user_id = '00000000-0000-4000-8000-00000000f00d';
    RAISE EXCEPTION 'FAIL: direct circle UPDATE allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  r := public.sandbox_join_circle('After', 3, 1000, 2, 'strangers');
  PERFORM public.sandbox_reset('community_fund', FALSE);
  IF EXISTS (SELECT 1 FROM public.sandbox_circles WHERE user_id = '00000000-0000-4000-8000-00000000f00d' AND status = 'open') THEN
    RAISE EXCEPTION 'FAIL: reset left an open circle';
  END IF;
  RAISE NOTICE 'ok: circles locked down and archived on reset';
END $$;

RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN
  BEGIN
    PERFORM public.sandbox_join_circle('x', 5, 100, 1, 'known');
    RAISE EXCEPTION 'FAIL: anon could join a circle';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RAISE NOTICE 'ok: anon denied';
END $$;

ROLLBACK;
