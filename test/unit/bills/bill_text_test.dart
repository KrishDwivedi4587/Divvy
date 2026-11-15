import 'package:divvy/core/utils/currency.dart';
import 'package:divvy/features/bills/domain/bill_text.dart';
import 'package:divvy/features/bills/domain/models/bill.dart';
import 'package:divvy/features/bills/domain/models/bill_record.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';

import '../../support/draft_builders.dart';

Adjustment adj(String label, AdjustmentMode mode, int value) => Adjustment(
  id: label,
  label: label,
  kind: AdjustmentKind.tax,
  mode: mode,
  value: value,
  order: 1,
  base: AdjustmentBase.itemsSubtotal,
  isNegative: false,
);

void main() {
  group('formatShortDate', () {
    test('formats as "3 Nov 2026"', () {
      expect(formatShortDate(DateTime(2026, 11, 3)), '3 Nov 2026');
    });

    test('does not pad single-digit days', () {
      expect(formatShortDate(DateTime(2026, 1, 5)), '5 Jan 2026');
    });

    test('covers every month', () {
      final names = [
        for (var m = 1; m <= 12; m++)
          formatShortDate(DateTime(2026, m, 1)).split(' ')[1],
      ];
      expect(names.toSet(), hasLength(12));
    });
  });

  group('adjustmentLabel', () {
    test('shows the rate for a percentage', () {
      expect(
        adjustmentLabel(adj('Tax', AdjustmentMode.percent, 500)),
        'Tax · 5%',
      );
      expect(
        adjustmentLabel(adj('Tax', AdjustmentMode.percent, 1825)),
        'Tax · 18.25%',
      );
    });

    test('shows just the label for a flat amount', () {
      expect(adjustmentLabel(adj('Tip', AdjustmentMode.amount, 5000)), 'Tip');
    });
  });

  test('peopleCount pluralises', () {
    expect(peopleCount(1), '1 person');
    expect(peopleCount(2), '2 people');
    expect(peopleCount(8), '8 people');
  });

  group('buildShareText', () {
    test('summarises the worked example', () {
      final record = recordFrom(goldenDraft());
      final text = buildShareText(record, computeFor(record));
      expect(
        text,
        '''
Divvy · The Spice Table
14 Nov 2026

Total ₹1,025.33, split by item between 3 people
Paid by Aarav

Aarav: ₹349.15
Priya: ₹349.12
Zoya: ₹327.06

Subtotal: ₹930.00
Service charge: ₹46.50
GST: ₹48.83'''
            .trim(),
      );
    });

    test('describes an equal split', () {
      final record = recordFrom(
        goldenDraft().copyWith(
          splitMode: SplitMode.equal,
          allocations: const {},
        ),
      );
      expect(
        buildShareText(record, computeFor(record)),
        contains('split equally between 3 people'),
      );
    });

    test('describes a split by amounts', () {
      final record = recordFrom(
        goldenDraft().copyWith(
          splitMode: SplitMode.custom,
          allocations: const {},
          customAmounts: {
            'aarav': p(50000),
            'priya': p(30000),
            'zoya': p(13000),
          },
        ),
      );
      expect(
        buildShareText(record, computeFor(record)),
        contains('split by amounts between 3 people'),
      );
    });

    test('uses the bill currency', () {
      final record = recordFrom(goldenDraft().copyWith(currency: Currency.usd));
      final text = buildShareText(record, computeFor(record));
      expect(text, contains(r'Total $1,025.33'));
      expect(text, isNot(contains('₹')));
    });
  });
}
