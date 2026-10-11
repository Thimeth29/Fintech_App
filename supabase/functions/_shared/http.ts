// CORS + JSON helpers so the Flutter app (including web builds) can call
// these functions directly.

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-cron-secret',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

export function json(body: unknown, status = 200, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json; charset=utf-8', ...extra },
  });
}

/** Serve [load] with a small in-memory cache so many app users share one upstream fetch. */
export function cachedHandler(ttlMs: number, load: () => Promise<unknown>) {
  let cached: { at: number; body: unknown } | null = null;
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
    try {
      if (!cached || Date.now() - cached.at > ttlMs) {
        cached = { at: Date.now(), body: await load() };
      }
      return json(cached.body, 200, { 'cache-control': `public, max-age=${Math.floor(ttlMs / 1000)}` });
    } catch (e) {
      // Serve the last good copy rather than an error if upstream blips.
      if (cached) return json(cached.body);
      return json({ error: (e as Error).message }, 502);
    }
  };
}
