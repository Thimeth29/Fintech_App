-- ============================================================
-- Investment Trainer RPC tests. Run AFTER the sandbox_trainer migration,
-- in the SQL editor (or psql) as postgres. Everything happens inside one
-- transaction that is rolled back at the end, so no data is left behind.
-- Each check RAISEs if it fails; success prints NOTICEs only.
-- ============================================================
BEGIN;

-- A throwaway user (handle_new_user creates the profile).
INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
VALUES ('00000000-0000-4000-8000-00000000beef', 'sandbox-test@example.com', '{"full_name":"Sandbox Test"}', 'authenticated', 'authenticated');

-- New users get no wallets until a module unlocks.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.sandbox_wallets WHERE user_id = '00000000-0000-4000-8000-00000000beef') THEN
    RAISE EXCEPTION 'FAIL: wallet created at sign-up';
  END IF;
  RAISE NOTICE 'ok: no wallets at sign-up';
END $$;

-- Act as that user.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000beef","role":"authenticated"}', true);

-- Unlock requires a passed quiz.
DO $$ BEGIN
  BEGIN
    PERFORM public.sandbox_unlock_module('cse', '{}'::jsonb);
    RAISE EXCEPTION 'FAIL: unlocked without a lesson';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'lesson_required' THEN RAISE; END IF;
  END;
  PERFORM public.sandbox_lesson_read('cse', 'cse_shares');
  PERFORM public.sandbox_submit_quiz('cse', 'cse_shares', 75);
  PERFORM public.sandbox_unlock_module('cse', '{"JKH.N": 20}'::jsonb);
  RAISE NOTICE 'ok: unlock after quiz';
END $$;

-- Quantity must be > 0 (zero and negative), on buy and sell.
DO $$
DECLARE q NUMERIC; s TEXT;
BEGIN
  FOREACH s IN ARRAY ARRAY['buy', 'sell'] LOOP
    FOREACH q IN ARRAY ARRAY[0, -5]::numeric[] LOOP
      BEGIN
        PERFORM public.sandbox_trade('cse', 'JKH.N', 'John Keells', 'stock', s, q, 20, 0);
        RAISE EXCEPTION 'FAIL: % of % accepted', s, q;
      EXCEPTION WHEN raise_exception THEN
        IF SQLERRM <> 'invalid_quantity' THEN RAISE; END IF;
      END;
    END LOOP;
  END LOOP;
  RAISE NOTICE 'ok: zero/negative quantities rejected';
END $$;

-- Whole shares only on the CSE.
DO $$ BEGIN
  BEGIN
    PERFORM public.sandbox_trade('cse', 'JKH.N', 'John Keells', 'stock', 'buy', 1.5, 20, 0);
    RAISE EXCEPTION 'FAIL: fractional share accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'whole_shares_only' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'ok: whole shares only';
END $$;

-- Insufficient balance, and sequential trades can't overspend.
DO $$
DECLARE r JSONB;
BEGIN
  BEGIN
    PERFORM public.sandbox_trade('cse', 'JKH.N', 'John Keells', 'stock', 'buy', 10000, 20, 0);
    RAISE EXCEPTION 'FAIL: overspend accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'insufficient_balance' THEN RAISE; END IF;
  END;
  r := public.sandbox_trade('cse', 'JKH.N', 'John Keells', 'stock', 'buy', 4000, 20, 896);  -- 80,000 + fee
  IF (r->>'balance')::numeric <> 19104 THEN RAISE EXCEPTION 'FAIL: balance %', r->>'balance'; END IF;
  BEGIN
    PERFORM public.sandbox_trade('cse', 'JKH.N', 'John Keells', 'stock', 'buy', 1000, 20, 224); -- 20,224 > 19,104
    RAISE EXCEPTION 'FAIL: second buy overspent';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'insufficient_balance' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'ok: balance checks';
END $$;

-- Can't sell more than held; a full sell deletes the holding and records P&L.
DO $$
DECLARE r JSONB;
BEGIN
  BEGIN
    PERFORM public.sandbox_trade('cse', 'JKH.N', 'John Keells', 'stock', 'sell', 4001, 20, 0);
    RAISE EXCEPTION 'FAIL: oversell accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'insufficient_holdings' THEN RAISE; END IF;
  END;
  r := public.sandbox_trade('cse', 'JKH.N', 'John Keells', 'stock', 'sell', 4000, 21, 940.80);
  IF r->'holding' <> 'null'::jsonb THEN RAISE EXCEPTION 'FAIL: holding not removed'; END IF;
  -- (21 - 20) * 4000 - 940.80 sell fee - 896 buy fee
  IF (r->>'realised_pnl')::numeric <> 2163.20 THEN RAISE EXCEPTION 'FAIL: pnl %', r->>'realised_pnl'; END IF;
  RAISE NOTICE 'ok: sell + realised P&L';
END $$;

-- Every trade is in history; invalid ones never wrote anything.
DO $$ BEGIN
  IF (SELECT count(*) FROM public.sandbox_trades WHERE user_id = '00000000-0000-4000-8000-00000000beef') <> 2 THEN
    RAISE EXCEPTION 'FAIL: expected 2 trade rows';
  END IF;
  RAISE NOTICE 'ok: trade history';
END $$;

-- Direct writes are denied: no UPDATE/INSERT/DELETE for normal users.
DO $$ BEGIN
  BEGIN
    UPDATE public.sandbox_wallets SET balance = 999999999 WHERE user_id = '00000000-0000-4000-8000-00000000beef';
    RAISE EXCEPTION 'FAIL: direct wallet UPDATE allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.sandbox_holdings (user_id, module, symbol, name, instrument_type, quantity, average_price)
    VALUES ('00000000-0000-4000-8000-00000000beef', 'cse', 'X', 'X', 'stock', 1, 1);
    RAISE EXCEPTION 'FAIL: direct holding INSERT allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE public.sandbox_progress SET xp = 99999 WHERE user_id = '00000000-0000-4000-8000-00000000beef';
    RAISE EXCEPTION 'FAIL: direct progress UPDATE allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RAISE NOTICE 'ok: direct writes denied';
END $$;

-- FD: open, fast-forward with a maturity event, wrong date rejected.
DO $$
DECLARE r JSONB; pid UUID; d DATE;
BEGIN
  PERFORM public.sandbox_lesson_read('fd', 'fd_basics');
  PERFORM public.sandbox_submit_quiz('fd', 'fd_basics', 100);
  PERFORM public.sandbox_unlock_module('fd', '{}'::jsonb);
  r := public.sandbox_open_position('fd', 'fd', 'Test Bank', 50000, 50000, 10, 'maturity', 3);
  pid := (r->'position'->>'id')::uuid;
  d := (r->'position'->>'maturity_sim_date')::date;
  BEGIN
    PERFORM public.sandbox_fast_forward('fd', 120, jsonb_build_array(jsonb_build_object(
      'kind', 'fd_mature', 'position_id', pid, 'amount', 51125, 'sim_date', d - 1)));
    RAISE EXCEPTION 'FAIL: maturity on wrong date accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'invalid_event_date' THEN RAISE; END IF;
  END;
  r := public.sandbox_fast_forward('fd', 120, jsonb_build_array(jsonb_build_object(
    'kind', 'fd_mature', 'position_id', pid, 'amount', 51125, 'sim_date', d)));
  IF (r->>'balance')::numeric <> 101125 THEN RAISE EXCEPTION 'FAIL: fd balance %', r->>'balance'; END IF;
  RAISE NOTICE 'ok: FD open + maturity';
END $$;

-- Reset keeps XP and archives history.
DO $$
DECLARE xp_before INT; r JSONB;
BEGIN
  SELECT xp INTO xp_before FROM public.sandbox_progress WHERE user_id = '00000000-0000-4000-8000-00000000beef';
  r := public.sandbox_reset('cse', FALSE);
  IF (SELECT balance FROM public.sandbox_wallets WHERE user_id = '00000000-0000-4000-8000-00000000beef' AND module = 'cse') <> 100000 THEN
    RAISE EXCEPTION 'FAIL: reset balance';
  END IF;
  IF (SELECT xp FROM public.sandbox_progress WHERE user_id = '00000000-0000-4000-8000-00000000beef') <> xp_before THEN
    RAISE EXCEPTION 'FAIL: reset changed XP';
  END IF;
  IF (SELECT count(*) FROM public.sandbox_trades WHERE user_id = '00000000-0000-4000-8000-00000000beef' AND module = 'cse') <> 2 THEN
    RAISE EXCEPTION 'FAIL: history deleted by reset';
  END IF;
  RAISE NOTICE 'ok: reset';
END $$;

-- Anonymous callers can't run the RPCs at all.
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN
  BEGIN
    PERFORM public.sandbox_trade('cse', 'JKH.N', 'x', 'stock', 'buy', 1, 1, 0);
    RAISE EXCEPTION 'FAIL: anon could call sandbox_trade';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RAISE NOTICE 'ok: anon denied';
END $$;

ROLLBACK;

-- ------------------------------------------------------------
-- Concurrency (manual): open two SQL sessions as the same user with
-- ~Rs 60,000 in the CSE wallet, run BEGIN; SELECT sandbox_trade(... cost
-- 50,000 ...); in both without committing. The second blocks on the
-- wallet's FOR UPDATE lock; after the first COMMITs, the second fails
-- with insufficient_balance. No overspend is possible.
-- ------------------------------------------------------------
