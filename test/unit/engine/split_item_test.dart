import 'package:divvy/core/errors/domain_error.dart';
import 'package:divvy/features/bills/domain/engine/money.dart';
import 'package:divvy/features/bills/domain/engine/split_item.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';
import '../../support/fuzz.dart';

int sum(Map<String, Paise> m) => m.values.fold(0, (a, b) => a + b.value);

String canonical(Map<String, Paise> m) {
  final keys = m.keys.toList()..sort();
  return keys.map((k) => '$k=${m[k]!.value}').join(',');
}

void main() {
  group('splitItem', () {
    test('gives one person the whole amount', () {
      final shares = splitItem(p(10000), ['a']);
      expect(shares['a'], p(10000));
      expect(sum(shares), 10000);
    });

    test('splits 100.00 between two people evenly', () {
      final shares = splitItem(p(10000), ['a', 'b']);
      expect(shares['a'], p(5000));
      expect(shares['b'], p(5000));
      expect(sum(shares), 10000);
    });

    test('splits 100.00 across three as 3334/3333/3333 and sums exactly', () {
      final shares = splitItem(p(10000), ['a', 'b', 'c']);
      expect(shares['a'], p(3334)); // lowest id absorbs the remainder
      expect(shares['b'], p(3333));
      expect(shares['c'], p(3333));
      expect(sum(shares), 10000);
    });

    test('splits a single paisa across three people without losing it', () {
      final shares = splitItem(p(1), ['a', 'b', 'c']);
      expect(sum(shares), 1);
      final values = shares.values.map((v) => v.value).toList()..sort();
      expect(values, [0, 0, 1]);
    });

    test('splits 100.00 across seven people and sums exactly', () {
      final ids = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
      final shares = splitItem(p(10000), ids);
      expect(sum(shares), 10000);
      // 10000 - 7 x 1428 = 4, so four people pay 1429 and three pay 1428.
      expect(shares.values.where((v) => v == p(1429)), hasLength(4));
      expect(shares.values.where((v) => v == p(1428)), hasLength(3));
    });

    test('returns an empty map for an unassigned item', () {
      expect(splitItem(p(10000), []), isEmpty);
    });

    test('handles a zero-value item', () {
      expect(sum(splitItem(p(0), ['a', 'b'])), 0);
    });

    test('is order-independent: assignee order changes nobody share', () {
      final forward = splitItem(p(10000), ['a', 'b', 'c']);
      final reversed = splitItem(p(10000), ['c', 'b', 'a']);
      expect(canonical(forward), canonical(reversed));
    });

    test('is deterministic across 100 identical runs', () {
      final first = canonical(splitItem(p(10001), ['x', 'y', 'z']));
      for (var i = 0; i < 100; i++) {
        expect(canonical(splitItem(p(10001), ['x', 'y', 'z'])), first);
      }
    });

    test('rejects a negative line total', () {
      expect(() => splitItem(p(-1), ['a']), throwsA(isA<DomainError>()));
    });

    test('rejects duplicate assignees', () {
      expect(
        () => splitItem(p(10000), ['a', 'a']),
        throwsA(
          isA<DomainError>().having(
            (e) => e.code,
            'code',
            DomainErrorCode.duplicateId,
          ),
        ),
      );
    });

    group('fuzz: shares always sum to the line total exactly', () {
      test('holds for 1..12 people across 500 random amounts each', () {
        fuzz((rnd) {
          for (var k = 1; k <= 12; k++) {
            final ids = List.generate(k, (i) => 'person-$i');
            for (var n = 0; n < 500; n++) {
              final amount = p(rnd.nextInt(500000));
              final shares = splitItem(amount, ids);
              expect(sum(shares), amount.value);
              expect(shares.length, k);
              for (final v in shares.values) {
                expect(v.value, greaterThanOrEqualTo(0));
              }
            }
          }
        });
      });
    });
  });
}
