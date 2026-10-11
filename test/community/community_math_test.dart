import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/community/community_math.dart';
import 'package:my_app/models/community_models.dart';

// The same cases as supabase/tests/community_rls_test.sql, so the Dart and
// SQL versions stay in step.
void main() {
  group('splitAmount', () {
    test('equal split gives the extra cent to the first', () {
      expect(splitAmount(100, [1, 1, 1]), [33.34, 33.33, 33.33]);
    });
    test('pro-rata', () {
      expect(splitAmount(1000, [50000, 30000, 20000]), [500, 300, 200]);
    });
    test('parts always add up exactly', () {
      for (final total in [0.01, 1.0, 99.99, 1000.01, 123456.78]) {
        for (final n in [1, 2, 3, 7, 13]) {
          final parts = splitAmount(total, List.filled(n, 1));
          final sumCents = parts.fold<int>(0, (a, p) => a + (p * 100).round());
          expect(sumCents, (total * 100).round(), reason: 'total $total, n $n');
        }
      }
    });
    test('uneven weights still add up', () {
      final parts = splitAmount(1000.01, [60000, 20000]);
      expect(parts, [750.01, 250.0]);
    });
    test('all-zero weights split equally', () {
      expect(splitAmount(10, [0, 0]), [5, 5]);
    });
    test('rejects negative weights', () {
      expect(() => splitAmount(10, [1, -1]), throwsArgumentError);
    });
  });

  group('seettu', () {
    // 13 Oct 2026 is a Tuesday.
    final start = DateTime(2026, 10, 13);
    test('weekly round 1 is the next chosen weekday', () {
      expect(seettuDueDate(start, 'weekly', 5, 1), DateTime(2026, 10, 16));
    });
    test('weekly due day equal to start day starts that day', () {
      expect(seettuDueDate(start, 'weekly', 2, 1), DateTime(2026, 10, 13));
      expect(seettuDueDate(start, 'weekly', 2, 3), DateTime(2026, 10, 27));
    });
    test('monthly rolls to next month when the day has passed', () {
      expect(seettuDueDate(start, 'monthly', 5, 1), DateTime(2026, 11, 5));
      expect(seettuDueDate(start, 'monthly', 28, 5), DateTime(2027, 2, 28));
    });
    test('rounds are 1-based', () {
      expect(() => seettuDueDate(start, 'weekly', 1, 0), throwsArgumentError);
    });
    test('pot and bidding discount', () {
      expect(seettuPot(5000, 10), 50000);
      expect(seettuPot(5000, 10, discount: 4500), 45500);
      final credits = seettuBidCredits(4500, 9);
      expect(credits.every((c) => c == 500), isTrue);
      // Others pay contribution − credit, the winner pays in full: the
      // total collected equals the reduced pot.
      final collected = 5000 + credits.fold<double>(0, (a, c) => a + (5000 - c));
      expect(collected, seettuPot(5000, 10, discount: 4500));
    });
    test('uneven bid credits still add up to the discount', () {
      final credits = seettuBidCredits(1000, 3);
      expect(credits, [333.34, 333.33, 333.33]);
    });
  });

  group('votePasses', () {
    bool pass(double yes, double no, int ballots, int eligible, double weight, String threshold, String base) =>
        votePasses(
          yes: yes,
          no: no,
          ballots: ballots,
          eligibleCount: eligible,
          eligibleWeight: weight,
          quorumPct: 50,
          threshold: threshold,
          base: base,
        );

    test('simple majority of votes cast', () => expect(pass(3, 2, 5, 8, 8, 'majority', 'cast'), isTrue));
    test('ties fail', () => expect(pass(2, 2, 4, 8, 8, 'majority', 'cast'), isFalse));
    test('below quorum fails', () => expect(pass(3, 0, 3, 8, 8, 'majority', 'cast'), isFalse));
    test('exactly two thirds passes', () => expect(pass(2, 1, 3, 3, 3, 'two_thirds', 'cast'), isTrue));
    test('60% fails two thirds', () => expect(pass(3, 2, 5, 5, 5, 'two_thirds', 'cast'), isFalse));
    test('leader change needs 2/3 of all members', () {
      expect(pass(4, 0, 4, 9, 9, 'two_thirds', 'eligible'), isFalse);
      expect(pass(6, 1, 7, 9, 9, 'two_thirds', 'eligible'), isTrue);
    });
    test('contribution-weighted: one big contributor outweighs two small ones', () {
      expect(pass(60000, 20000, 3, 3, 80000, 'majority', 'cast'), isTrue);
      expect(pass(20000, 60000, 3, 3, 80000, 'majority', 'cast'), isFalse);
    });
  });

  group('exitPayout', () {
    test('contribution back', () {
      expect(
          exitPayout(method: 'contribution_back', contribution: 50000, share: 0.5, poolValue: 120000, penaltyPct: 10, inLockIn: false),
          50000);
    });
    test('share of value', () {
      expect(
          exitPayout(method: 'share_of_value', contribution: 50000, share: 0.5, poolValue: 120000, penaltyPct: 10, inLockIn: false),
          60000);
    });
    test('lock-in penalty', () {
      expect(
          exitPayout(method: 'share_of_value', contribution: 50000, share: 0.5, poolValue: 120000, penaltyPct: 10, inLockIn: true),
          54000);
    });
  });

  group('content safety', () {
    test('blocks card numbers', () => expect(hasPaymentDetails('pay to 1234 5678 9012 3456'), isTrue));
    test('blocks account numbers next to keywords', () => expect(hasPaymentDetails('my account no 8001234567'), isTrue));
    test('allows mobile numbers', () => expect(hasPaymentDetails('call me on 0771234567'), isFalse));
    test('allows amounts and dates', () => expect(hasPaymentDetails('round 3 is Rs 25,000 on 2026-11-05'), isFalse));
  });

  test('contribution buckets match the server', () {
    expect(contributionBucket(9999), 0);
    expect(contributionBucket(10000), 1);
    expect(contributionBucket(75000), 2);
    expect(contributionBucket(500000), 5);
    expect(kContributionBuckets[contributionBucket(75000)!], 'Rs 50k–100k');
  });
}
