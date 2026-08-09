/// Category of a sandbox instrument. Each category is handled by a
/// different rule set inside [SandboxEngine]:
/// - [tradable]  : freely bought/sold at a live (simulated) price — gold, forex, stocks
/// - [term]      : locked for a fixed term at a fixed rate — fixed deposits, treasury bonds
/// - [community] : pooled rotating-fund simulation — seettu/cheetu style community investing
enum InstrumentCategory { tradable, term, community }

enum RiskLevel { low, medium, high }

class Instrument {
  final String id;
  final String name;
  final String issuer; // e.g. "NSB", "CBSL", "Colombo Stock Exchange"
  final InstrumentCategory category;
  final RiskLevel risk;
  final String unitLabel; // e.g. "per gram", "per share", "per unit"
  final String description;

  /// Starting price used to seed the price simulator (LKR).
  final double basePrice;

  /// Daily volatility used by the price simulator, expressed as a
  /// fraction (e.g. 0.02 == price can drift ~2% per tick).
  final double volatility;

  /// Only relevant for [InstrumentCategory.term] instruments.
  final int? termDays;
  final double? annualRatePct;

  /// Only relevant for [InstrumentCategory.community] instruments.
  final int? totalRounds;
  final double? roundContribution;

  const Instrument({
    required this.id,
    required this.name,
    required this.issuer,
    required this.category,
    required this.risk,
    required this.unitLabel,
    required this.description,
    required this.basePrice,
    required this.volatility,
    this.termDays,
    this.annualRatePct,
    this.totalRounds,
    this.roundContribution,
  });
}
