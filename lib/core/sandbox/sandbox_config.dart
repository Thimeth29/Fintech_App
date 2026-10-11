// lib/core/sandbox/sandbox_config.dart
//
// Every tunable number in the Investment Trainer lives here: starting
// balance, fees, taxes, fallback prices and the instrument catalogue.
// Real market data (CSE, gold, FD rates, T-bill yields) overrides the
// fallbacks when it can be fetched; see SandboxAnchorService.
//
// All money in the trainer is virtual. Nothing here is financial advice.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Each module's wallet starts with this much virtual money.
const double kSandboxStartingBalance = 100000;

/// Shown on every trainer screen.
const String kSandboxDisclaimer = 'Simulated: virtual money, not financial advice';

// ---------------------------------------------------------------------------
// Fees and taxes. Verified October 2026; review before each release.
// ---------------------------------------------------------------------------

/// CSE equity transaction cost per side for trades up to Rs 100 million:
/// brokerage 0.64% + CSE 0.084% + CDS 0.024% + SEC cess 0.072% + share
/// transaction levy 0.30% = 1.12%. Source: cse.lk "Transaction costs".
const double kCseFeeRate = 0.0112;

/// Advance income tax (withholding) on interest from banks and finance
/// companies, 10% from 1 April 2025 (Inland Revenue (Amendment) Act No. 2
/// of 2025). Residents earning under Rs 1.8m a year can file a
/// self-declaration to avoid it; the trainer always applies it.
const double kInterestWhtRate = 0.10;

/// The same 10% advance income tax applied to T-bill discount income and
/// T-bond coupons in the trainer. Review if the treasury treatment differs.
const double kGovSecWhtRate = 0.10;

/// Withholding tax on CSE dividends (15%).
const double kDividendWhtRate = 0.15;

/// Gold: total buy/sell spread around the mid price (buy at mid +1.5%,
/// sell at mid −1.5%). Typical for Colombo dealers; not an official rate.
const double kGoldSpread = 0.03;

/// Jewellery making charge as a share of the gold value, paid on purchase
/// and not refunded on sale.
const double kJewelleryMakingCharge = 0.12;

/// 22K jewellery is 91.6% pure.
const double kGold22kPurity = 0.916;
const double kGramsPerSovereign = 8;

/// Short-term trading: per-trade fee of 0.2%, minimum Rs 25.
const double kTradingFeeRate = 0.002;
const double kTradingMinFee = 25;

/// Banks pay a slightly lower rate when interest is paid monthly.
const double kFdMonthlyRateDiscount = 0.5; // percentage points

/// Breaking an FD early: interest is recalculated at this savings-style
/// rate for full months held, and interest already paid is clawed back.
const double kFdEarlyWithdrawalRate = 3.0; // % p.a.

/// Assumed inflation for "compare with inflation" (% p.a.).
const double kAssumedInflation = 5.0;

// ---------------------------------------------------------------------------
// Short-term trading safety rules
// ---------------------------------------------------------------------------
const double kDailyLossLimitShare = 0.20; // of the wallet at session start
const Duration kTakeABreakAfter = Duration(minutes: 30);
const double kMaxRiskPerTrade = 0.02; // 2% of equity
const int kShortSellingLevel = 5;

/// Up-or-Down pays this multiple of the stake on a win. Less than 2x on a
/// 50/50 guess, so the expected value is negative — on purpose.
const double kUpDownPayout = 1.8;
const int kUpDownStatsRounds = 10;

// ---------------------------------------------------------------------------
// Levels: XP thresholds must match _sandbox_level_for_xp() in the migration.
// ---------------------------------------------------------------------------
const List<int> kSandboxLevelThresholds = [0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200];
const List<String> kSandboxLevelTitles = [
  'Beginner Saver',
  'Curious Learner',
  'Budget Builder',
  'Steady Saver',
  'Market Explorer',
  'Risk Aware',
  'Portfolio Planner',
  'Disciplined Investor',
  'Wise Allocator',
  'Smart Investor',
];

const int kQuizPassPercent = 70;

// ---------------------------------------------------------------------------
// Modules
// ---------------------------------------------------------------------------
enum SandboxModule { cse, fd, gold, trading, govSecurities }

extension SandboxModuleInfo on SandboxModule {
  /// Value stored in the database `module` column.
  String get id => switch (this) {
        SandboxModule.cse => 'cse',
        SandboxModule.fd => 'fd',
        SandboxModule.gold => 'gold',
        SandboxModule.trading => 'trading',
        SandboxModule.govSecurities => 'gov_securities',
      };

  String get title => switch (this) {
        SandboxModule.cse => 'CSE Stock Investing',
        SandboxModule.fd => 'Fixed Deposits',
        SandboxModule.gold => 'Gold Investing',
        SandboxModule.trading => 'Short-term Trading',
        SandboxModule.govSecurities => 'Government Securities',
      };

  String get shortTitle => switch (this) {
        SandboxModule.cse => 'CSE stocks',
        SandboxModule.fd => 'Fixed deposits',
        SandboxModule.gold => 'Gold',
        SandboxModule.trading => 'Trading',
        SandboxModule.govSecurities => 'T-Bills & Bonds',
      };

  String get tagline => switch (this) {
        SandboxModule.cse => 'Own a slice of Sri Lankan companies',
        SandboxModule.fd => 'Lock in a rate and watch interest grow',
        SandboxModule.gold => 'A store of value, with a spread',
        SandboxModule.trading => 'Fast, exciting — and why it\'s risky',
        SandboxModule.govSecurities => 'Lend to the government',
      };

  IconData get icon => switch (this) {
        SandboxModule.cse => Icons.show_chart_rounded,
        SandboxModule.fd => Icons.savings_outlined,
        SandboxModule.gold => Icons.monetization_on_outlined,
        SandboxModule.trading => Icons.candlestick_chart_outlined,
        SandboxModule.govSecurities => Icons.account_balance_outlined,
      };

  Color get color => switch (this) {
        SandboxModule.cse => AppColors.primary,
        SandboxModule.fd => AppColors.accentCyan,
        SandboxModule.gold => AppColors.gold,
        SandboxModule.trading => AppColors.accentTeal,
        SandboxModule.govSecurities => AppColors.accentLavender,
      };

  /// Trading runs in real time; every other module has a fast-forward clock.
  bool get hasSimClock => this != SandboxModule.trading;

  static SandboxModule? parse(String? id) {
    for (final m in SandboxModule.values) {
      if (m.id == id) return m;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Instrument types: stored lowercase, shown with friendly labels.
// ---------------------------------------------------------------------------
String instrumentTypeLabel(String type) => switch (type.toLowerCase()) {
      'stock' => 'CSE share',
      'gold' => 'Gold',
      'fixed_deposit' || 'fd' => 'Fixed Deposit',
      'treasury_bill' || 'tbill' => 'Treasury Bill',
      'treasury_bond' || 'tbond' => 'Treasury Bond',
      'trading' => 'Trading instrument',
      'cash' => 'Cash',
      _ => type.replaceAll('_', ' '),
    };

IconData instrumentTypeIcon(String type) => switch (type.toLowerCase()) {
      'stock' => Icons.show_chart_rounded,
      'gold' => Icons.monetization_on_outlined,
      'fixed_deposit' || 'fd' => Icons.savings_outlined,
      'treasury_bill' || 'tbill' || 'treasury_bond' || 'tbond' => Icons.account_balance_outlined,
      'trading' => Icons.candlestick_chart_outlined,
      _ => Icons.savings_outlined,
    };

/// One tradable thing in the simulator.
class InstrumentSpec {
  final String symbol;
  final String name;
  final SandboxModule module;
  final String type; // 'stock' | 'gold' | 'trading'
  final String sector;
  final double fallbackPrice;

  /// Annualised drift and volatility of the simulated random walk.
  final double drift;
  final double volatility;

  /// Annual dividend yield (CSE only), paid in [dividendMonths].
  final double dividendYield;
  final List<int> dividendMonths;
  final bool fictional;
  final String unit; // 'share', 'g', 'unit'

  const InstrumentSpec({
    required this.symbol,
    required this.name,
    required this.module,
    required this.type,
    required this.sector,
    required this.fallbackPrice,
    required this.drift,
    required this.volatility,
    this.dividendYield = 0,
    this.dividendMonths = const [],
    this.fictional = false,
    this.unit = 'share',
  });
}

/// Well-known CSE companies across sectors. Fallback prices are rough
/// reference levels used only when live CSE data can't be fetched.
const List<InstrumentSpec> kCseInstruments = [
  InstrumentSpec(symbol: 'JKH.N', name: 'John Keells Holdings', module: SandboxModule.cse, type: 'stock',
      sector: 'Diversified', fallbackPrice: 145.50, drift: 0.09, volatility: 0.28,
      dividendYield: 0.025, dividendMonths: [6, 12]),
  InstrumentSpec(symbol: 'COMB.N', name: 'Commercial Bank', module: SandboxModule.cse, type: 'stock',
      sector: 'Banking', fallbackPrice: 98.20, drift: 0.10, volatility: 0.26,
      dividendYield: 0.06, dividendMonths: [4, 11]),
  InstrumentSpec(symbol: 'HNB.N', name: 'Hatton National Bank', module: SandboxModule.cse, type: 'stock',
      sector: 'Banking', fallbackPrice: 330.00, drift: 0.10, volatility: 0.27,
      dividendYield: 0.055, dividendMonths: [3, 9]),
  InstrumentSpec(symbol: 'DIAL.N', name: 'Dialog Axiata', module: SandboxModule.cse, type: 'stock',
      sector: 'Telecom', fallbackPrice: 13.50, drift: 0.07, volatility: 0.24,
      dividendYield: 0.07, dividendMonths: [5]),
  InstrumentSpec(symbol: 'CTC.N', name: 'Ceylon Tobacco', module: SandboxModule.cse, type: 'stock',
      sector: 'Consumer', fallbackPrice: 1350.00, drift: 0.06, volatility: 0.18,
      dividendYield: 0.08, dividendMonths: [3, 8, 11]),
  InstrumentSpec(symbol: 'CARG.N', name: 'Cargills (Ceylon)', module: SandboxModule.cse, type: 'stock',
      sector: 'Retail', fallbackPrice: 380.00, drift: 0.08, volatility: 0.22,
      dividendYield: 0.03, dividendMonths: [7]),
  InstrumentSpec(symbol: 'HAYL.N', name: 'Hayleys', module: SandboxModule.cse, type: 'stock',
      sector: 'Diversified', fallbackPrice: 110.00, drift: 0.09, volatility: 0.30,
      dividendYield: 0.03, dividendMonths: [6]),
  InstrumentSpec(symbol: 'TKYO.N', name: 'Tokyo Cement', module: SandboxModule.cse, type: 'stock',
      sector: 'Manufacturing', fallbackPrice: 70.00, drift: 0.08, volatility: 0.32,
      dividendYield: 0.035, dividendMonths: [10]),
  InstrumentSpec(symbol: 'LIOC.N', name: 'Lanka IOC', module: SandboxModule.cse, type: 'stock',
      sector: 'Energy', fallbackPrice: 150.00, drift: 0.07, volatility: 0.34,
      dividendYield: 0.05, dividendMonths: [8]),
  InstrumentSpec(symbol: 'AEL.N', name: 'Access Engineering', module: SandboxModule.cse, type: 'stock',
      sector: 'Construction', fallbackPrice: 30.00, drift: 0.08, volatility: 0.36,
      dividendYield: 0.04, dividendMonths: [9]),
];

/// Gold priced per gram of 24K. Bullion and jewellery share the price;
/// jewellery is 22K and carries a making charge.
const InstrumentSpec kGoldBullion = InstrumentSpec(
    symbol: 'GOLD24.BULLION', name: '24K gold bullion', module: SandboxModule.gold, type: 'gold',
    sector: 'Gold', fallbackPrice: 24800, drift: 0.06, volatility: 0.15, unit: 'g');
const InstrumentSpec kGoldJewellery = InstrumentSpec(
    symbol: 'GOLD22.JEWEL', name: '22K gold jewellery', module: SandboxModule.gold, type: 'gold',
    sector: 'Gold', fallbackPrice: 24800, drift: 0.06, volatility: 0.15, unit: 'g');
const List<InstrumentSpec> kGoldInstruments = [kGoldBullion, kGoldJewellery];

/// Clearly fictional, high-volatility instruments for the trading module.
const List<InstrumentSpec> kTradingInstruments = [
  InstrumentSpec(symbol: 'ZEPH', name: 'Zephyr Tech (fictional)', module: SandboxModule.trading, type: 'trading',
      sector: 'Fictional', fallbackPrice: 250, drift: 0.0, volatility: 0.9, fictional: true, unit: 'unit'),
  InstrumentSpec(symbol: 'KOLA', name: 'Kola Foods (fictional)', module: SandboxModule.trading, type: 'trading',
      sector: 'Fictional', fallbackPrice: 80, drift: 0.0, volatility: 0.7, fictional: true, unit: 'unit'),
  InstrumentSpec(symbol: 'MOON', name: 'MoonCoin (fictional)', module: SandboxModule.trading, type: 'trading',
      sector: 'Fictional', fallbackPrice: 12, drift: 0.0, volatility: 1.4, fictional: true, unit: 'unit'),
  InstrumentSpec(symbol: 'TIDE', name: 'Tide Shipping (fictional)', module: SandboxModule.trading, type: 'trading',
      sector: 'Fictional', fallbackPrice: 540, drift: 0.0, volatility: 0.8, fictional: true, unit: 'unit'),
];

InstrumentSpec? instrumentBySymbol(String symbol) {
  for (final list in [kCseInstruments, kGoldInstruments, kTradingInstruments]) {
    for (final i in list) {
      if (i.symbol == symbol) return i;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Fixed income fallbacks (% p.a.). Live values come from fd_rates and
// gov_security_yields.
// ---------------------------------------------------------------------------
const List<int> kFdTenures = [1, 3, 6, 12, 24];

/// Banks offered in the FD simulator, with fallback maturity rates by tenure.
const Map<String, Map<int, double>> kFdFallbackRates = {
  'Bank of Ceylon': {1: 6.00, 3: 6.75, 6: 7.00, 12: 7.25, 24: 7.50},
  "People's Bank": {1: 6.25, 3: 7.00, 6: 7.50, 12: 8.50, 24: 8.75},
  'Commercial Bank': {1: 7.00, 3: 8.00, 6: 9.00, 12: 10.00, 24: 10.25},
  'Seylan Bank': {1: 7.00, 3: 8.25, 6: 9.25, 12: 10.00, 24: 10.25},
  'National Savings Bank': {1: 6.50, 3: 7.25, 6: 7.75, 12: 8.25, 24: 8.50},
  'Central Finance': {1: 8.00, 3: 9.50, 6: 10.50, 12: 11.50, 24: 11.75},
};

const List<int> kTbillTenures = [91, 182, 364];
const Map<int, double> kTbillFallbackYields = {91: 7.90, 182: 8.10, 364: 8.65};

/// T-bond tenures (years) and fallback market yields / coupon rates.
const List<int> kTbondTenureYears = [2, 5, 10];
const Map<int, double> kTbondFallbackYields = {2: 9.25, 5: 10.00, 10: 10.75};

/// Anchor keys for yields in a wallet's price_anchors.
String tbillAnchorKey(int days) => 'TBILL_$days';
String tbondAnchorKey(int years) => 'TBOND_${years}Y';
