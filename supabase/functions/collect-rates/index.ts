// POST /functions/v1/collect-rates — the daily collector.
//
// Scrapes each institution's official FD rate page and Bank of Ceylon's
// weekly T-bill table, then upserts into `fd_rates` / `gov_security_yields`.
// The app is subscribed to both tables via Supabase Realtime, so new rates
// appear on screen as soon as this finishes.
//
// Triggered once a day by pg_cron (see supabase_schema.sql), which sends the
// password stored in Vault as the `x-cron-secret` header. It's accepted if it
// matches that Vault secret (checked via the verify_cron_secret function) or
// the optional CRON_SECRET function secret.

import { createClient } from 'npm:@supabase/supabase-js@2';
import { parseFdRates } from '../_shared/fd_parser.ts';
import { INSTITUTIONS } from '../_shared/institutions.ts';
import { parseBocTbills } from '../_shared/tbill_parser.ts';
import { corsHeaders, json } from '../_shared/http.ts';

const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36';
const BOC_RATES_URL = 'https://www.boc.lk/rates-tariff';
const TBILL_ORDER: Record<number, number> = { 91: 1, 182: 2, 364: 3 };

async function fetchHtml(url: string): Promise<string> {
  const res = await fetch(url, { headers: { 'user-agent': UA }, signal: AbortSignal.timeout(25000) });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.text();
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  const provided = req.headers.get('x-cron-secret') ?? '';
  let authorized = provided !== '' && provided === Deno.env.get('CRON_SECRET');
  if (!authorized && provided !== '') {
    const { data } = await db.rpc('verify_cron_secret', { candidate: provided });
    authorized = data === true;
  }
  if (!authorized) return json({ error: 'unauthorized' }, 401);

  const now = new Date().toISOString();

  // Fetch each page once (BOC's page serves both FD and T-bill rates).
  const pages = new Map<string, Promise<string>>();
  const page = (url: string) => {
    if (!pages.has(url)) pages.set(url, fetchHtml(url));
    return pages.get(url)!;
  };

  // ---- FD rates ----
  const fdReport = await Promise.all(INSTITUTIONS.map(async (inst) => {
    try {
      const rates = parseFdRates(await page(inst.url), inst.tableHint);
      if (!rates) return { institution: inst.name, ok: false, error: 'rate table not found (page layout changed?)' };
      const { error } = await db.from('fd_rates').upsert({
        institution: inst.name,
        institution_type: inst.type,
        sldis_member: true,
        ...rates,
        source_url: inst.url,
        updated_at: now,
      });
      if (error) throw error;
      return { institution: inst.name, ok: true, rates };
    } catch (e) {
      // Keep yesterday's row rather than blanking it.
      return { institution: inst.name, ok: false, error: (e as Error).message };
    }
  }));

  // ---- T-bills ----
  let tbillReport: unknown;
  try {
    const parsed = parseBocTbills(await page(BOC_RATES_URL));
    if (!parsed) throw new Error('T-bill table not found');

    const { data: existing } = await db.from('gov_security_yields').select('security, yield_rate, previous_yield');
    const old = new Map((existing ?? []).map((r) => [r.security, r]));

    const rows = parsed.yields.map((y) => {
      const prev = old.get(y.security);
      const prevRate = prev?.yield_rate == null ? null : Number(prev.yield_rate);
      return {
        security: y.security,
        kind: 'bill',
        sort_order: TBILL_ORDER[y.days] ?? y.days,
        yield_rate: y.yield_rate,
        // Only roll the previous yield forward when the rate actually changes.
        previous_yield: prevRate !== null && prevRate !== y.yield_rate ? prevRate : prev?.previous_yield ?? null,
        auction_date: parsed.weekCommencing,
        source_url: BOC_RATES_URL,
        updated_at: now,
      };
    });
    const { error } = await db.from('gov_security_yields').upsert(rows);
    if (error) throw error;
    tbillReport = { ok: true, week_commencing: parsed.weekCommencing, yields: parsed.yields };
  } catch (e) {
    tbillReport = { ok: false, error: (e as Error).message };
  }

  return json({
    ran_at: now,
    fd_updated: fdReport.filter((r) => r.ok).length,
    fd_failed: fdReport.filter((r) => !r.ok).length,
    fd: fdReport,
    tbills: tbillReport,
  });
});
