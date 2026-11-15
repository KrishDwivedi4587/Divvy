import 'package:divvy/features/bills/domain/engine/settle.dart';
import 'package:divvy/features/bills/domain/models/bill.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';

void main() {
  group('golden case: the worked example', () {
    final goldenBill = bill(
      people: [
        person('aarav', 'Aarav'),
        person('priya', 'Priya'),
        person('zoya', 'Zoya'),
      ],
      items: [
        item('paneer', 'Paneer Tikka', 34000),
        item('dal', 'Dal Makhani', 28000),
        item('coffee', 'Cold Coffee', 15000),
        item('naan', 'Naan', 16000, quantity: 4),
      ],
      assignments: {
        'paneer': ['aarav', 'priya'],
        'dal': ['aarav', 'priya', 'zoya'],
        'coffee': ['zoya'],
        'naan': ['aarav', 'priya', 'zoya'],
      },
      adjustments: [
        adjustment(
          'service',
          label: 'Service Charge',
          kind: AdjustmentKind.service,
          mode: AdjustmentMode.percent,
          value: 500,
          order: 1,
        ),
        adjustment(
          'gst',
          label: 'GST',
          mode: AdjustmentMode.percent,
          value: 500,
          order: 2,
          base: AdjustmentBase.runningTotal,
        ),
      ],
    );

    final settlement = computeSettlement(goldenBill);
    final people = byId(settlement);

    test('items subtotal is 930.00', () {
      expect(settlement.itemsSubtotal, p(93000));
    });

    test('per-person subtotals match the worked example', () {
      expect(people['aarav']!.subtotal, p(31668));
      expect(people['priya']!.subtotal, p(31666));
      expect(people['zoya']!.subtotal, p(29666));
    });

    test('subtotals sum to the items subtotal exactly', () {
      final sum = settlement.perPerson.fold(0, (a, x) => a + x.subtotal.value);
      expect(sum, 93000);
    });

    test('service charge is 5% of items = 46.50, split 1584/1583/1483', () {
      final service = settlement.adjustmentTotals.firstWhere(
        (a) => a.adjustmentId == 'service',
      );
      expect(service.amount, p(4650));
      expect(people['aarav']!.adjustmentShares[0].share, p(1584));
      expect(people['priya']!.adjustmentShares[0].share, p(1583));
      expect(people['zoya']!.adjustmentShares[0].share, p(1483));
    });

    test('GST is 5% of (items + service) = 4882.5 rounded to 48.83', () {
      final gst = settlement.adjustmentTotals.firstWhere(
        (a) => a.adjustmentId == 'gst',
      );
      expect(gst.amount, p(4883));
      expect(people['aarav']!.adjustmentShares[1].share, p(1663));
      expect(people['priya']!.adjustmentShares[1].share, p(1663));
      expect(people['zoya']!.adjustmentShares[1].share, p(1557));
    });

    test('final per-person totals are 349.15 / 349.12 / 327.06', () {
      expect(people['aarav']!.total, p(34915));
      expect(people['priya']!.total, p(34912));
      expect(people['zoya']!.total, p(32706));
    });

    test('grand total is 1,025.33 and everyone sums to it exactly', () {
      expect(settlement.grandTotal, p(102533));
      expect(totalOf(settlement), 102533);
      expect(settlement.reconciles, isTrue);
    });

    test('nothing is unassigned', () {
      expect(settlement.unassignedItemIds, isEmpty);
      expect(settlement.unassignedAmount, p(0));
    });
  });

  group('adjustment ordering', () {
    final base = (
      people: [person('a'), person('b')],
      items: [item('i1', 'Item', 100000)],
      assignments: {
        'i1': ['a', 'b'],
      },
    );

    Adjustment service(int order) => adjustment(
      'service',
      label: 'Service',
      kind: AdjustmentKind.service,
      mode: AdjustmentMode.percent,
      value: 1000, // 10%
      order: order,
    );

    Adjustment gst(int order) => adjustment(
      'gst',
      label: 'GST',
      mode: AdjustmentMode.percent,
      value: 500, // 5%
      order: order,
      base: AdjustmentBase.runningTotal,
    );

    Bill make(List<Adjustment> adjustments) => bill(
      people: base.people,
      items: base.items,
      assignments: base.assignments,
      adjustments: adjustments,
    );

    test('service-then-GST differs from GST-then-service; both reconcile', () {
      final serviceFirst = computeSettlement(make([service(1), gst(2)]));
      final gstFirst = computeSettlement(make([gst(1), service(2)]));

      // Service first: GST is charged on 110000 -> 5500. Grand 115500.
      expect(serviceFirst.grandTotal, p(115500));
      // GST first: GST is charged on 100000 -> 5000. Grand 115000.
      expect(gstFirst.grandTotal, p(115000));

      expect(serviceFirst.grandTotal, isNot(gstFirst.grandTotal));
      expect(serviceFirst.reconciles, isTrue);
      expect(gstFirst.reconciles, isTrue);
    });

    test('percent mode and amount mode agree when the amounts match', () {
      final asPercent = computeSettlement(make([service(1)]));
      final asAmount = computeSettlement(
        make([
          adjustment(
            'service',
            label: 'Service',
            kind: AdjustmentKind.service,
            mode: AdjustmentMode.amount,
            value: 10000,
            order: 1,
          ),
        ]),
      );
      expect(asAmount.grandTotal, asPercent.grandTotal);
      expect(byId(asAmount)['a']!.total, byId(asPercent)['a']!.total);
    });

    test('applies adjustments in order, not array position', () {
      final shuffled = computeSettlement(make([gst(2), service(1)]));
      expect(shuffled.grandTotal, p(115500));
    });

    test('a zero-rate adjustment changes nothing', () {
      final zero = computeSettlement(
        make([
          adjustment(
            'service',
            mode: AdjustmentMode.percent,
            value: 0,
            order: 1,
          ),
        ]),
      );
      expect(zero.grandTotal, p(100000));
      expect(zero.reconciles, isTrue);
    });
  });
}
