-- ============================================================
-- Community & group RLS / RPC tests. Run AFTER the community_groups
-- migration, in the SQL editor (or psql) as postgres. Everything happens
-- inside one transaction that is rolled back at the end, so no data is
-- left behind. Each check RAISEs if it fails; success prints NOTICEs.
-- ============================================================
BEGIN;
CREATE SCHEMA cgtest;
GRANT ALL ON SCHEMA cgtest TO authenticated;

-- Helpers ------------------------------------------------------
CREATE FUNCTION cgtest.as_user(p UUID) RETURNS VOID LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::TEXT, TRUE);
$$;

CREATE FUNCTION cgtest.expect_error(p_sql TEXT, p_code TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE p_sql;
  EXCEPTION WHEN others THEN
    IF SQLERRM = p_code OR SQLSTATE = p_code THEN RETURN; END IF;
    RAISE EXCEPTION 'FAIL: expected % from [%], got % (%)', p_code, p_sql, SQLERRM, SQLSTATE;
  END;
  RAISE EXCEPTION 'FAIL: expected % but [%] succeeded', p_code, p_sql;
END;
$$;

-- Users: A leader, B and C members, D outsider, E hidden.
INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role) VALUES
  ('00000000-0000-4000-8000-0000000c0001', 'cg-a@example.com', '{"full_name":"Amal A"}', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000c0002', 'cg-b@example.com', '{"full_name":"Bimal B"}', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000c0003', 'cg-c@example.com', '{"full_name":"Chamari C"}', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000c0004', 'cg-d@example.com', '{"full_name":"Dilan D"}', 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000c0005', 'cg-e@example.com', '{"full_name":"Eshani E"}', 'authenticated', 'authenticated');
-- E is 17.
UPDATE public.profiles SET date_of_birth = CURRENT_DATE - INTERVAL '17 years'
WHERE id = '00000000-0000-4000-8000-0000000c0005';

-- Pure functions (no role needed) ------------------------------
DO $$
DECLARE a NUMERIC[];
BEGIN
  a := public.cg_split_amount(100, ARRAY[1, 1, 1]::NUMERIC[]);
  IF a <> ARRAY[33.34, 33.33, 33.33]::NUMERIC[] THEN RAISE EXCEPTION 'FAIL: equal split %', a; END IF;
  a := public.cg_split_amount(1000, ARRAY[50000, 30000, 20000]::NUMERIC[]);
  IF a <> ARRAY[500, 300, 200]::NUMERIC[] THEN RAISE EXCEPTION 'FAIL: pro-rata split %', a; END IF;
  a := public.cg_split_amount(100, ARRAY[1, 1, 1, 1, 1, 1, 1]::NUMERIC[]);
  IF (SELECT SUM(x) FROM unnest(a) x) <> 100 THEN RAISE EXCEPTION 'FAIL: split does not add up %', a; END IF;
  a := public.cg_split_amount(10, ARRAY[0, 0]::NUMERIC[]);
  IF a <> ARRAY[5, 5]::NUMERIC[] THEN RAISE EXCEPTION 'FAIL: zero weights %', a; END IF;

  -- 2026-10-13 is a Tuesday.
  IF public.cg_seettu_due_date('2026-10-13', 'weekly', 5, 1) <> '2026-10-16' THEN RAISE EXCEPTION 'FAIL: weekly round 1'; END IF;
  IF public.cg_seettu_due_date('2026-10-13', 'weekly', 2, 3) <> '2026-10-27' THEN RAISE EXCEPTION 'FAIL: weekly same day'; END IF;
  IF public.cg_seettu_due_date('2026-10-13', 'monthly', 5, 1) <> '2026-11-05' THEN RAISE EXCEPTION 'FAIL: monthly round 1'; END IF;
  IF public.cg_seettu_due_date('2026-10-13', 'monthly', 28, 5) <> '2027-02-28' THEN RAISE EXCEPTION 'FAIL: monthly round 5'; END IF;

  -- majority of cast votes; ties fail; quorum by headcount
  IF NOT public.cg_vote_passes(3, 2, 5, 8, 8, 50, 'majority', 'cast') THEN RAISE EXCEPTION 'FAIL: simple majority'; END IF;
  IF public.cg_vote_passes(2, 2, 4, 8, 8, 50, 'majority', 'cast') THEN RAISE EXCEPTION 'FAIL: tie passed'; END IF;
  IF public.cg_vote_passes(3, 0, 3, 8, 8, 50, 'majority', 'cast') THEN RAISE EXCEPTION 'FAIL: below quorum passed'; END IF;
  IF NOT public.cg_vote_passes(2, 1, 3, 3, 3, 50, 'two_thirds', 'cast') THEN RAISE EXCEPTION 'FAIL: exactly two thirds'; END IF;
  IF public.cg_vote_passes(3, 2, 5, 5, 5, 50, 'two_thirds', 'cast') THEN RAISE EXCEPTION 'FAIL: 60 percent passed two thirds'; END IF;
  -- leader change: 2/3 of ALL members
  IF public.cg_vote_passes(4, 0, 4, 9, 9, 50, 'two_thirds', 'eligible') THEN RAISE EXCEPTION 'FAIL: 4 of 9 changed leader'; END IF;
  IF NOT public.cg_vote_passes(6, 1, 7, 9, 9, 50, 'two_thirds', 'eligible') THEN RAISE EXCEPTION 'FAIL: 6 of 9 failed'; END IF;
  -- weighted: one big contributor outweighs two small ones
  IF NOT public.cg_vote_passes(60000, 20000, 3, 3, 80000, 50, 'majority', 'cast') THEN RAISE EXCEPTION 'FAIL: weighted'; END IF;

  IF public.cg_exit_payout('contribution_back', 50000, 0.5, 120000, 10, FALSE) <> 50000 THEN RAISE EXCEPTION 'FAIL: exit contribution'; END IF;
  IF public.cg_exit_payout('share_of_value', 50000, 0.5, 120000, 10, FALSE) <> 60000 THEN RAISE EXCEPTION 'FAIL: exit share'; END IF;
  IF public.cg_exit_payout('share_of_value', 50000, 0.5, 120000, 10, TRUE) <> 54000 THEN RAISE EXCEPTION 'FAIL: exit penalty'; END IF;

  IF NOT public.cg_has_payment_details('pay to 1234 5678 9012 3456') THEN RAISE EXCEPTION 'FAIL: card number allowed'; END IF;
  IF NOT public.cg_has_payment_details('my account no 8001234567') THEN RAISE EXCEPTION 'FAIL: account number allowed'; END IF;
  IF public.cg_has_payment_details('call me on 0771234567') THEN RAISE EXCEPTION 'FAIL: phone blocked'; END IF;
  IF public.cg_has_payment_details('round 3 is Rs 25,000 on 2026-11-05') THEN RAISE EXCEPTION 'FAIL: amount blocked'; END IF;
  RAISE NOTICE 'ok: pure functions';
END $$;

SET LOCAL ROLE authenticated;

-- Profiles -----------------------------------------------------
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0001');
SELECT public.community_save_profile('Amal A', '0771111111', FALSE, NULL, 75000, 'experienced', ARRAY['seettu', 'cse'], 'Colombo', 'Long-term saver');
SELECT public.community_confirm_age();
SELECT public.community_set_available(TRUE);

SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0002');
SELECT public.community_save_profile('Bimal B', '0772222222', TRUE, NULL, 20000, 'some', ARRAY['seettu'], 'Kandy', NULL);
SELECT public.community_confirm_age();
SELECT public.community_set_available(TRUE);

SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0003');
SELECT public.community_save_profile('Chamari C', '0773333333', FALSE, NULL, 5000, 'none', ARRAY['fd'], NULL, NULL);
SELECT public.community_confirm_age();
SELECT public.community_set_available(TRUE);

SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0004');
SELECT public.community_save_profile('Dilan D', '0774444444', FALSE, NULL, 10000, 'none', '{}', NULL, NULL);
SELECT public.community_confirm_age();
SELECT public.community_set_available(TRUE);

-- E: under 18 can save a profile but not become available.
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0005');
SELECT public.community_save_profile('Eshani E', '0775555555', TRUE, NULL, 10000, 'none', '{}', NULL, NULL);
SELECT cgtest.expect_error('SELECT public.community_confirm_age()', 'under_18');
SELECT cgtest.expect_error('SELECT public.community_set_available(TRUE)', 'under_18');
DO $$ BEGIN RAISE NOTICE 'ok: under-18 cannot opt in'; END $$;

-- Search as D --------------------------------------------------
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0004');
DO $$
DECLARE r RECORD;
BEGIN
  IF EXISTS (SELECT 1 FROM public.community_search_people() WHERE user_id = '00000000-0000-4000-8000-0000000c0005') THEN
    RAISE EXCEPTION 'FAIL: hidden user in search';
  END IF;
  IF EXISTS (SELECT 1 FROM public.community_profiles WHERE user_id = '00000000-0000-4000-8000-0000000c0005') THEN
    RAISE EXCEPTION 'FAIL: hidden profile readable';
  END IF;
  SELECT * INTO r FROM public.community_search_people() WHERE user_id = '00000000-0000-4000-8000-0000000c0001';
  IF r.user_id IS NULL THEN RAISE EXCEPTION 'FAIL: available user missing'; END IF;
  IF r.phone IS NOT NULL THEN RAISE EXCEPTION 'FAIL: phone shown without permission'; END IF;
  IF r.contribution_label <> 'Rs 50k–100k' THEN RAISE EXCEPTION 'FAIL: bucket %', r.contribution_label; END IF;
  SELECT * INTO r FROM public.community_search_people() WHERE user_id = '00000000-0000-4000-8000-0000000c0002';
  IF r.phone IS DISTINCT FROM '0772222222' THEN RAISE EXCEPTION 'FAIL: opted-in phone hidden'; END IF;
  IF (SELECT COUNT(*) FROM public.community_search_people(p_query => 'chama')) <> 1 THEN RAISE EXCEPTION 'FAIL: name search'; END IF;
  IF EXISTS (SELECT 1 FROM public.community_search_people(p_min_bucket => 2) WHERE user_id = '00000000-0000-4000-8000-0000000c0002') THEN
    RAISE EXCEPTION 'FAIL: bucket filter';
  END IF;
  RAISE NOTICE 'ok: search visibility, phone rule, filters';
END $$;
SELECT cgtest.expect_error('SELECT phone FROM public.community_profiles', '42501');
SELECT cgtest.expect_error('SELECT max_contribution FROM public.community_profiles', '42501');
SELECT cgtest.expect_error($q$UPDATE public.community_profiles SET phone_verified = TRUE$q$, '42501');
DO $$ BEGIN RAISE NOTICE 'ok: phone and exact contribution not selectable; phone_verified not writable'; END $$;

-- Connections and blocks ----------------------------------------
SELECT public.connection_request('00000000-0000-4000-8000-0000000c0003', 'Hi!');
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0003');
SELECT public.connection_respond((SELECT id FROM public.connections WHERE requester_id = '00000000-0000-4000-8000-0000000c0004'), FALSE);
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0004');
SELECT cgtest.expect_error($q$SELECT public.connection_request('00000000-0000-4000-8000-0000000c0003')$q$, 'declined_recently');
DO $$ BEGIN RAISE NOTICE 'ok: 7-day cooldown after decline'; END $$;

-- D blocks A: they disappear for each other.
SELECT public.community_block('00000000-0000-4000-8000-0000000c0001');
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.community_search_people() WHERE user_id = '00000000-0000-4000-8000-0000000c0001') THEN
    RAISE EXCEPTION 'FAIL: blocked user visible to blocker';
  END IF;
END $$;
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0001');
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.community_search_people() WHERE user_id = '00000000-0000-4000-8000-0000000c0004') THEN
    RAISE EXCEPTION 'FAIL: blocker visible to blocked user';
  END IF;
  IF public.community_get_profile('00000000-0000-4000-8000-0000000c0004') IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL: blocked profile readable';
  END IF;
  RAISE NOTICE 'ok: blocks hide both ways';
END $$;
SELECT cgtest.expect_error($q$SELECT public.connection_request('00000000-0000-4000-8000-0000000c0004')$q$, 'user_unavailable');

-- Investment group ----------------------------------------------
SELECT public.group_create('investment', 'CG Test Fund', 'Testing', NULL, 5, TRUE, 'leader', 'Be honest.',
  'weighted', 'Colombo', NULL,
  '{"min_contribution": 1000, "max_contribution": 100000, "allowed_types": ["fd", "cse"], "decision_threshold": 5000}'::jsonb);
CREATE TABLE cgtest.t_ids AS SELECT id AS fund FROM public.groups WHERE name = 'CG Test Fund';
GRANT SELECT ON cgtest.t_ids TO authenticated;

SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0002');
SELECT cgtest.expect_error($q$SELECT public.group_request_join((SELECT fund FROM cgtest.t_ids), 'hi', FALSE)$q$, 'rules_not_accepted');
SELECT public.group_request_join((SELECT fund FROM cgtest.t_ids), 'Keen to join', TRUE);
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0003');
SELECT public.group_request_join((SELECT fund FROM cgtest.t_ids), NULL, TRUE);
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0001');
SELECT public.group_decide_join(r.id, TRUE) FROM public.group_join_requests r WHERE r.group_id = (SELECT fund FROM cgtest.t_ids);
DO $$ BEGIN
  IF (SELECT COUNT(*) FROM public.group_members WHERE group_id = (SELECT fund FROM cgtest.t_ids) AND status = 'active') <> 3 THEN
    RAISE EXCEPTION 'FAIL: join approvals';
  END IF;
  RAISE NOTICE 'ok: join requests approved';
END $$;
SELECT cgtest.expect_error($q$SELECT public._cg_active_count((SELECT fund FROM cgtest.t_ids))$q$, '42501');
DO $$ BEGIN RAISE NOTICE 'ok: internal helpers not callable by clients'; END $$;
SELECT public.group_send_message((SELECT fund FROM cgtest.t_ids), 'Welcome everyone');
SELECT cgtest.expect_error($q$SELECT public.group_send_message((SELECT fund FROM cgtest.t_ids), 'send to card 4111 1111 1111 1111')$q$, 'payment_details_blocked');

-- Non-member D can't read anything inside the group.
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0004');
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.group_messages WHERE group_id = (SELECT fund FROM cgtest.t_ids)) THEN RAISE EXCEPTION 'FAIL: non-member reads chat'; END IF;
  IF EXISTS (SELECT 1 FROM public.groups WHERE id = (SELECT fund FROM cgtest.t_ids)) THEN RAISE EXCEPTION 'FAIL: non-member reads group row'; END IF;
  IF EXISTS (SELECT 1 FROM public.group_members WHERE group_id = (SELECT fund FROM cgtest.t_ids)) THEN RAISE EXCEPTION 'FAIL: non-member reads members'; END IF;
  IF EXISTS (SELECT 1 FROM public.group_activity_log WHERE group_id = (SELECT fund FROM cgtest.t_ids)) THEN RAISE EXCEPTION 'FAIL: non-member reads log'; END IF;
  RAISE NOTICE 'ok: non-member cannot read group content';
END $$;
SELECT cgtest.expect_error($q$SELECT public.group_send_message((SELECT fund FROM cgtest.t_ids), 'hi')$q$, 'not_group_member');
SELECT cgtest.expect_error($q$INSERT INTO public.group_messages (group_id, body) VALUES ((SELECT fund FROM cgtest.t_ids), 'x')$q$, '42501');

-- Contributions: can't confirm your own.
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0002');
SELECT public.invest_pledge((SELECT fund FROM cgtest.t_ids), 60000);
SELECT public.invest_mark_paid(id) FROM public.group_contributions WHERE user_id = '00000000-0000-4000-8000-0000000c0002';
SELECT cgtest.expect_error($q$SELECT public.invest_confirm_contribution(id) FROM public.group_contributions WHERE user_id = '00000000-0000-4000-8000-0000000c0002'$q$, 'not_group_officer');
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0001');
SELECT public.invest_pledge((SELECT fund FROM cgtest.t_ids), 20000);
SELECT cgtest.expect_error($q$SELECT public.invest_confirm_contribution(id) FROM public.group_contributions WHERE user_id = '00000000-0000-4000-8000-0000000c0001'$q$, 'cannot_confirm_own_payment');
SELECT public.invest_confirm_contribution(id) FROM public.group_contributions WHERE user_id = '00000000-0000-4000-8000-0000000c0002';
SELECT public.group_set_role((SELECT fund FROM cgtest.t_ids), '00000000-0000-4000-8000-0000000c0003', 'treasurer');
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0003');
SELECT public.invest_confirm_contribution(id) FROM public.group_contributions WHERE user_id = '00000000-0000-4000-8000-0000000c0001';
DO $$ BEGIN RAISE NOTICE 'ok: contributions confirmed by someone else only'; END $$;

-- Formal vote: one ballot per member, changeable; no direct inserts.
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0001');
SELECT public.group_start_vote((SELECT fund FROM cgtest.t_ids), 'custom', 'Meet on Saturday?');
CREATE TABLE cgtest.t_vote AS SELECT id FROM public.group_votes WHERE title = 'Meet on Saturday?';
GRANT SELECT ON cgtest.t_vote TO authenticated;
SELECT public.vote_cast((SELECT id FROM cgtest.t_vote), 'yes');
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0002');
SELECT public.vote_cast((SELECT id FROM cgtest.t_vote), 'no');
SELECT public.vote_cast((SELECT id FROM cgtest.t_vote), 'yes');
DO $$ BEGIN
  IF (SELECT COUNT(*) FROM public.group_vote_ballots WHERE vote_id = (SELECT id FROM cgtest.t_vote) AND user_id = '00000000-0000-4000-8000-0000000c0002') <> 1 THEN
    RAISE EXCEPTION 'FAIL: two ballots';
  END IF;
  IF (SELECT choice FROM public.group_vote_ballots WHERE vote_id = (SELECT id FROM cgtest.t_vote) AND user_id = '00000000-0000-4000-8000-0000000c0002') <> 'yes' THEN
    RAISE EXCEPTION 'FAIL: ballot not changed';
  END IF;
  RAISE NOTICE 'ok: one ballot per member, changeable';
END $$;
SELECT cgtest.expect_error($q$INSERT INTO public.group_vote_ballots (vote_id, group_id, user_id, choice) VALUES ((SELECT id FROM cgtest.t_vote), (SELECT fund FROM cgtest.t_ids), '00000000-0000-4000-8000-0000000c0002', 'no')$q$, '42501');
SELECT cgtest.expect_error($q$SELECT public.vote_close((SELECT id FROM cgtest.t_vote))$q$, 'vote_still_open');

-- Activity log is append-only.
SELECT cgtest.expect_error($q$UPDATE public.group_activity_log SET event = 'x'$q$, '42501');

RESET ROLE;
DO $$ BEGIN
  BEGIN
    UPDATE public.group_activity_log SET event = 'tampered' WHERE group_id = (SELECT fund FROM cgtest.t_ids);
    RAISE EXCEPTION 'FAIL: postgres edited the log';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'activity_log_is_append_only' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'ok: activity log append-only (even for postgres)';
END $$;

-- Close the vote after its deadline: weighted by confirmed contributions
-- (B 60k yes, A 20k yes, C 0) -> passes.
UPDATE public.group_votes SET deadline = NOW() - INTERVAL '1 minute' WHERE id = (SELECT id FROM cgtest.t_vote);
SELECT public._cg_close_vote((SELECT id FROM cgtest.t_vote));
DO $$
DECLARE v public.group_votes;
BEGIN
  SELECT * INTO v FROM public.group_votes WHERE id = (SELECT id FROM cgtest.t_vote);
  IF v.status <> 'passed' OR v.yes_weight <> 80000 OR v.eligible_weight <> 80000 THEN
    RAISE EXCEPTION 'FAIL: weighted close % yes % eligible %', v.status, v.yes_weight, v.eligible_weight;
  END IF;
  RAISE NOTICE 'ok: weighted vote tally';
END $$;

-- Distribution adds up exactly.
SET LOCAL ROLE authenticated;
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0001');
SELECT public.invest_create_distribution((SELECT fund FROM cgtest.t_ids), 1000.01);
DO $$ BEGIN
  IF (SELECT SUM(amount) FROM public.group_distribution_shares WHERE group_id = (SELECT fund FROM cgtest.t_ids)) <> 1000.01 THEN
    RAISE EXCEPTION 'FAIL: distribution does not add up';
  END IF;
  IF (SELECT amount FROM public.group_distribution_shares WHERE group_id = (SELECT fund FROM cgtest.t_ids)
      AND user_id = '00000000-0000-4000-8000-0000000c0002') <> 750.01 THEN
    RAISE EXCEPTION 'FAIL: pro-rata share';
  END IF;
  RAISE NOTICE 'ok: distribution';
END $$;

-- Seettu ---------------------------------------------------------
SELECT public.group_create('seettu', 'CG Test Seettu', NULL, NULL, 2, TRUE, 'leader', '', 'one_member_one_vote', NULL,
  json_build_object('contribution', 5000, 'frequency', 'monthly', 'start_date', CURRENT_DATE, 'due_day', 28,
                    'payout_method', 'agreed')::jsonb, NULL);
INSERT INTO cgtest.t_ids SELECT id FROM public.groups WHERE name = 'CG Test Seettu';
CREATE TABLE cgtest.t_seettu AS SELECT id FROM public.groups WHERE name = 'CG Test Seettu';
GRANT SELECT ON cgtest.t_seettu TO authenticated;
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0002');
SELECT public.group_request_join((SELECT id FROM cgtest.t_seettu), NULL, TRUE);
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0001');
SELECT public.group_decide_join(r.id, TRUE) FROM public.group_join_requests r WHERE r.group_id = (SELECT id FROM cgtest.t_seettu);
SELECT public.seettu_set_order((SELECT id FROM cgtest.t_seettu),
  ARRAY['00000000-0000-4000-8000-0000000c0002', '00000000-0000-4000-8000-0000000c0001']::UUID[]);
SELECT cgtest.expect_error($q$SELECT public.seettu_start((SELECT id FROM cgtest.t_seettu))$q$, 'not_all_confirmed');
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0002');
SELECT public.seettu_confirm((SELECT id FROM cgtest.t_seettu));
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0001');
SELECT public.seettu_start((SELECT id FROM cgtest.t_seettu));

-- Round 1 goes to B. B pays and can't confirm their own payment.
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0002');
SELECT public.seettu_mark_paid(p.id) FROM public.seettu_payments p JOIN public.seettu_rounds r ON r.id = p.round_id
WHERE r.group_id = (SELECT id FROM cgtest.t_seettu) AND r.round_no = 1 AND p.payer_id = '00000000-0000-4000-8000-0000000c0002';
SELECT cgtest.expect_error($q$SELECT public.seettu_confirm_payment(p.id) FROM public.seettu_payments p JOIN public.seettu_rounds r ON r.id = p.round_id
  WHERE r.group_id = (SELECT id FROM cgtest.t_seettu) AND r.round_no = 1 AND p.payer_id = '00000000-0000-4000-8000-0000000c0002'$q$,
  'cannot_confirm_own_payment');
-- The recipient (B) confirms A's payment; the leader (A) confirms B's.
SELECT public.seettu_confirm_payment(p.id) FROM public.seettu_payments p JOIN public.seettu_rounds r ON r.id = p.round_id
WHERE r.group_id = (SELECT id FROM cgtest.t_seettu) AND r.round_no = 1 AND p.payer_id = '00000000-0000-4000-8000-0000000c0001';
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0001');
SELECT public.seettu_confirm_payment(p.id) FROM public.seettu_payments p JOIN public.seettu_rounds r ON r.id = p.round_id
WHERE r.group_id = (SELECT id FROM cgtest.t_seettu) AND r.round_no = 1 AND p.payer_id = '00000000-0000-4000-8000-0000000c0002';
SELECT public.seettu_hand_over(id) FROM public.seettu_rounds WHERE group_id = (SELECT id FROM cgtest.t_seettu) AND round_no = 1;
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0002');
SELECT public.seettu_confirm_received(id) FROM public.seettu_rounds WHERE group_id = (SELECT id FROM cgtest.t_seettu) AND round_no = 1;
DO $$ BEGIN
  IF (SELECT pot FROM public.seettu_rounds WHERE group_id = (SELECT id FROM cgtest.t_seettu) AND round_no = 1) <> 10000 THEN
    RAISE EXCEPTION 'FAIL: pot';
  END IF;
  RAISE NOTICE 'ok: seettu round flow';
END $$;
SELECT cgtest.expect_error($q$SELECT public.group_leave((SELECT id FROM cgtest.t_seettu))$q$, 'must_complete_payments');
DO $$ BEGIN RAISE NOTICE 'ok: pot receiver cannot leave before paying'; END $$;

-- Anonymous poll: others can't see who voted.
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0001');
SELECT public.poll_create((SELECT fund FROM cgtest.t_ids), 'Which bank?', ARRAY['BOC', 'HNB'], FALSE, TRUE, NOW() + INTERVAL '1 day');
SELECT public.poll_vote(p.id, ARRAY[(SELECT o.id FROM public.poll_options o WHERE o.poll_id = p.id AND o.position = 1)])
FROM public.polls p WHERE p.question = 'Which bank?';
-- Changing the vote retracts the first choice.
SELECT public.poll_vote(p.id, ARRAY[(SELECT o.id FROM public.poll_options o WHERE o.poll_id = p.id AND o.position = 2)])
FROM public.polls p WHERE p.question = 'Which bank?';
SELECT cgtest.as_user('00000000-0000-4000-8000-0000000c0002');
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.poll_votes v JOIN public.polls p ON p.id = v.poll_id WHERE p.question = 'Which bank?') THEN
    RAISE EXCEPTION 'FAIL: anonymous voter visible';
  END IF;
  IF (SELECT string_agg(vote_count::TEXT, ',' ORDER BY position) FROM public.poll_options o JOIN public.polls p ON p.id = o.poll_id
      WHERE p.question = 'Which bank?') <> '0,1' THEN
    RAISE EXCEPTION 'FAIL: changed poll vote counts';
  END IF;
  RAISE NOTICE 'ok: anonymous poll, vote change';
END $$;

-- Notifications: only your own.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.notifications WHERE user_id <> '00000000-0000-4000-8000-0000000c0002') THEN
    RAISE EXCEPTION 'FAIL: read others'' notifications';
  END IF;
  RAISE NOTICE 'ok: notifications private';
END $$;

RESET ROLE;
-- Raising here guarantees nothing is kept, even if ROLLBACK below is skipped.
DO $$ BEGIN RAISE EXCEPTION 'ALL_COMMUNITY_TESTS_PASSED'; END $$;
ROLLBACK;
