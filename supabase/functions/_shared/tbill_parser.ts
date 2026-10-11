// Parses Bank of Ceylon's weekly "TREASURY BILL RATES APPLICABLE FOR THE
// WEEK COMMENCING FROM dd.mm.yyyy" table on https://www.boc.lk/rates-tariff.
// CBSL publishes auction results only as PDFs; BOC's table is the rate a
// retail investor can actually buy at that week.

import { extractTables } from './fd_parser.ts';

export interface TbillYield {
  security: string; // matches the app: "91-day T-Bill" etc.
  days: number;
  yield_rate: number;
}

export interface TbillResult {
  weekCommencing: string | null; // ISO date
  yields: TbillYield[];
}

export function parseBocTbills(html: string): TbillResult | null {
  for (const { rows, context } of extractTables(html)) {
    const text = context + ' ' + rows.flat().join(' ');
    if (!/treasury bill rates/i.test(text)) continue;

    const yields: TbillYield[] = [];
    for (const cells of rows) {
      const days = cells.join(' ').match(/\((\d{2,3})\s*days\)/i);
      if (!days) continue;
      const pct = cells.map((c) => c.match(/^\s*(\d{1,2}\.\d{1,3})\s*%/)).find((m) => m);
      if (!pct) continue;
      const d = Number(days[1]);
      yields.push({ security: `${d}-day T-Bill`, days: d, yield_rate: Number(pct[1]) });
    }
    if (yields.length === 0) continue;

    const date = text.match(/commencing from\s*(\d{2})\.(\d{2})\.(\d{4})/i);
    return {
      weekCommencing: date ? `${date[3]}-${date[2]}-${date[1]}` : null,
      yields,
    };
  }
  return null;
}
