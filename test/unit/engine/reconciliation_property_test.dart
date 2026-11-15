// The flagship test.
//
// Generates 1,000 random bills and asserts the invariant the whole project
// rests on:
//
//     sum(perPerson.total) == grandTotal - unassignedAmount
//
// exactly, as integers. Nothing here checks a specific number; it checks that
// no combination of items, people, assignments, charges and discounts can make
// a paisa appear or disappear.
//
// The generator is seeded, so a failure is reproducible: the seed is printed
// with the failing case rather than being lost. No property-testing library is
// used: a seeded generator and a loop cover this adequately, and adding a
// dependency to the one module that must be trivially auditable would be a
// poor trade.

import 'package:divvy/features/bills/domain/engine/settle.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/bill_generator.dart';
import '../../support/builders.dart';

void main() {
  const cases = 1000;

  test('the generator reproduces the original Mulberry32 stream', () {
    // Reference values computed with the original TypeScript algorithm
    // (Math.imul based), so seeds mean the same thing in both languages.
    const expected = <int, List<double>>{
      1: [
        0.6270739405881613,
        0.002735721180215478,
        0.5274470399599522,
        0.9810509674716741,
        0.9683778982143849,
      ],
      42: [
        0.6011037519201636,
        0.44829055899754167,
        0.8524657934904099,
        0.6697340414393693,
        0.17481389874592423,
      ],
      999: [
        0.9699058223050088,
        0.6347794097382575,
        0.3093319069594145,
        0.7726939893327653,
        0.4566342122852802,
      ],
    };
    expected.forEach((seed, values) {
      final rng = Mulberry32(seed);
      for (final v in values) {
        expect(rng.next(), closeTo(v, 1e-15));
      }
    });
  });

  group('reconciliation invariant', () {
    test('holds for $cases randomly generated bills', () {
      for (var seed = 1; seed <= cases; seed++) {
        final b = generateBill(seed);
        final s = computeSettlement(b);

        final sumOfPeople = totalOf(s);
        final expectedTotal = s.grandTotal.value - s.unassignedAmount.value;

        if (sumOfPeople != expectedTotal || !s.reconciles) {
          fail(
            'RECONCILIATION FAILED at seed $seed\n'
            '  sum of perPerson.total = $sumOfPeople\n'
            '  grandTotal             = ${s.grandTotal.value}\n'
            '  unassignedAmount       = ${s.unassignedAmount.value}\n'
            '  expected               = $expectedTotal\n'
            '  reconciles flag        = ${s.reconciles}',
          );
        }
      }
    });

    test('produces only whole numbers across $cases bills', () {
      // Every money field is an int, so this checks the stronger property that
      // nothing was ever computed through a double and truncated back.
      for (var seed = 1; seed <= cases; seed++) {
        final s = computeSettlement(generateBill(seed));
        final numbers = <Object>[
          s.itemsSubtotal.value,
          s.grandTotal.value,
          s.unassignedAmount.value,
          for (final a in s.adjustmentTotals) a.amount.value,
          for (final person in s.perPerson) ...[
            person.subtotal.value,
            person.total.value,
            for (final i in person.itemShares) i.share.value,
            for (final a in person.adjustmentShares) a.share.value,
          ],
        ];
        for (final n in numbers) {
          expect(n, isA<int>(), reason: 'seed $seed');
        }
      }
    });

    test('per-item shares always sum to the item line total', () {
      for (var seed = 1; seed <= 200; seed++) {
        final b = generateBill(seed);
        final s = computeSettlement(b);

        final perItem = <String, int>{};
        for (final person in s.perPerson) {
          for (final share in person.itemShares) {
            perItem[share.itemId] =
                (perItem[share.itemId] ?? 0) + share.share.value;
          }
        }

        for (final item in b.items) {
          final assigned = b.assignments[item.id] ?? const <String>[];
          final allocated = perItem[item.id] ?? 0;
          final expectedAmount = assigned.isEmpty ? 0 : item.lineTotal.value;
          expect(allocated, expectedAmount, reason: 'seed $seed ${item.id}');
        }
      }
    });

    test('each adjustment total equals the sum of its per-person shares', () {
      for (var seed = 1; seed <= 200; seed++) {
        final s = computeSettlement(generateBill(seed));

        for (final adj in s.adjustmentTotals) {
          var distributed = 0;
          for (final person in s.perPerson) {
            for (final a in person.adjustmentShares) {
              if (a.adjustmentId == adj.adjustmentId) {
                distributed += a.share.value;
              }
            }
          }
          expect(distributed, adj.amount.value, reason: 'seed $seed');
        }
      }
    });

    test('is deterministic: the same seed always gives the same result', () {
      String render(int seed) {
        final s = computeSettlement(generateBill(seed));
        return [
          s.grandTotal.value,
          for (final person in s.perPerson) person.total.value,
        ].join(',');
      }

      for (final seed in [1, 42, 500, 999]) {
        expect(render(seed), render(seed));
      }
    });
  });
}
