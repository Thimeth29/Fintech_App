// GET /functions/v1/cse-market — live CSE snapshot (indices, market status,
// turnover, top gainers/losers, most active). Cached 30 s per instance.

import { fetchCseSnapshot } from '../_shared/cse.ts';
import { cachedHandler } from '../_shared/http.ts';

Deno.serve(cachedHandler(30_000, fetchCseSnapshot));
