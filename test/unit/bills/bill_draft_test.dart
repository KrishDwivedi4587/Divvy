import 'package:divvy/core/utils/currency.dart';
import 'package:divvy/features/bills/domain/bill_draft.dart';
import 'package:divvy/features/bills/domain/engine/money.dart';
import 'package:divvy/features/bills/domain/models/bill.dart';
import 'package:divvy/features/bills/domain/models/bill_record.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';
import '../../support/draft_builders.dart';

Map<String, int> totals(BillDraft d) => {
  for (final x in d.settle(now)!.perPerson) x.personId: x.total.value,
};

void main() {
  group('by item', () {
    test('reproduces the worked example with the receipt amounts', () {
      final d = goldenDraft();
      expect(totals(d), {'aarav': 34915, 'priya': 34912, 'zoya': 32706});
      expect(d.settle(now)!.grandTotal, p(102533));
      expect(d.settle(now)!.reconciles, isTrue);
    });

    test('a bill that matches its receipt total has no mismatch', () {
      expect(goldenDraft().totalMismatch(now), isNull);
    });

    test('flags a receipt total that does not match', () {
      final d = goldenDraft().copyWith(statedTotal: const Paise(110000));
      expect(d.totalMismatch(now), p(110000 - 102533));
    });

    test('is valid when every item is assigned and a payer is chosen', () {
      expect(goldenDraft().problems(now), isEmpty);
    });
  });

  group('equal split', () {
    test('shares every item between everyone', () {
      final d = goldenDraft().copyWith(
        splitMode: SplitMode.equal,
        allocations: const {},
      );
      expect(d.problems(now), isEmpty);
      final values = totals(d).values.toList()..sort();
      expect(values.reduce((a, b) => a + b), 102533);
      // Each of the 4 items and 2 charges can hand one extra paisa to the
      // lowest id, so the spread is bounded by 6, never more.
      expect(values.last - values.first, lessThanOrEqualTo(6));
    });
  });

  group('custom amounts', () {
    BillDraft custom(Map<String, int> amounts) => goldenDraft().copyWith(
      splitMode: SplitMode.custom,
      allocations: const {},
      customAmounts: {for (final e in amounts.entries) e.key: Paise(e.value)},
    );

    test('uses the explicit amounts, then spreads the charges over them', () {
      final d = custom({'aarav': 50000, 'priya': 30000, 'zoya': 13000});
      expect(d.problems(now), isEmpty);
      final s = d.settle(now)!;
      expect(s.itemsSubtotal, p(93000));
      expect(s.grandTotal, p(102533));
      expect(s.reconciles, isTrue);
      final t = totals(d);
      expect(t['aarav']! > t['priya']!, isTrue);
      expect(t['priya']! > t['zoya']!, isTrue);
    });

    test('is a problem when the amounts do not add up to the items', () {
      final d = custom({'aarav': 50000, 'priya': 30000, 'zoya': 12999});
      expect(d.problems(now), contains(BillProblem.customAmountsMismatch));
    });
  });

  group('problems', () {
    test('needs at least two people', () {
      final d = goldenDraft().copyWith(
        participants: [participant('aarav', 'Aarav')],
      );
      expect(d.problems(now), contains(BillProblem.tooFewPeople));
    });

    test('needs items', () {
      final d = goldenDraft().copyWith(items: const []);
      expect(d.problems(now), contains(BillProblem.noItems));
    });

    test('rejects a bill whose items are worth nothing', () {
      final d = goldenDraft().copyWith(items: [draftItem('free', 'Free', 0)]);
      expect(d.problems(now), contains(BillProblem.zeroTotal));
    });

    test('reports unassigned items', () {
      final d = goldenDraft().copyWith(
        allocations: {
          'paneer': {'aarav'},
        },
      );
      expect(d.problems(now), contains(BillProblem.unassignedItems));
    });

    test('needs a payer who is on the bill', () {
      expect(
        goldenDraft().copyWith(clearPayer: true).problems(now),
        contains(BillProblem.noPayer),
      );
      expect(
        goldenDraft().copyWith(payerId: 'ghost').problems(now),
        contains(BillProblem.noPayer),
      );
    });

    test('toRecord refuses an incomplete bill', () {
      final d = goldenDraft().copyWith(clearPayer: true);
      expect(() => d.toRecord(id: 'x', now: now), throwsStateError);
    });
  });

  group('charges', () {
    test('tax is charged on the items plus the service charge', () {
      // 10% service on 1,000.00, then 5% tax on 1,100.00 = 55.00.
      final d = BillDraft(
        billDate: DateTime(2026, 11, 5),
        currency: Currency.inr,
        items: [draftItem('i', 'Meal', 100000)],
        adjustments: [
          charge('tax', AdjustmentKind.tax, 500, mode: AdjustmentMode.percent),
          charge(
            'service',
            AdjustmentKind.service,
            1000,
            mode: AdjustmentMode.percent,
          ),
        ],
        participants: [participant('a', 'A'), participant('b', 'B')],
        allocations: {
          'i': {'a', 'b'},
        },
        payerId: 'a',
      );
      // Entered tax-first, but applied service-first.
      final s = d.settle(now)!;
      final byAdjustment = {
        for (final a in s.adjustmentTotals) a.adjustmentId: a.amount.value,
      };
      expect(byAdjustment['service'], 10000);
      expect(byAdjustment['tax'], 5500);
      expect(s.grandTotal, p(115500));
    });

    test('a discount lowers the total and still reconciles', () {
      final d = goldenDraft().copyWith(
        adjustments: [
          charge('disc', AdjustmentKind.discount, 9300, isNegative: true),
        ],
      );
      final s = d.settle(now)!;
      expect(s.grandTotal, p(93000 - 9300));
      expect(s.reconciles, isTrue);
    });
  });

  group('toRecord', () {
    test('snapshots totals and marks the payer settled', () {
      final r = recordFrom(goldenDraft());
      expect(r.grandTotal, p(102533));
      expect(r.participantTotals['zoya'], p(32706));
      expect(r.participantSubtotals['zoya'], p(29666));
      BillParticipant who(String id) =>
          r.participants.firstWhere((x) => x.id == id);
      expect(who('aarav').isSettled, isTrue);
      expect(who('zoya').isSettled, isFalse);
      expect(r.unsettledDebtors.map((x) => x.id), ['priya', 'zoya']);
    });

    test('titles an unnamed merchant by date', () {
      final d = goldenDraft().copyWith(merchant: '  ');
      expect(d.title, 'Bill 14/11/2026');
      expect(recordFrom(d).merchant, isNull);
    });
  });
}
