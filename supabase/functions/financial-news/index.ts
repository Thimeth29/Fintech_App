// GET /functions/v1/financial-news — latest local + international financial
// headlines merged from RSS feeds. Cached 5 min per instance.

import { collectNews } from '../_shared/news.ts';
import { cachedHandler } from '../_shared/http.ts';

Deno.serve(cachedHandler(5 * 60_000, async () => {
  const { items, failed } = await collectNews(40);
  if (items.length === 0) throw new Error('No feeds reachable');
  return { items, failed_sources: failed, fetched_at: new Date().toISOString() };
}));
