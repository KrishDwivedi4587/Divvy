import 'package:divvy/core/errors/domain_error.dart';
import 'package:divvy/features/bills/domain/engine/apportion.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';
import '../../support/fuzz.dart';

int total(List<Share> shares) => shares.fold(0, (a, s) => a + s.share.value);

List<Weighted> w(List<int> weights) => [
  for (var i = 0; i < weights.length; i++) Weighted('p$i', weights[i]),
];

List<int> values(List<Share> shares) =>
    shares.map((s) => s.share.value).toList();

void main() {
  group('apportion', () {
    test('splits equally when weights are equal', () {
      expect(values(apportion(p(300), w([100, 100, 100]))), [100, 100, 100]);
    });

    test('gives equal weights shares within one paisa of each other', () {
      final shares = apportion(p(100), w([50, 50, 50]));
      final v = values(shares)..sort();
      expect(v.last - v.first, lessThanOrEqualTo(1));
      expect(total(shares), 100);
    });

    test('distributes proportionally to weight', () {
      expect(values(apportion(p(1000), w([750, 250]))), [750, 250]);
    });

    test('gives a zero-weight person nothing', () {
      final shares = apportion(p(1000), w([1000, 0]));
      expect(shares[1].share, p(0));
      expect(total(shares), 1000);
    });

    test('falls back to an equal split when every weight is zero', () {
      final shares = apportion(p(100), w([0, 0, 0, 0]));
      expect(total(shares), 100);
      expect(values(shares), [25, 25, 25, 25]);
    });

    test('still reconciles when a zero-weight fallback does not divide', () {
      expect(total(apportion(p(10), w([0, 0, 0]))), 10);
    });

    test('returns an empty list when there are no entries', () {
      expect(apportion(p(100), const []), isEmpty);
    });

    test('handles a zero amount', () {
      expect(total(apportion(p(0), w([100, 200]))), 0);
    });

    test('preserves the caller ordering, not the ranked ordering', () {
      final shares = apportion(p(100), const [
        Weighted('zoya', 10),
        Weighted('aarav', 90),
      ]);
      expect(shares.map((s) => s.id).toList(), ['zoya', 'aarav']);
    });

    test('breaks remainder ties by id ascending, deterministically', () {
      // Three equal weights, one leftover paisa: the lowest id must take it.
      final shares = apportion(p(10), const [
        Weighted('c', 1),
        Weighted('a', 1),
        Weighted('b', 1),
      ]);
      final byId = {for (final s in shares) s.id: s.share.value};
      expect(byId['a'], 4);
      expect(byId['b'], 3);
      expect(byId['c'], 3);
      expect(total(shares), 10);
    });

    test('is stable across 100 identical runs', () {
      final entries = w([31668, 31666, 29666]);
      final first = apportion(p(4650), entries).toString();
      for (var i = 0; i < 100; i++) {
        expect(apportion(p(4650), entries).toString(), first);
      }
    });

    test('reproduces the worked example, service charge step', () {
      final shares = apportion(p(4650), const [
        Weighted('aarav', 31668),
        Weighted('priya', 31666),
        Weighted('zoya', 29666),
      ]);
      expect(values(shares), [1584, 1583, 1483]);
      expect(total(shares), 4650);
    });

    test('reproduces the worked example, GST step', () {
      final shares = apportion(p(4883), const [
        Weighted('aarav', 33252),
        Weighted('priya', 33249),
        Weighted('zoya', 31149),
      ]);
      expect(values(shares), [1663, 1663, 1557]);
      expect(total(shares), 4883);
    });

    test('rejects a negative amount', () {
      expect(() => apportion(p(-100), w([1, 1])), throwsA(isA<DomainError>()));
    });

    test('rejects a negative weight', () {
      expect(() => apportion(p(100), w([1, -1])), throwsA(isA<DomainError>()));
    });

    group('fuzz: shares always sum to the amount exactly', () {
      test('holds for 10,000 random (amount, weights) pairs', () {
        fuzz((rnd) {
          for (var i = 0; i < 10000; i++) {
            final n = 1 + rnd.nextInt(8);
            final entries = [
              for (var j = 0; j < n; j++) Weighted('p$j', rnd.nextInt(100000)),
            ];
            final amount = p(rnd.nextInt(1000000));
            expect(total(apportion(amount, entries)), amount.value);
          }
        });
      });
    });
  });

  group('apportionSigned: the D7 negative-amount trap', () {
    test('apportions a NEGATIVE amount to exactly the negative total', () {
      // The trap: floor division of a negative number rounds away from zero.
      // Apportioning a negative amount directly would overshoot and break
      // reconciliation. The magnitude must be apportioned, then negated.
      final shares = apportionSigned(p(4650), w([31668, 31666, 29666]), true);
      expect(total(shares), -4650);
      expect(shares.every((s) => s.share.value <= 0), isTrue);
    });

    test('is the exact mirror of the positive case', () {
      final entries = w([1000, 3000, 7]);
      final positive = apportion(p(12345), entries);
      final negative = apportionSigned(p(12345), entries, true);
      expect(values(negative), values(positive).map((v) => -v).toList());
    });

    test('leaves a non-negative adjustment untouched', () {
      final entries = w([100, 200]);
      expect(
        apportionSigned(p(300), entries, false),
        apportion(p(300), entries),
      );
    });

    test('sums to exactly -A across 5,000 random discounts', () {
      fuzz((rnd) {
        for (var i = 0; i < 5000; i++) {
          final n = 1 + rnd.nextInt(6);
          final entries = [
            for (var j = 0; j < n; j++) Weighted('p$j', rnd.nextInt(50000)),
          ];
          final amount = p(rnd.nextInt(200000));
          expect(total(apportionSigned(amount, entries, true)), -amount.value);
        }
      });
    });

    test('regression: a zero-amount discount sums to zero (deterministic)', () {
      // The fuzz test above only reaches amount = 0 by chance; pin it. In the
      // TypeScript original this case produced a negative zero that made a
      // strict-equality assertion fail in about 2.5% of runs.
      final shares = apportionSigned(p(0), w([1, 2, 3]), true);
      expect(total(shares), 0);
      expect(shares.every((s) => s.share.value <= 0), isTrue);
    });
  });
}
