import 'package:divvy/core/errors/domain_error.dart';
import 'package:divvy/features/bills/domain/engine/money.dart';
import 'package:divvy/features/bills/domain/engine/settle.dart';
import 'package:divvy/features/bills/domain/models/bill.dart';
import 'package:divvy/features/bills/domain/models/settlement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';

String describe(Settlement s) => [
  s.itemsSubtotal.value,
  s.grandTotal.value,
  s.unassignedAmount.value,
  for (final p in s.perPerson) ...[
    p.personId,
    p.subtotal.value,
    p.total.value,
    for (final i in p.itemShares) '${i.itemId}:${i.share.value}',
    for (final a in p.adjustmentShares) '${a.adjustmentId}:${a.share.value}',
  ],
].join('|');

void main() {
  group('edge cases', () {
    test('handles a single person with a single item', () {
      final s = computeSettlement(
        bill(
          people: [person('solo')],
          items: [item('i1', 'Item', 12345)],
          assignments: {
            'i1': ['solo'],
          },
        ),
      );
      expect(s.perPerson[0].total, p(12345));
      expect(s.reconciles, isTrue);
    });

    test('handles a person with no items assigned', () {
      final s = computeSettlement(
        bill(
          people: [person('a'), person('idle')],
          items: [item('i1', 'Item', 10000)],
          assignments: {
            'i1': ['a'],
          },
        ),
      );
      expect(byId(s)['idle']!.subtotal, p(0));
      expect(byId(s)['idle']!.total, p(0));
      expect(s.reconciles, isTrue);
    });

    test('handles a bill with no items', () {
      final s = computeSettlement(bill(people: [person('a')]));
      expect(s.itemsSubtotal, p(0));
      expect(s.grandTotal, p(0));
      expect(s.reconciles, isTrue);
    });

    test('handles a zero-priced item', () {
      final s = computeSettlement(
        bill(
          people: [person('a'), person('b')],
          items: [item('free', 'Complimentary', 0)],
          assignments: {
            'free': ['a', 'b'],
          },
        ),
      );
      expect(s.grandTotal, p(0));
      expect(s.reconciles, isTrue);
    });

    test('handles eight people sharing one item', () {
      final ids = List.generate(8, (i) => 'p$i');
      final s = computeSettlement(
        bill(
          people: ids.map(person).toList(),
          items: [item('i1', 'Item', 10000)],
          assignments: {'i1': ids},
        ),
      );
      expect(totalOf(s), 10000);
      expect(s.reconciles, isTrue);
    });

    test('is deterministic across repeated runs', () {
      final b = bill(
        people: [person('c'), person('a'), person('b')],
        items: [item('i1', 'Item', 10001)],
        assignments: {
          'i1': ['c', 'a', 'b'],
        },
      );
      final first = describe(computeSettlement(b));
      for (var i = 0; i < 50; i++) {
        expect(describe(computeSettlement(b)), first);
      }
    });
  });

  group('validation', () {
    final cases = <(String, Bill Function(), DomainErrorCode)>[
      (
        'no people',
        () => bill(items: [item('i1', 'x', 100)]),
        DomainErrorCode.noPeople,
      ),
      (
        'duplicate person ids',
        () => bill(people: [person('a'), person('a')]),
        DomainErrorCode.duplicateId,
      ),
      (
        'duplicate item ids',
        () => bill(
          people: [person('a')],
          items: [item('dup', 'x', 100), item('dup', 'y', 200)],
        ),
        DomainErrorCode.duplicateId,
      ),
      (
        'unknown person in an assignment',
        () => bill(
          people: [person('a')],
          items: [item('i1', 'x', 100)],
          assignments: {
            'i1': ['ghost'],
          },
        ),
        DomainErrorCode.unknownPerson,
      ),
      (
        'unknown item in an assignment',
        () => bill(
          people: [person('a')],
          items: [item('i1', 'x', 100)],
          assignments: {
            'nonexistent': ['a'],
          },
        ),
        DomainErrorCode.unknownItem,
      ),
      (
        'negative line total',
        () => bill(people: [person('a')], items: [item('i1', 'x', -100)]),
        DomainErrorCode.negativeAmount,
      ),
      (
        'zero quantity',
        () => bill(
          people: [person('a')],
          items: [
            BillItem(
              id: 'i1',
              name: 'x',
              quantity: 0,
              unitPrice: p(100),
              lineTotal: p(100),
            ),
          ],
        ),
        DomainErrorCode.invalidQuantity,
      ),
      (
        'duplicate adjustment ids',
        () => bill(
          people: [person('a')],
          adjustments: [
            adjustment('t', mode: AdjustmentMode.percent, value: 1, order: 1),
            adjustment('t', mode: AdjustmentMode.percent, value: 2, order: 2),
          ],
        ),
        DomainErrorCode.duplicateId,
      ),
    ];

    for (final (label, make, code) in cases) {
      test('rejects $label', () {
        expect(
          () => computeSettlement(make()),
          throwsA(isA<DomainError>().having((e) => e.code, 'code', code)),
        );
      });
    }

    test('rejects an item assigned to the same person twice', () {
      expect(
        () => computeSettlement(
          bill(
            people: [person('a')],
            items: [item('i1', 'x', 100)],
            assignments: {
              'i1': ['a', 'a'],
            },
          ),
        ),
        throwsA(isA<DomainError>()),
      );
    });

    test('a fractional line total cannot be constructed (type-enforced)', () {
      // The TypeScript engine validated this inside computeSettlement. In Dart
      // a line total is a Paise wrapping an int, so the invalid state is
      // unrepresentable; the check moves to the construction boundary.
      expect(
        () => toPaise(10.5),
        throwsA(
          isA<DomainError>().having(
            (e) => e.code,
            'code',
            DomainErrorCode.notAnInteger,
          ),
        ),
      );
    });
  });
}
