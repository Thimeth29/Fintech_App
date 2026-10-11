// lib/models/investing_models.dart
//
// Models behind the Investing Options pages (FD, Gold, CSE, Government
// Securities). FD rates and T-bill/T-bond yields come from Supabase tables
// (kept up to date by a scheduled job); gold is computed live from the
// international spot price and the USD/LKR rate.

double? _asDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _asDateOrNull(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

/// LCB = Licensed Commercial Bank, LSB = Licensed Specialised Bank,
/// LFC = Licensed Finance Company (all CBSL-regulated).
enum InstitutionType { lcb, lsb, lfc }

extension InstitutionTypeLabel on InstitutionType {
  String get shortLabel => switch (this) {
        InstitutionType.lcb => 'LCB',
        InstitutionType.lsb => 'LSB',
        InstitutionType.lfc => 'LFC',
      };

  String get longLabel => switch (this) {
        InstitutionType.lcb => 'Licensed Commercial Bank',
        InstitutionType.lsb => 'Licensed Specialised Bank',
        InstitutionType.lfc => 'Licensed Finance Company',
      };

  bool get isBank => this != InstitutionType.lfc;

  static InstitutionType parse(String? raw) => switch (raw?.toUpperCase()) {
        'LSB' => InstitutionType.lsb,
        'LFC' => InstitutionType.lfc,
        _ => InstitutionType.lcb,
      };
}

/// One institution's published FD rates (annual %, interest paid at
/// maturity). Any tenure the institution doesn't publish is null.
class FdRate {
  final String institution;
  final InstitutionType type;
  final bool sldisMember;
  final double? rate1m;
  final double? rate3m;
  final double? rate6m;
  final double? rate12m;
  final double? rate24m;
  final double? rate60m;
  final String sourceUrl;
  final DateTime? updatedAt;

  const FdRate({
    required this.institution,
    required this.type,
    required this.sourceUrl,
    this.sldisMember = true,
    this.rate1m,
    this.rate3m,
    this.rate6m,
    this.rate12m,
    this.rate24m,
    this.rate60m,
    this.updatedAt,
  });

  bool get hasRates =>
      [rate1m, rate3m, rate6m, rate12m, rate24m, rate60m].any((r) => r != null);

  factory FdRate.fromJson(Map<String, dynamic> json) => FdRate(
        institution: (json['institution'] ?? '').toString(),
        type: InstitutionTypeLabel.parse(json['institution_type']?.toString()),
        sldisMember: json['sldis_member'] != false,
        rate1m: _asDoubleOrNull(json['rate_1m']),
        rate3m: _asDoubleOrNull(json['rate_3m']),
        rate6m: _asDoubleOrNull(json['rate_6m']),
        rate12m: _asDoubleOrNull(json['rate_12m']),
        rate24m: _asDoubleOrNull(json['rate_24m']),
        rate60m: _asDoubleOrNull(json['rate_60m']),
        sourceUrl: (json['source_url'] ?? '').toString(),
        updatedAt: _asDateOrNull(json['updated_at']),
      );
}

/// Latest auction / market yield for one T-bill or T-bond tenure.
class GovSecurityYield {
  final String security; // e.g. "91-day T-Bill", "5-year T-Bond"
  final String kind; // "bill" or "bond"
  final int sortOrder;
  final double? yieldRate;
  final double? previousYield;
  final DateTime? auctionDate;
  final String sourceUrl;
  final DateTime? updatedAt;

  const GovSecurityYield({
    required this.security,
    required this.kind,
    required this.sortOrder,
    required this.sourceUrl,
    this.yieldRate,
    this.previousYield,
    this.auctionDate,
    this.updatedAt,
  });

  double? get change => (yieldRate != null && previousYield != null)
      ? yieldRate! - previousYield!
      : null;

  factory GovSecurityYield.fromJson(Map<String, dynamic> json) =>
      GovSecurityYield(
        security: (json['security'] ?? '').toString(),
        kind: (json['kind'] ?? 'bill').toString(),
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        yieldRate: _asDoubleOrNull(json['yield_rate']),
        previousYield: _asDoubleOrNull(json['previous_yield']),
        auctionDate: _asDateOrNull(json['auction_date']),
        sourceUrl: (json['source_url'] ?? '').toString(),
        updatedAt: _asDateOrNull(json['updated_at']),
      );
}

/// One CSE index reading (ASPI / S&P SL20).
class CseIndex {
  final String name;
  final double? value;
  final double? change;
  final double? changePercentage;
  final double? high;
  final double? low;

  const CseIndex({
    required this.name,
    this.value,
    this.change,
    this.changePercentage,
    this.high,
    this.low,
  });

  bool get isUp => (changePercentage ?? 0) >= 0;

  factory CseIndex.fromJson(Map<String, dynamic> json) => CseIndex(
        name: (json['name'] ?? '').toString(),
        value: _asDoubleOrNull(json['value']),
        change: _asDoubleOrNull(json['change']),
        changePercentage: _asDoubleOrNull(json['change_percentage']),
        high: _asDoubleOrNull(json['high']),
        low: _asDoubleOrNull(json['low']),
      );
}

class CseQuote {
  final String symbol;
  final String name;
  final double? price;
  final double? changePercentage;
  final double? turnover;

  const CseQuote({
    required this.symbol,
    required this.name,
    this.price,
    this.changePercentage,
    this.turnover,
  });

  bool get isUp => (changePercentage ?? 0) >= 0;

  factory CseQuote.fromJson(Map<String, dynamic> json) => CseQuote(
        symbol: (json['symbol'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        price: _asDoubleOrNull(json['price']),
        changePercentage: _asDoubleOrNull(json['change_percentage']),
        turnover: _asDoubleOrNull(json['turnover']),
      );
}

/// Everything the CSE page shows, from the `cse-market` edge function.
class CseSnapshot {
  final String? marketStatus; // e.g. "Market Open", "Market Closed"
  final List<CseIndex> indices;
  final double? turnover;
  final double? shareVolume;
  final int? trades;
  final List<CseQuote> gainers;
  final List<CseQuote> losers;
  final List<CseQuote> mostActive;
  final DateTime? fetchedAt;

  const CseSnapshot({
    this.marketStatus,
    this.indices = const [],
    this.turnover,
    this.shareVolume,
    this.trades,
    this.gainers = const [],
    this.losers = const [],
    this.mostActive = const [],
    this.fetchedAt,
  });

  factory CseSnapshot.fromJson(Map<String, dynamic> json) {
    List<CseQuote> quotes(String key) => ((json[key] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CseQuote.fromJson)
        .toList();
    final summary = json['summary'] as Map<String, dynamic>?;
    return CseSnapshot(
      marketStatus: json['market_status']?.toString(),
      indices: ((json['indices'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CseIndex.fromJson)
          .toList(),
      turnover: _asDoubleOrNull(summary?['turnover']),
      shareVolume: _asDoubleOrNull(summary?['share_volume']),
      trades: _asDoubleOrNull(summary?['trades'])?.toInt(),
      gainers: quotes('gainers'),
      losers: quotes('losers'),
      mostActive: quotes('most_active'),
      fetchedAt: _asDateOrNull(json['fetched_at']),
    );
  }
}

/// One headline from the `financial-news` edge function.
class NewsItem {
  final String title;
  final String summary;
  final String url;
  final String? image;
  final String source;
  final bool isLocal;
  final DateTime? publishedAt;

  const NewsItem({
    required this.title,
    required this.summary,
    required this.url,
    required this.source,
    required this.isLocal,
    this.image,
    this.publishedAt,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        title: (json['title'] ?? '').toString(),
        summary: (json['summary'] ?? '').toString(),
        url: (json['url'] ?? '').toString(),
        image: json['image']?.toString(),
        source: (json['source'] ?? '').toString(),
        isLocal: json['region'] == 'local',
        publishedAt: _asDateOrNull(json['published_at']),
      );
}

/// Live gold estimate derived from international spot (USD / troy oz)
/// and the USD/LKR rate. Excludes local import levies and dealer margins.
class GoldQuote {
  static const double gramsPerTroyOunce = 31.1034768;
  static const double gramsPerSovereign = 8.0;

  final double spotUsdPerOunce;
  final double usdLkr;
  final DateTime? spotUpdatedAt;
  final DateTime? fxUpdatedAt;

  const GoldQuote({
    required this.spotUsdPerOunce,
    required this.usdLkr,
    this.spotUpdatedAt,
    this.fxUpdatedAt,
  });

  double get lkrPerGram24k => spotUsdPerOunce / gramsPerTroyOunce * usdLkr;
  double get lkrPerGram22k => lkrPerGram24k * 0.916;
  double get lkrPerSovereign24k => lkrPerGram24k * gramsPerSovereign;
  double get lkrPerSovereign22k => lkrPerGram22k * gramsPerSovereign;
}
