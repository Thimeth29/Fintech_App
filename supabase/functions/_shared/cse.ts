// Live Colombo Stock Exchange snapshot from cse.lk's public JSON endpoints.
// cse.lk sends no CORS headers, so browsers (Flutter web) can't call it
// directly — the app goes through the `cse-market` edge function instead.

const BASE = 'https://www.cse.lk/api';
const UA = 'Mozilla/5.0 (compatible; FinSmartMarketBot/1.0)';

async function post(endpoint: string): Promise<any> {
  const res = await fetch(`${BASE}/${endpoint}`, {
    method: 'POST',
    headers: { 'user-agent': UA, accept: 'application/json' },
    signal: AbortSignal.timeout(10000),
  });
  if (!res.ok) throw new Error(`${endpoint} ${res.status}`);
  return res.json();
}

const num = (v: unknown): number | null =>
  typeof v === 'number' ? v : v == null || v === '' ? null : Number.isFinite(Number(v)) ? Number(v) : null;

export interface CseSnapshot {
  market_status: string | null;
  indices: { name: string; value: number | null; change: number | null; change_percentage: number | null; high: number | null; low: number | null }[];
  summary: { turnover: number | null; share_volume: number | null; trades: number | null } | null;
  gainers: Quote[];
  losers: Quote[];
  most_active: Quote[];
  fetched_at: string;
}

interface Quote {
  symbol: string;
  name: string;
  price: number | null;
  change: number | null;
  change_percentage: number | null;
  turnover: number | null;
}

export async function fetchCseSnapshot(): Promise<CseSnapshot> {
  const settled = await Promise.allSettled([
    post('marketStatus'),
    post('aspiData'),
    post('snpData'),
    post('marketSummery'), // (sic)
    post('topGainers'),
    post('topLooses'), // (sic)
    post('tradeSummary'),
  ]);
  const [status, aspi, snp, summary, gainers, losers, trades] = settled.map((s) =>
    s.status === 'fulfilled' ? s.value : null
  );
  if (!aspi && !snp && !gainers) throw new Error('cse.lk unreachable');

  // tradeSummary carries company names and turnover; gainers/losers don't.
  const all: any[] = trades?.reqTradeSummery ?? [];
  const bySymbol = new Map(all.map((t) => [t.symbol, t]));
  const toQuote = (q: any): Quote => {
    const t = bySymbol.get(q.symbol);
    return {
      symbol: String(q.symbol ?? ''),
      name: String(t?.name ?? q.name ?? ''),
      price: num(q.price ?? q.lastTradedPrice),
      change: num(q.change),
      change_percentage: num(q.changePercentage ?? q.percentageChange),
      turnover: num(t?.turnover),
    };
  };
  const index = (name: string, d: any) => ({
    name,
    value: num(d?.value),
    change: num(d?.change),
    change_percentage: num(d?.percentage ?? d?.changePercentage),
    high: num(d?.highValue),
    low: num(d?.lowValue),
  });

  return {
    market_status: status?.status ?? null,
    indices: [aspi && index('ASPI', aspi), snp && index('S&P SL20', snp)].filter(Boolean) as CseSnapshot['indices'],
    summary: summary
      ? { turnover: num(summary.tradeVolume), share_volume: num(summary.shareVolume), trades: num(summary.trades) }
      : null,
    gainers: (Array.isArray(gainers) ? gainers : []).slice(0, 10).map(toQuote),
    losers: (Array.isArray(losers) ? losers : []).slice(0, 10).map(toQuote),
    most_active: [...all]
      .sort((a, b) => (num(b.turnover) ?? 0) - (num(a.turnover) ?? 0))
      .slice(0, 10)
      .map((t) => toQuote({ ...t, changePercentage: t.percentageChange })),
    fetched_at: new Date().toISOString(),
  };
}
