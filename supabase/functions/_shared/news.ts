// Aggregates recent financial news from local (Sri Lankan) and international
// RSS feeds into one list, newest first. Dependency-free so it runs in Deno
// (edge function) and Node (local tests).

import { decodeEntities, stripTags } from './fd_parser.ts';

export interface NewsItem {
  title: string;
  summary: string;
  url: string;
  image: string | null;
  source: string;
  region: 'local' | 'world';
  published_at: string; // ISO
}

interface Feed {
  source: string;
  region: 'local' | 'world';
  url: string;
  /** Offset for feeds that publish times without a timezone. */
  naiveTz?: string;
}

export const FEEDS: Feed[] = [
  { source: 'EconomyNext', region: 'local', url: 'https://economynext.com/feed/' },
  { source: 'Daily Mirror', region: 'local', url: 'https://www.dailymirror.lk/rss/business/215', naiveTz: '+05:30' },
  { source: 'Lanka Business Online', region: 'local', url: 'https://www.lankabusinessonline.com/feed/' },
  { source: 'BBC Business', region: 'world', url: 'https://feeds.bbci.co.uk/news/business/rss.xml' },
  { source: 'CNBC', region: 'world', url: 'https://www.cnbc.com/id/10001147/device/rss/rss.html' },
  { source: 'MarketWatch', region: 'world', url: 'https://feeds.content.dowjones.io/public/rss/mw_topstories' },
  { source: 'Investing.com', region: 'world', url: 'https://www.investing.com/rss/news_25.rss', naiveTz: 'Z' },
];

// Some publishers (e.g. EconomyNext) reject bot user agents.
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36';

function tag(xml: string, name: string): string | null {
  const m = xml.match(new RegExp(`<${name}(?:\\s[^>]*)?>([\\s\\S]*?)</${name}>`, 'i'));
  if (!m) return null;
  return m[1].replace(/^\s*<!\[CDATA\[([\s\S]*?)\]\]>\s*$/, '$1').trim();
}

function attr(xml: string, name: string, attribute: string): string | null {
  const m = xml.match(new RegExp(`<${name}\\b[^>]*\\b${attribute}="([^"]+)"`, 'i'));
  return m ? decodeEntities(m[1]) : null;
}

function parseDate(raw: string | null, naiveTz?: string): Date | null {
  if (!raw) return null;
  let s = raw.trim();
  // "2026-10-10 12:20:00" has no zone: apply the feed's known offset.
  if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?$/.test(s)) s = s.replace(' ', 'T') + (naiveTz ?? 'Z');
  const d = new Date(s);
  return isNaN(d.getTime()) ? null : d;
}

export function parseFeed(xml: string, feed: Feed): NewsItem[] {
  const items = xml.match(/<(item|entry)[\s>][\s\S]*?<\/(item|entry)>/gi) ?? [];
  const out: NewsItem[] = [];
  for (const item of items) {
    const title = stripTags(tag(item, 'title') ?? '');
    const url = (tag(item, 'link') || attr(item, 'link', 'href') || '').trim();
    const date = parseDate(
      tag(item, 'pubDate') ?? tag(item, 'published') ?? tag(item, 'updated') ?? tag(item, 'dc:date'),
      feed.naiveTz,
    );
    if (!title || !/^https?:\/\//.test(url) || !date) continue;

    const body = tag(item, 'content:encoded') ?? tag(item, 'description') ?? tag(item, 'summary') ?? '';
    const image =
      attr(item, 'media:content', 'url') ??
      attr(item, 'media:thumbnail', 'url') ??
      attr(item, 'enclosure', 'url') ??
      decodeEntities(body).match(/<img[^>]+src="([^"]+)"/i)?.[1] ??
      null;
    const summary = stripTags(decodeEntities(body)).slice(0, 220);

    out.push({
      title,
      summary,
      url,
      image: image && /^https?:\/\//.test(image) ? image : null,
      source: feed.source,
      region: feed.region,
      published_at: date.toISOString(),
    });
  }
  return out;
}

/** Fetch every feed in parallel; a failing feed is skipped, not fatal. */
export async function collectNews(limit = 40): Promise<{ items: NewsItem[]; failed: string[] }> {
  const failed: string[] = [];
  const lists = await Promise.all(
    FEEDS.map(async (feed) => {
      try {
        const res = await fetch(feed.url, {
          headers: { 'user-agent': UA, accept: 'application/rss+xml, application/xml, text/xml, */*' },
          signal: AbortSignal.timeout(10000),
        });
        if (!res.ok) throw new Error(String(res.status));
        return parseFeed(await res.text(), feed).slice(0, 12);
      } catch {
        failed.push(feed.source);
        return [];
      }
    }),
  );

  const now = Date.now();
  const seen = new Set<string>();
  const newestFirst = lists
    .flat()
    .filter((n) => Date.parse(n.published_at) <= now + 10 * 60_000) // drop bogus future dates
    .filter((n) => {
      const key = n.title.toLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .sort((a, b) => b.published_at.localeCompare(a.published_at));

  // Half local, half world, so fast-moving international wires don't push
  // Sri Lankan stories out; a short region is topped up from the other.
  const local = newestFirst.filter((n) => n.region === 'local');
  const world = newestFirst.filter((n) => n.region === 'world');
  const half = Math.ceil(limit / 2);
  const takeLocal = Math.min(local.length, Math.max(half, limit - world.length));
  const takeWorld = Math.min(world.length, limit - takeLocal);
  const items = [...local.slice(0, takeLocal), ...world.slice(0, takeWorld)]
    .sort((a, b) => b.published_at.localeCompare(a.published_at));
  return { items, failed };
}
