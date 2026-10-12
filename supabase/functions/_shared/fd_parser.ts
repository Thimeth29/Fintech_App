// Extracts LKR fixed-deposit rates from a bank's "rates & tariffs" HTML page.
//
// Bank pages differ, but their FD tables share one shape: the first cell
// names the tenure ("6 Months", "1 Year - Interest at maturity", ...) and a
// later cell holds the annual rate. We parse every <table>, keep rows that
// look like standard LKR deposits paid at maturity, and use the table that
// yields the most tenures.
//
// Plain TypeScript with no dependencies so it runs in Deno (edge function)
// and Node (local tests) alike.

export interface FdRates {
  rate_1m: number | null;
  rate_3m: number | null;
  rate_6m: number | null;
  rate_12m: number | null;
  rate_24m: number | null;
  rate_60m: number | null;
}

const TRACKED_MONTHS: Record<number, keyof FdRates> = {
  1: 'rate_1m',
  3: 'rate_3m',
  6: 'rate_6m',
  12: 'rate_12m',
  24: 'rate_24m',
  60: 'rate_60m',
};

// Rows for products we don't compare (foreign currency, senior citizens,
// minors, staff, promos, non-maturity payouts handled separately).
const EXCLUDE_ROW =
  /\b(usd|gbp|eur|euro|aud|cad|jpy|sgd|chf|nzd|sek|hkd|cny|inr|fcy|foreign|senior|minor|children|child|staff|special|nrfc|rfc|pensioner|women|sevana|udara|ladies)\b/i;
const NON_MATURITY = /\b(monthly|annually|quarterly|semi[- ]?annual|half[- ]?yearly|upfront|in advance)\b/i;
const MATURITY = /maturity/i;
const EXCLUDE_TABLE = /\b(usd|gbp|eur|aud|foreign currency|fcy|loan|lending|pawning|leasing|treasury)\b/i;
// Headings of tables that aren't the standard retail FD.
const EXCLUDE_CONTEXT =
  /\b(senior|minor|loans?|advances|lending|pawning|leasing|certificate of deposits?|foreign currency|fcy|usd|co-operative|samurdhi|treasury)\b/i;

export function decodeEntities(s: string): string {
  return s
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)));
}

export function stripTags(s: string): string {
  return decodeEntities(s.replace(/<br\s*\/?>/gi, ' ').replace(/<[^>]+>/g, ' '))
    .replace(/\s+/g, ' ')
    .trim();
}

export interface HtmlTable {
  rows: string[][];
  /** Visible text just before the table, usually its heading. */
  context: string;
}

/** Every table in the page as rows of cell text, plus the text above it. */
export function extractTables(html: string): HtmlTable[] {
  const clean = html
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<!--[\s\S]*?-->/g, '');
  const result: HtmlTable[] = [];
  const re = /<table[\s\S]*?<\/table>/gi;
  let prevEnd = 0;
  let m: RegExpExecArray | null;
  while ((m = re.exec(clean))) {
    const before = stripTags(clean.slice(Math.max(prevEnd, m.index - 2000), m.index));
    result.push({
      context: before.slice(-400),
      rows: (m[0].match(/<tr[\s\S]*?<\/tr>/gi) ?? []).map((r) =>
        (r.match(/<t[hd][\s\S]*?<\/t[hd]>/gi) ?? []).map(stripTags)
      ),
    });
    prevEnd = m.index + m[0].length;
  }
  return result;
}

/** "6 Months" -> 6, "1 Year" -> 12, "01 Year maturity" -> 12, "91 days" -> 3. */
export function tenureMonths(label: string): number | null {
  const m = label.match(/(\d{1,3})\s*(months?|mths?|mnths?|years?|yrs?)\b/i);
  if (m) {
    const n = Number(m[1]);
    return /^y/i.test(m[2]) ? n * 12 : n;
  }
  const d = label.match(/(\d{2,4})\s*days?\b/i);
  if (d) {
    const days = Number(d[1]);
    const months = Math.round(days / 30.4);
    return [1, 3, 6, 12, 24, 60].includes(months) && Math.abs(days - months * 30.4) < 8
      ? months
      : null;
  }
  return null;
}

/** A cell that is nothing but a tenure, e.g. "12 Month" or "02 Years". */
function isTenureHeader(cell: string): boolean {
  return /^\s*\d{1,3}\s*(months?|mths?|years?|yrs?)\s*$/i.test(cell);
}

/** Rate in a cell that starts with one: "10.25%", "9.5% (AER 9.73%)", "10.00". */
export function cellRate(cell: string): number | null {
  if (tenureMonths(cell) !== null) return null; // "3 Month" is not a rate
  const m = cell.match(/^\s*(\d{1,2}(?:\.\d{1,3})?)(?![\d,])\s*%?/);
  if (!m) return null; // "Rs. 5,000", "-", "N/A"
  const v = Number(m[1]);
  return v >= 0.5 && v <= 30 ? v : null;
}

/** First plausible annual rate (0.5%–30%) among the cells. */
export function firstRate(cells: string[]): number | null {
  for (const cell of cells) {
    const v = cellRate(cell);
    if (v !== null) return v;
  }
  return null;
}

interface Candidate {
  months: number;
  rate: number;
  maturity: boolean;
}

/**
 * Tables with tenures across the header row and one row per currency /
 * payout type (e.g. Nations Trust):
 *   Currency | Deposit type          | 1 Month | 3 Month | ...
 *   LKR      | Fixed Deposit–Maturity | 8.00%   | 9.00%   | ...
 *            | Fixed Deposit–Monthly  |         | 9.55%   | ...   (rowspan)
 */
function parseTransposed(rows: string[][]): Candidate[] {
  const headerIdx = rows.findIndex((r) => r.filter(isTenureHeader).length >= 3);
  if (headerIdx < 0) return [];
  const header = rows[headerIdx];
  const out: Candidate[] = [];
  let currency = 'LKR';

  for (const cells of rows.slice(headerIdx + 1)) {
    const code = cells.find((c) => /^[A-Z]{3}$/.test(c.trim()));
    if (code) currency = code.trim();
    if (currency !== 'LKR') continue;
    const label = cells.find((c) => c !== code && /[a-z]{3}/i.test(c) && firstRate([c]) === null) ?? '';
    if (EXCLUDE_ROW.test(label)) continue;
    const maturity = MATURITY.test(label) || !NON_MATURITY.test(label);
    // Rowspan cells shift a row left, so line cells up from the right.
    const shift = header.length - cells.length;
    header.forEach((h, j) => {
      const months = tenureMonths(h);
      const cell = cells[j - shift];
      if (months === null || cell === undefined || j - shift < 0) return;
      const rate = firstRate([cell]);
      if (rate !== null && /\d/.test(cell)) out.push({ months, rate, maturity });
    });
  }
  return out;
}

function parseTable(rows: string[][]): Map<number, number> {
  const candidates: Candidate[] = [];
  // Header like "Period | Amount | Monthly | AER | Maturity | AER": read the
  // Maturity column instead of the first number in the row.
  let header: string[] | null = null;
  let maturityCol = -1;

  for (const cells of rows) {
    if (cells.length < 2 || cells.filter(isTenureHeader).length >= 3) continue;
    const labelIdx = cells.findIndex((c) => tenureMonths(c) !== null);

    if (labelIdx < 0) {
      // A header row: no rates in it.
      if (cells.every((c) => cellRate(c) === null)) {
        header = cells;
        maturityCol = cells.findIndex((c) => MATURITY.test(c));
      }
      continue;
    }

    // The label is the first cell that names a tenure; the rate follows it.
    const label = cells[labelIdx];
    if (EXCLUDE_ROW.test(label)) continue;
    const months = tenureMonths(label)!;

    let rate: number | null;
    let maturity = MATURITY.test(label) || !NON_MATURITY.test(label);
    if (header && maturityCol > 0) {
      // Rowspan/colspan can make rows shorter than the header: align right.
      const col = maturityCol - (header.length - cells.length);
      rate = col > labelIdx ? cellRate(cells[col] ?? '') : null;
      maturity = true;
    } else {
      rate = firstRate(cells.slice(labelIdx + 1));
    }
    if (rate === null) continue;
    candidates.push({ months, rate, maturity });
  }

  candidates.push(...parseTransposed(rows));

  // Per tenure: prefer an explicit "at maturity" row; skip monthly-payout rows.
  const result = new Map<number, number>();
  for (const c of candidates) {
    if (!c.maturity) continue;
    if (!result.has(c.months)) result.set(c.months, c.rate);
  }
  return result;
}

/**
 * Best-effort LKR FD rates from a bank page; null if nothing usable found.
 * [tableHint], when given, must match the text above the right table — use
 * it for banks whose page has several FD-like tables.
 */
export function parseFdRates(html: string, tableHint?: RegExp): FdRates | null {
  let best: Map<number, number> | null = null;
  let bestScore = 0;

  for (const { rows, context } of extractTables(html)) {
    const head = rows.slice(0, 2).flat().join(' ');
    if (EXCLUDE_TABLE.test(head)) continue;
    // The last ~100 chars before a table are effectively its heading.
    if (tableHint ? !tableHint.test(context) : EXCLUDE_CONTEXT.test(context.slice(-100))) continue;
    const parsed = parseTable(rows);
    const tenures = [...parsed.keys()].filter((m) => m in TRACKED_MONTHS).length;
    if (tenures < 2) continue; // need two standard tenures to trust a table
    const score = tenures + (/fixed deposit/i.test(context) ? 2 : 0);
    if (score > bestScore) {
      best = parsed;
      bestScore = score;
    }
  }

  if (!best) return null;

  const rates: FdRates = {
    rate_1m: null, rate_3m: null, rate_6m: null,
    rate_12m: null, rate_24m: null, rate_60m: null,
  };
  for (const [months, key] of Object.entries(TRACKED_MONTHS)) {
    rates[key] = best.get(Number(months)) ?? null;
  }
  return rates;
}
