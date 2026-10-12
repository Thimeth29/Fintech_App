// lib/services/sandbox/gamification.dart
//
// Challenges and badges. XP amounts are fixed on the server (see the
// sandbox_trainer migration); this file only describes them. Nothing here
// rewards the *number* of trades — only learning and good habits.

import 'package:flutter/material.dart';

import '../../core/sandbox/sandbox_config.dart';

class ChallengeSpec {
  final String id;
  final SandboxModule module;
  final String title;
  final String description;
  final int target;
  final String? badgeId;

  const ChallengeSpec({
    required this.id,
    required this.module,
    required this.title,
    required this.description,
    this.target = 1,
    this.badgeId,
  });
}

const List<ChallengeSpec> kChallenges = [
  // CSE
  ChallengeSpec(id: 'cse_first_share', module: SandboxModule.cse, title: 'Buy your first share',
      description: 'Become a part-owner of a listed company.', badgeId: 'first_share'),
  ChallengeSpec(id: 'cse_three_sectors', module: SandboxModule.cse, title: 'Hold 3 sectors',
      description: 'Own shares in three different sectors at the same time.', target: 3, badgeId: 'diversified'),
  ChallengeSpec(id: 'cse_first_dividend', module: SandboxModule.cse, title: 'Earn your first dividend',
      description: 'Hold a dividend-paying share through its payout month.', badgeId: 'dividend_earner'),
  ChallengeSpec(id: 'cse_hold_year', module: SandboxModule.cse, title: 'Stay invested 1 sim-year',
      description: 'Keep a holding for 365 simulated days.', target: 365, badgeId: 'long_term'),
  ChallengeSpec(id: 'cse_no_panic', module: SandboxModule.cse, title: "Don't panic-sell during a 10% dip",
      description: 'Keep holding for 30 sim-days after a share falls 10% below what you paid.', badgeId: 'steady_hands'),
  // FD
  ChallengeSpec(id: 'fd_first', module: SandboxModule.fd, title: 'Open your first FD',
      description: 'Lock in a rate at any bank.', badgeId: 'first_fd'),
  ChallengeSpec(id: 'fd_ladder', module: SandboxModule.fd, title: 'Build a 3-FD ladder',
      description: 'Have three open FDs that mature on different dates.', target: 3, badgeId: 'ladder_builder'),
  ChallengeSpec(id: 'fd_compare_payout', module: SandboxModule.fd, title: 'Compare monthly vs maturity payout',
      description: 'Use the payout comparison before opening an FD.'),
  ChallengeSpec(id: 'fd_early_cost', module: SandboxModule.fd, title: 'See what an early withdrawal costs',
      description: 'Open the early-withdrawal quote on one of your FDs.'),
  // Gold
  ChallengeSpec(id: 'gold_first_gram', module: SandboxModule.gold, title: 'Buy 1 gram',
      description: 'Own at least one gram of gold.', badgeId: 'gold_starter'),
  ChallengeSpec(id: 'gold_spread', module: SandboxModule.gold, title: 'Discover the spread',
      description: 'Check what buying and instantly selling would cost you.', badgeId: 'spread_spotter'),
  ChallengeSpec(id: 'gold_jewel_vs_bullion', module: SandboxModule.gold, title: 'Compare jewellery vs bullion',
      description: 'Sell some bullion and some jewellery to see the difference.', target: 2),
  ChallengeSpec(id: 'gold_inflation', module: SandboxModule.gold, title: 'Hold gold through an inflation event',
      description: 'Own gold when an inflation headline hits.', badgeId: 'inflation_hedger'),
  // Trading
  ChallengeSpec(id: 'tr_stop_loss', module: SandboxModule.trading, title: 'Place a trade with a stop-loss',
      description: 'Decide your exit before you enter.', badgeId: 'stop_loss_pro'),
  ChallengeSpec(id: 'tr_risk10', module: SandboxModule.trading, title: 'Keep risk under 2% for 10 trades',
      description: 'Each trade has a stop-loss that risks at most 2% of your wallet.', target: 10, badgeId: 'risk_manager'),
  ChallengeSpec(id: 'tr_session_limit', module: SandboxModule.trading, title: 'Finish a session within your loss limit',
      description: 'Trade, then leave before hitting the daily loss limit.'),
  ChallengeSpec(id: 'tr_updown10', module: SandboxModule.trading, title: 'Play 10 Up-or-Down rounds and read the stats',
      description: 'See why fixed-payout bets lose in the long run.', target: 10, badgeId: 'house_edge'),
  // Government securities
  ChallengeSpec(id: 'gov_first_tbill', module: SandboxModule.govSecurities, title: 'Buy your first T-bill',
      description: 'Lend to the government for 3, 6 or 12 months.', badgeId: 'bill_buyer'),
  ChallengeSpec(id: 'gov_two_coupons', module: SandboxModule.govSecurities, title: 'Collect 2 coupons',
      description: 'Hold a T-bond through two coupon dates.', target: 2, badgeId: 'coupon_collector'),
  ChallengeSpec(id: 'gov_sell_after_rise', module: SandboxModule.govSecurities, title: 'Withdraw a bond early',
      description: 'Cash out a T-bond before maturity and see the coupons you give up.', badgeId: 'rate_watcher'),
  ChallengeSpec(id: 'gov_compare', module: SandboxModule.govSecurities, title: 'Compare a 1-year T-bill vs a 12-month FD',
      description: 'Use the comparison tool.'),
  // Foreign currency
  ChallengeSpec(id: 'fx_first', module: SandboxModule.forex, title: 'Buy your first foreign currency',
      description: 'Swap rupees for dollars, euros or another currency.', badgeId: 'fx_first'),
  ChallengeSpec(id: 'fx_spread', module: SandboxModule.forex, title: 'Spot the bank spread',
      description: 'Check what buying and instantly selling a currency would cost.'),
  ChallengeSpec(id: 'fx_two_currencies', module: SandboxModule.forex, title: 'Hold 2 currencies',
      description: 'Own two different foreign currencies at the same time.', target: 2),
  ChallengeSpec(id: 'fx_profit', module: SandboxModule.forex, title: 'Profit from a rupee move',
      description: 'Sell a currency for more rupees than you paid, after the spread.', badgeId: 'fx_trader'),
  // Community fund
  ChallengeSpec(id: 'cf_compare', module: SandboxModule.communityFund, title: 'Compare an early and a late turn',
      description: 'See why an early pot is like a loan and a late one like saving.'),
  ChallengeSpec(id: 'cf_join', module: SandboxModule.communityFund, title: 'Join a seettu',
      description: 'Commit to paying every round of a savings circle.', badgeId: 'seettu_member'),
  ChallengeSpec(id: 'cf_pot', module: SandboxModule.communityFund, title: 'Receive your pot',
      description: 'Stay in until your turn comes round.'),
  ChallengeSpec(id: 'cf_complete', module: SandboxModule.communityFund, title: 'Finish a whole seettu',
      description: 'Keep paying every round, even after your pot.', badgeId: 'seettu_finisher'),
];

List<ChallengeSpec> challengesFor(SandboxModule m) => kChallenges.where((c) => c.module == m).toList();

ChallengeSpec? challengeById(String id) {
  for (final c in kChallenges) {
    if (c.id == id) return c;
  }
  return null;
}

class BadgeSpec {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final SandboxModule? module;
  const BadgeSpec({required this.id, required this.title, required this.description, required this.icon, this.module});
}

const List<BadgeSpec> kBadges = [
  BadgeSpec(id: 'first_share', title: 'First Share', description: 'Bought your first CSE share.',
      icon: Icons.emoji_events_outlined, module: SandboxModule.cse),
  BadgeSpec(id: 'diversified', title: 'Diversified', description: 'Held three sectors at once.',
      icon: Icons.donut_large_rounded, module: SandboxModule.cse),
  BadgeSpec(id: 'dividend_earner', title: 'Dividend Earner', description: 'Got paid for owning shares.',
      icon: Icons.payments_outlined, module: SandboxModule.cse),
  BadgeSpec(id: 'long_term', title: 'Long-Term Thinker', description: 'Stayed invested for a sim-year.',
      icon: Icons.hourglass_bottom_rounded, module: SandboxModule.cse),
  BadgeSpec(id: 'steady_hands', title: 'Steady Hands', description: 'Didn\'t panic-sell in a dip.',
      icon: Icons.self_improvement_rounded, module: SandboxModule.cse),
  BadgeSpec(id: 'first_fd', title: 'Rate Locker', description: 'Opened your first FD.',
      icon: Icons.lock_clock_outlined, module: SandboxModule.fd),
  BadgeSpec(id: 'ladder_builder', title: 'Ladder Builder', description: 'Built a 3-FD ladder.',
      icon: Icons.stairs_outlined, module: SandboxModule.fd),
  BadgeSpec(id: 'gold_starter', title: 'Gold Starter', description: 'Owned your first gram of gold.',
      icon: Icons.monetization_on_outlined, module: SandboxModule.gold),
  BadgeSpec(id: 'spread_spotter', title: 'Spread Spotter', description: 'Found the hidden cost of gold.',
      icon: Icons.search_rounded, module: SandboxModule.gold),
  BadgeSpec(id: 'inflation_hedger', title: 'Inflation Hedger', description: 'Held gold through an inflation scare.',
      icon: Icons.shield_outlined, module: SandboxModule.gold),
  BadgeSpec(id: 'stop_loss_pro', title: 'Exit Planner', description: 'Traded with a stop-loss.',
      icon: Icons.front_hand_outlined, module: SandboxModule.trading),
  BadgeSpec(id: 'risk_manager', title: 'Risk Manager', description: 'Ten trades at 2% risk or less.',
      icon: Icons.health_and_safety_outlined, module: SandboxModule.trading),
  BadgeSpec(id: 'house_edge', title: 'House-Edge Detective', description: 'Saw why fixed-payout bets lose.',
      icon: Icons.casino_outlined, module: SandboxModule.trading),
  BadgeSpec(id: 'bill_buyer', title: 'Bill Buyer', description: 'Bought your first T-bill.',
      icon: Icons.receipt_long_outlined, module: SandboxModule.govSecurities),
  BadgeSpec(id: 'coupon_collector', title: 'Coupon Collector', description: 'Collected two bond coupons.',
      icon: Icons.local_activity_outlined, module: SandboxModule.govSecurities),
  BadgeSpec(id: 'rate_watcher', title: 'Rate Watcher', description: 'Saw what withdrawing a bond early gives up.',
      icon: Icons.trending_down_rounded, module: SandboxModule.govSecurities),
  BadgeSpec(id: 'fx_first', title: 'Currency Starter', description: 'Bought your first foreign currency.',
      icon: Icons.currency_exchange_rounded, module: SandboxModule.forex),
  BadgeSpec(id: 'fx_trader', title: 'Rupee Watcher', description: 'Made a profit after the spread.',
      icon: Icons.swap_vert_rounded, module: SandboxModule.forex),
  BadgeSpec(id: 'seettu_member', title: 'Circle Member', description: 'Joined your first seettu.',
      icon: Icons.groups_2_outlined, module: SandboxModule.communityFund),
  BadgeSpec(id: 'seettu_finisher', title: 'Promise Keeper', description: 'Paid every round of a seettu.',
      icon: Icons.handshake_outlined, module: SandboxModule.communityFund),
  BadgeSpec(id: 'scholar', title: 'Scholar', description: 'Passed every lesson in a module.',
      icon: Icons.school_outlined),
  BadgeSpec(id: 'on_fire', title: 'On a Roll', description: 'Learned something 7 days in a row.',
      icon: Icons.local_fire_department_outlined),
];

BadgeSpec? badgeById(String id) {
  for (final b in kBadges) {
    if (b.id == id) return b;
  }
  return null;
}
