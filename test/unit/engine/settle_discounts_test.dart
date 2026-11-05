import 'package:divvy/features/bills/domain/engine/settle.dart';
import 'package:divvy/features/bills/domain/models/bill.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';

Adjustment discount(int value, [AdjustmentMode mode = AdjustmentMode.percent]) {
  return adjustment(
    'disc',
    label: 'Discount',
    kind: AdjustmentKind.discount,
    mode: mode,
    value: value,
    order: 1,
    isNegative: true,
  );
}

Bill discountBill(Adjustment disc) => bill(
  people: [person('a'), person('b'), person('c')],
  items: [item('i1', 'Item', 30000)],
  assignments: {
    'i1': ['a', 'b', 'c'],
  },
  adjustments: [disc],
);

void main() {
  group('discounts', () {
    test('reduces the grand total and still reconciles', () {
      final s = computeSettlement(discountBill(discount(1000))); // 10%
      expect(s.adjustmentTotals[0].amount, p(-3000));
      expect(s.grandTotal, p(27000));
      expect(totalOf(s), 27000);
      expect(s.reconciles, isTrue);
    });

    test('reduces every person share', () {
      final s = computeSettlement(discountBill(discount(1000)));
      for (final person in s.perPerson) {
        expect(person.adjustmentShares[0].share.value, lessThan(0));
        expect(person.total.value, lessThan(person.subtotal.value));
      }
    });

    test('handles a 100% discount down to zero', () {
      final s = computeSettlement(discountBill(discount(10000)));
      expect(s.grandTotal, p(0));
      expect(totalOf(s), 0);
      expect(s.reconciles, isTrue);
    });

    test('handles a 0% discount', () {
      final s = computeSettlement(discountBill(discount(0)));
      expect(s.grandTotal, p(30000));
      expect(s.reconciles, isTrue);
    });

    test('reconciles a fixed-amount discount that does not divide evenly', () {
      final s = computeSettlement(
        discountBill(discount(1000, AdjustmentMode.amount)),
      );
      expect(s.adjustmentTotals[0].amount, p(-1000));
      expect(totalOf(s), 29000);
      expect(s.reconciles, isTrue);
    });

    test('regression: a discount driving a running base negative is safe', () {
      // Found by the property test at seed 110. A discount larger than a
      // person's subtotal pushes their running base below zero; the next
      // proportional adjustment then received a negative weight and threw.
      // Weights are clamped at zero, so that person simply receives none of
      // the later charge.
      final s = computeSettlement(
        bill(
          people: [person('rich'), person('poor')],
          items: [item('big', 'Big', 100000), item('tiny', 'Tiny', 100)],
          assignments: {
            'big': ['rich'],
            'tiny': ['poor'],
          },
          adjustments: [
            adjustment(
              'disc',
              label: 'Flat discount',
              kind: AdjustmentKind.discount,
              mode: AdjustmentMode.amount,
              value: 50000,
              order: 1,
              isNegative: true,
            ),
            adjustment(
              'gst',
              label: 'GST',
              mode: AdjustmentMode.percent,
              value: 1800,
              order: 2,
              base: AdjustmentBase.runningTotal,
            ),
          ],
        ),
      );
      expect(s.reconciles, isTrue);
      expect(totalOf(s), s.grandTotal.value - s.unassignedAmount.value);
    });

    test('combines a discount with a tax and still reconciles', () {
      final s = computeSettlement(
        bill(
          people: [person('a'), person('b')],
          items: [item('i1', 'Item', 99999)],
          assignments: {
            'i1': ['a', 'b'],
          },
          adjustments: [
            adjustment(
              'disc',
              label: 'Discount',
              kind: AdjustmentKind.discount,
              mode: AdjustmentMode.percent,
              value: 1234,
              order: 1,
              isNegative: true,
            ),
            adjustment(
              'gst',
              label: 'GST',
              mode: AdjustmentMode.percent,
              value: 1800,
              order: 2,
              base: AdjustmentBase.runningTotal,
            ),
          ],
        ),
      );
      expect(s.reconciles, isTrue);
      expect(totalOf(s), s.grandTotal.value);
    });
  });

  group('unassigned items', () {
    final s = computeSettlement(
      bill(
        people: [person('a'), person('b')],
        items: [
          item('assigned', 'Assigned', 20000),
          item('orphan', 'Orphan', 5000),
        ],
        assignments: {
          'assigned': ['a', 'b'],
          'orphan': [],
        },
      ),
    );

    test('counts unassigned items in the subtotal but in nobody subtotal', () {
      expect(s.itemsSubtotal, p(25000));
      expect(s.perPerson.fold(0, (a, x) => a + x.subtotal.value), 20000);
    });

    test('reports the unassigned amount and ids', () {
      expect(s.unassignedAmount, p(5000));
      expect(s.unassignedItemIds, ['orphan']);
    });

    test('reconciles against the grand total minus the unassigned amount', () {
      expect(totalOf(s), s.grandTotal.value - s.unassignedAmount.value);
      expect(s.reconciles, isTrue);
    });

    test('an item missing from the assignments map counts as unassigned', () {
      final missing = computeSettlement(
        bill(people: [person('a')], items: [item('i1', 'Item', 1000)]),
      );
      expect(missing.unassignedAmount, p(1000));
      expect(missing.reconciles, isTrue);
    });

    test('charges still apportion when every item is unassigned', () {
      final allOrphaned = computeSettlement(
        bill(
          people: [person('a'), person('b')],
          items: [item('i1', 'Item', 10000)],
          assignments: {'i1': []},
          adjustments: [
            adjustment(
              'gst',
              label: 'GST',
              mode: AdjustmentMode.percent,
              value: 500,
              order: 1,
            ),
          ],
        ),
      );
      // Nobody has a subtotal, so the charge splits equally rather than
      // vanishing.
      expect(allOrphaned.adjustmentTotals[0].amount, p(500));
      expect(totalOf(allOrphaned), 500);
      expect(allOrphaned.reconciles, isTrue);
    });
  });
}
