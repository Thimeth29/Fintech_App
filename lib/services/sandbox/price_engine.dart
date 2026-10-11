// lib/services/sandbox/price_engine.dart
//
// Simulated prices for the Investment Trainer. Pure Dart (no Flutter, no
// dart:io) so it runs the same on mobile, desktop and web, and in tests.
//
// * Daily prices follow a geometric Brownian motion seeded by
//   user + instrument + day, so a reload shows exactly the same path.
//   Day 0 is the anchor (a real market price captured when the module was
//   unlocked); negative days give the chart some history before that.
// * Scripted news events nudge prices on particular days. They're the
//   main teaching moments, so each carries a short "why".
// * Yields (T-bills, T-bonds, new FD rates) follow a slow mean-reverting
//   walk plus rate-decision events.
// * The trading module runs on an intraday tick path instead.
//
// All hashing is 32-bit and avoids products above 2^53, so the numbers are
// identical under dart2js.

import 'dart:math' as math;

import '../../core/sandbox/sandbox_config.dart';

// ---------------------------------------------------------------------------
// Deterministic randomness
// ---------------------------------------------------------------------------
const int _mask32 = 0xFFFFFFFF;

/// (a * b) mod 2^32 without overflowing a JS double.
int _mul32(int a, int b) {
  final lo = (a & 0xFFFF) * b;
  final hi = (((a >> 16) & 0xFFFF) * b) & 0xFFFF;
  return (lo + hi * 65536) & _mask32;
}

/// Murmur3 finaliser: scrambles a 32-bit value.
int mix32(int h) {
  h &= _mask32;
  h ^= h >> 16;
  h = _mul32(h, 0x85ebca6b);
  h ^= h >> 13;
  h = _mul32(h, 0xc2b2ae35);
  h ^= h >> 16;
  return h & _mask32;
}

/// FNV-1a over UTF-16 code units.
int hashString(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = (h ^ c) & _mask32;
    h = _mul32(h, 0x01000193);
  }
  return h;
}

int combine(int h, int v) => mix32((h ^ mix32((v & _mask32) + 0x9e3779b9)) & _mask32);

/// Uniform in (0, 1).
double unitFromHash(int h) => (mix32(h) + 0.5) / 4294967296.0;

/// Standard normal via Box–Muller.
double normalFromHash(int h) {
  final u1 = unitFromHash(h);
  final u2 = unitFromHash(h ^ 0x5bd1e995);
  return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
}

// ---------------------------------------------------------------------------
// News
// ---------------------------------------------------------------------------
class NewsEvent {
  final SandboxModule module;
  final int day; // sim day index (or tick for trading)
  final String headline;
  final String why;

  /// Symbols moved, with the log-return shock applied to each.
  final Map<String, double> shocks;

  /// Shift in percentage points to yields / new deposit rates.
  final double rateShift;

  /// e.g. 'inflation', 'rate_cut', 'rate_hike', 'earnings'
  final String kind;

  const NewsEvent({
    required this.module,
    required this.day,
    required this.headline,
    required this.why,
    this.shocks = const {},
    this.rateShift = 0,
    this.kind = 'general',
  });

  bool get isPositive => shocks.values.fold(0.0, (a, b) => a + b) - rateShift >= 0;
}

class _Template {
  final String headline;
  final String why;
  final double shock; // log-return for a company / gold / trading
  final double rateShift;
  final String kind;
  final bool marketWide;
  const _Template(this.headline, this.why,
      {this.shock = 0, this.rateShift = 0, this.kind = 'general', this.marketWide = false});
}

const _cseCompanyNews = [
  _Template('{name} reports record quarterly profit',
      'Higher profits mean more earnings per share and often bigger dividends, so investors pay more for each share.',
      shock: 0.07, kind: 'earnings'),
  _Template('{name} profit falls short of expectations',
      'The price already assumed good results. When profits disappoint, investors lower what they will pay.',
      shock: -0.08, kind: 'earnings'),
  _Template('{name} announces a large new project',
      'Investors expect the project to grow future earnings, but it also costs money and carries risk.',
      shock: 0.04),
  _Template('{name} faces a regulatory probe',
      'Uncertainty about fines or rule changes makes investors nervous, so some sell and the price drops.',
      shock: -0.06),
  _Template('{sector} sector hit by higher costs',
      'Rising costs squeeze profit margins for every company in the sector, not just one.',
      shock: -0.05),
];

const _cseMarketNews = [
  _Template('Central Bank cuts the policy rate',
      'Lower interest rates make borrowing cheaper for companies and make FDs less attractive, so money flows into shares.',
      shock: 0.03, kind: 'rate_cut', marketWide: true),
  _Template('Foreign investors sell Sri Lankan shares',
      'Large sellers push prices down across the market. Diversifying doesn\'t stop this, but it limits the damage.',
      shock: -0.04, marketWide: true),
  _Template('IMF review completed successfully',
      'Confidence in the economy improves, so investors are willing to pay more for local companies.',
      shock: 0.025, marketWide: true),
];

const _goldNews = [
  _Template('Rupee weakens against the US dollar',
      'Gold is priced in dollars worldwide. When the rupee falls, the same gold costs more rupees.',
      shock: 0.035),
  _Template('Global inflation fears rise',
      'When people worry that money will buy less, they turn to gold as a store of value. This is gold\'s inflation-hedge role.',
      shock: 0.045, kind: 'inflation'),
  _Template('US dollar strengthens globally',
      'A strong dollar makes gold more expensive for the rest of the world, so demand and the price dip.',
      shock: -0.03),
  _Template('Central banks buy record amounts of gold',
      'Big buyers increase demand. More demand with the same supply lifts the price.',
      shock: 0.03),
  _Template('Risk appetite returns; investors sell gold for shares',
      'Gold earns no interest or dividends. When shares look attractive, some investors move money out of gold.',
      shock: -0.035),
];

const _rateNews = [
  _Template('Central Bank cuts the policy rate by 0.50%',
      'Lower policy rates pull down the yields on new T-bills and bonds. Existing bonds that pay higher coupons become worth more.',
      rateShift: -0.5, kind: 'rate_cut'),
  _Template('Central Bank raises the policy rate by 0.75%',
      'New bonds now pay more, so older bonds with lower coupons are worth less if you sell them before maturity.',
      rateShift: 0.75, kind: 'rate_hike'),
  _Template('Inflation comes in higher than expected',
      'Lenders demand higher yields so their real return isn\'t eaten by inflation.',
      rateShift: 0.4, kind: 'inflation'),
  _Template('Government borrowing needs fall',
      'With fewer bonds to sell, the government doesn\'t need to offer such high yields.',
      rateShift: -0.3),
];

const _fdNews = [
  _Template('Banks cut FD rates after a policy rate cut',
      'Your existing FD keeps its rate until maturity. Only new deposits get the lower rate — that\'s why locking in can help.',
      rateShift: -0.75, kind: 'rate_cut'),
  _Template('Banks raise FD rates to attract deposits',
      'New FDs now pay more. If you had locked in long at a lower rate, breaking early to switch usually costs more than it gains.',
      rateShift: 0.75, kind: 'rate_hike'),
  _Template('Inflation rises to 8%',
      'Your FD rate stays the same, but if inflation is higher than your after-tax rate, your real return is negative.',
      rateShift: 0.25, kind: 'inflation'),
];

const _tradingNews = [
  _Template('{name} goes viral on social media',
      'Hype brings in a rush of buyers. Prices driven by hype can reverse just as quickly.', shock: 0.05),
  _Template('Short-seller report questions {name}',
      'A credible negative report makes holders rush to sell. Stop-losses limit how much you lose in moves like this.',
      shock: -0.06),
  _Template('{name} beats sales forecast',
      'Better-than-expected numbers cause a quick jump. By the time you see the headline, much of the move is done.',
      shock: 0.035),
  _Template('Rumour: {name} loses a key contract',
      'Unconfirmed rumours move prices too. Trading on rumours is gambling on what other people will do.', shock: -0.04),
];

// ---------------------------------------------------------------------------
// Engine
// ---------------------------------------------------------------------------
class SandboxPriceEngine {
  /// Usually the user id; any string works (tests use fixed seeds).
  final String seed;
  final int _seedHash;

  SandboxPriceEngine(this.seed) : _seedHash = hashString(seed);

  /// Cumulative log-returns per symbol: [_pos][d-1] = sum r_1..r_d,
  /// [_neg][k-1] = sum r_{-k+1}..r_0 (used for days before the anchor).
  final Map<String, List<double>> _pos = {};
  final Map<String, List<double>> _neg = {};
  final Map<String, List<double>> _rateCum = {};
  final Map<String, NewsEvent?> _newsCache = {};

  static const double _dt = 1 / 365;
  static const double maxLogMove = 3.0; // prices stay within ~5%..20x of the anchor

  static const Map<SandboxModule, double> _newsChance = {
    SandboxModule.cse: 0.025,
    SandboxModule.gold: 0.012,
    SandboxModule.govSecurities: 0.01,
    SandboxModule.fd: 0.008,
  };

  int _h(String salt) => hashString('$seed|$salt');

  /// The one news event (if any) for [module] on sim [day].
  NewsEvent? newsOn(SandboxModule module, int day) {
    if (module == SandboxModule.trading) return null;
    final key = '${module.id}|$day';
    if (_newsCache.containsKey(key)) return _newsCache[key];
    final base = combine(combine(_seedHash, hashString('news|${module.id}')), day);
    NewsEvent? event;
    if (day > 0 && unitFromHash(base) < (_newsChance[module] ?? 0)) {
      event = _buildNews(module, day, base);
    }
    _newsCache[key] = event;
    return event;
  }

  NewsEvent _buildNews(SandboxModule module, int day, int base) {
    int pick(int n, int salt) => (mix32(base ^ salt) % n);
    switch (module) {
      case SandboxModule.cse:
        final marketWide = unitFromHash(base ^ 0x1234) < 0.3;
        if (marketWide) {
          final t = _cseMarketNews[pick(_cseMarketNews.length, 7)];
          return NewsEvent(
            module: module,
            day: day,
            headline: t.headline,
            why: t.why,
            kind: t.kind,
            shocks: {for (final i in kCseInstruments) i.symbol: t.shock},
          );
        }
        final company = kCseInstruments[pick(kCseInstruments.length, 11)];
        final t = _cseCompanyNews[pick(_cseCompanyNews.length, 13)];
        final sectorWide = t.headline.contains('{sector}');
        return NewsEvent(
          module: module,
          day: day,
          headline: t.headline.replaceAll('{name}', company.name).replaceAll('{sector}', company.sector),
          why: t.why,
          kind: t.kind,
          shocks: sectorWide
              ? {for (final i in kCseInstruments.where((i) => i.sector == company.sector)) i.symbol: t.shock}
              : {company.symbol: t.shock},
        );
      case SandboxModule.gold:
        final t = _goldNews[pick(_goldNews.length, 17)];
        return NewsEvent(
          module: module,
          day: day,
          headline: t.headline,
          why: t.why,
          kind: t.kind,
          shocks: {for (final i in kGoldInstruments) i.symbol: t.shock},
        );
      case SandboxModule.govSecurities:
        final t = _rateNews[pick(_rateNews.length, 19)];
        return NewsEvent(module: module, day: day, headline: t.headline, why: t.why, kind: t.kind, rateShift: t.rateShift);
      case SandboxModule.fd:
        final t = _fdNews[pick(_fdNews.length, 23)];
        return NewsEvent(module: module, day: day, headline: t.headline, why: t.why, kind: t.kind, rateShift: t.rateShift);
      case SandboxModule.trading:
        throw StateError('trading news is intraday');
    }
  }

  /// News for [module] in days (from, to].
  List<NewsEvent> newsBetween(SandboxModule module, int fromDay, int toDay) => [
        for (var d = fromDay + 1; d <= toDay; d++)
          if (newsOn(module, d) case final e?) e,
      ];

  /// Log-return of [spec] on [day] (day >= 1 moves from day-1 to day; day
  /// <= 0 moves from day-1 to day as well, used for history).
  double dailyLogReturn(InstrumentSpec spec, int day) {
    final sigma = spec.volatility;
    final z = normalFromHash(combine(_h('px|${spec.symbol}'), day));
    var r = (spec.drift - 0.5 * sigma * sigma) * _dt + sigma * math.sqrt(_dt) * z;
    final news = newsOn(spec.module, day);
    if (news != null) r += news.shocks[spec.symbol] ?? 0;
    return r;
  }

  double _cumulative(InstrumentSpec spec, int day) {
    if (day == 0) return 0;
    if (day > 0) {
      final list = _pos.putIfAbsent(spec.symbol, () => []);
      while (list.length < day) {
        final prev = list.isEmpty ? 0.0 : list.last;
        list.add(prev + dailyLogReturn(spec, list.length + 1));
      }
      return list[day - 1];
    }
    final k = -day;
    final list = _neg.putIfAbsent(spec.symbol, () => []);
    while (list.length < k) {
      // Moving back from day -(n-1) to -n undoes r_{-(n-1)}.
      final prev = list.isEmpty ? 0.0 : list.last;
      list.add(prev + dailyLogReturn(spec, -list.length));
    }
    return -list[k - 1];
  }

  /// Simulated price of [spec] on sim [day], anchored at [anchor] on day 0.
  double priceOn(InstrumentSpec spec, double anchor, int day) {
    final c = _cumulative(spec, day).clamp(-maxLogMove, maxLogMove);
    return anchor * math.exp(c);
  }

  /// Prices for days from..to inclusive.
  List<double> path(InstrumentSpec spec, double anchor, int fromDay, int toDay) => [
        for (var d = fromDay; d <= toDay; d++) priceOn(spec, anchor, d),
      ];

  // -------------------------------------------------------------------------
  // Rates: yields and new-deposit rates move together within a module.
  // -------------------------------------------------------------------------

  /// Rate offset (percentage points) for [module] on [day]: a slow
  /// mean-reverting walk plus news shifts. Day 0 is 0 (the anchor).
  double rateOffset(SandboxModule module, int day) {
    if (day <= 0) return 0;
    final list = _rateCum.putIfAbsent(module.id, () => []);
    final h = _h('rate|${module.id}');
    while (list.length < day) {
      final d = list.length + 1;
      final prev = list.isEmpty ? 0.0 : list.last;
      final z = normalFromHash(combine(h, d));
      var next = prev * (1 - 0.003) + 0.025 * z;
      next += newsOn(module, d)?.rateShift ?? 0;
      list.add(next.clamp(-4.0, 6.0));
    }
    return list[day - 1];
  }

  /// [baseRate] (% p.a., from real data at day 0) moved by the module's
  /// rate walk. Never below 0.5%.
  double rateOn(SandboxModule module, double baseRate, int day) =>
      math.max(0.5, baseRate + rateOffset(module, day));

  // -------------------------------------------------------------------------
  // Intraday ticks (trading module)
  // -------------------------------------------------------------------------
  final Map<String, IntradaySeries> _intraday = {};

  /// The tick path for [spec] on calendar [date], starting from [dayOpen].
  /// Ticks are seconds since local midnight; [IntradaySeries.preTicks] of
  /// history before midnight are included so charts are never empty.
  IntradaySeries intraday(InstrumentSpec spec, double dayOpen, DateTime date) {
    final key = '${spec.symbol}|${date.year}-${date.month}-${date.day}';
    return _intraday.putIfAbsent(
      key,
      () => IntradaySeries._(
        spec: spec,
        open: dayOpen,
        seedHash: _h('tick|$key'),
        newsHash: _h('ticknews|$key'),
      ),
    );
  }
}

/// A lazily-extended tick path. Each tick is one simulated minute of a
/// busy market squeezed into one real second, so moves are visible.
class IntradaySeries {
  final InstrumentSpec spec;
  final double open;
  final int seedHash;
  final int newsHash;

  static const int preTicks = 6 * 3600;
  static const double newsChancePerTick = 1 / 1800;

  /// log price relative to [open], index i = tick (i - preTicks).
  final List<double> _logs = [0];
  final Map<int, NewsEvent> _news = {};

  IntradaySeries._({required this.spec, required this.open, required this.seedHash, required this.newsHash}) {
    _back.add(0);
  }

  // Backward history: _back[k] = log price at tick -k.
  final List<double> _back = [];

  double get _tickSigma => spec.volatility / math.sqrt(252 * 390);

  double _step(int tick) {
    var r = _tickSigma * normalFromHash(combine(seedHash, tick + 1000000));
    final n = newsAt(tick);
    if (n != null) r += n.shocks[spec.symbol] ?? 0;
    return r;
  }

  /// News that hit at [tick], if any.
  NewsEvent? newsAt(int tick) {
    if (_news.containsKey(tick)) return _news[tick];
    final h = combine(newsHash, tick + 1000000);
    if (tick <= 0 || unitFromHash(h) >= newsChancePerTick) return null;
    final t = _tradingNews[mix32(h ^ 29) % _tradingNews.length];
    final e = NewsEvent(
      module: SandboxModule.trading,
      day: tick,
      headline: t.headline.replaceAll('{name}', spec.name.replaceAll(' (fictional)', '')),
      why: t.why,
      shocks: {spec.symbol: t.shock},
    );
    _news[tick] = e;
    return e;
  }

  double _log(int tick) {
    if (tick >= 0) {
      while (_logs.length <= tick) {
        _logs.add(_logs.last + _step(_logs.length));
      }
      return _logs[tick];
    }
    final k = -tick;
    while (_back.length <= k) {
      // log(t-1) = log(t) - r_t
      _back.add(_back.last - _step(-(_back.length - 1)));
    }
    return _back[k];
  }

  double at(int tick) {
    final t = tick < -preTicks ? -preTicks : tick;
    return open * math.exp(_log(t).clamp(-SandboxPriceEngine.maxLogMove, SandboxPriceEngine.maxLogMove));
  }

  /// OHLC candles of [ticksPerCandle] ending at [endTick] (inclusive).
  List<Candle> candles({required int endTick, required int ticksPerCandle, required int count}) {
    final result = <Candle>[];
    // Align buckets to multiples of ticksPerCandle so candles don't shift.
    final lastStart = endTick - (endTick % ticksPerCandle + ticksPerCandle) % ticksPerCandle;
    for (var i = count - 1; i >= 0; i--) {
      final start = lastStart - i * ticksPerCandle;
      if (start < -preTicks) continue;
      final end = math.min(start + ticksPerCandle - 1, endTick);
      var hi = -double.infinity, lo = double.infinity;
      final o = at(start);
      var c = o;
      for (var t = start; t <= end; t++) {
        c = at(t);
        if (c > hi) hi = c;
        if (c < lo) lo = c;
      }
      result.add(Candle(startTick: start, open: o, high: hi, low: lo, close: c));
    }
    return result;
  }
}

class Candle {
  final int startTick;
  final double open, high, low, close;
  const Candle({required this.startTick, required this.open, required this.high, required this.low, required this.close});
  bool get isUp => close >= open;
}
