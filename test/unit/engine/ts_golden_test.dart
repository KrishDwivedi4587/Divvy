// Differential test against the original TypeScript engine.
//
// test/fixtures/ts_engine_golden.json holds 200 bills and the settlement the
// TypeScript engine (tag v0.1-m1-engine) computed for each, down to every
// per-person item share and adjustment share. This test rebuilds each bill in
// Dart, settles it, and requires an exact match on every number. Passing means
// the port reproduces the original behaviour, not merely the same invariants.
//
// See test/fixtures/README.md for how the fixture was produced.

import 'dart:convert';
import 'dart:io';

import 'package:divvy/features/bills/domain/engine/money.dart';
import 'package:divvy/features/bills/domain/engine/settle.dart';
import 'package:divvy/features/bills/domain/models/bill.dart';
import 'package:flutter_test/flutter_test.dart';

Bill billFrom(Map<String, dynamic> raw, int seed) {
  final people = (raw['people'] as List<dynamic>)
      .map(
        (id) =>
            Person(id: id as String, name: id, colorIndex: 0, initials: 'P'),
      )
      .toList();

  final items = (raw['items'] as List<dynamic>).map((row) {
    final r = row as List<dynamic>;
    return BillItem(
      id: r[0] as String,
      name: r[0] as String,
      quantity: r[2] as int,
      unitPrice: Paise(r[1] as int),
      lineTotal: Paise(r[1] as int),
    );
  }).toList();

  final assignments = (raw['assignments'] as Map<String, dynamic>).map(
    (k, v) => MapEntry(k, (v as List<dynamic>).cast<String>()),
  );

  final adjustments = (raw['adjustments'] as List<dynamic>).map((row) {
    final r = row as List<dynamic>;
    return Adjustment(
      id: r[0] as String,
      label: r[0] as String,
      kind: AdjustmentKind.tax,
      mode: AdjustmentMode.fromWire(r[1] as String),
      value: r[2] as int,
      order: r[3] as int,
      base: AdjustmentBase.fromWire(r[4] as String),
      isNegative: r[5] as bool,
    );
  }).toList();

  return Bill(
    id: 'bill-$seed',
    title: 'Golden $seed',
    createdAt: DateTime.utc(2026, 9, 1),
    people: people,
    items: items,
    assignments: assignments,
    adjustments: adjustments,
  );
}

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/ts_engine_golden.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final cases = fixture['cases'] as List<dynamic>;

  test('the fixture is the expected size', () {
    expect(cases, hasLength(200));
  });

  test('matches the TypeScript engine exactly for all 200 bills', () {
    for (final c in cases) {
      final entry = c as Map<String, dynamic>;
      final seed = entry['seed'] as int;
      final expected = entry['expected'] as Map<String, dynamic>;
      final s = computeSettlement(
        billFrom(entry['bill'] as Map<String, dynamic>, seed),
      );
      final why = 'seed $seed';

      expect(s.itemsSubtotal.value, expected['itemsSubtotal'], reason: why);
      expect(s.grandTotal.value, expected['grandTotal'], reason: why);
      expect(
        s.unassignedAmount.value,
        expected['unassignedAmount'],
        reason: why,
      );
      expect(
        s.unassignedItemIds,
        (expected['unassignedItemIds'] as List<dynamic>).cast<String>(),
        reason: why,
      );
      expect(s.reconciles, expected['reconciles'], reason: why);

      final totals = expected['adjustmentTotals'] as List<dynamic>;
      expect(s.adjustmentTotals, hasLength(totals.length), reason: why);
      for (var i = 0; i < totals.length; i++) {
        final t = totals[i] as List<dynamic>;
        expect(s.adjustmentTotals[i].adjustmentId, t[0], reason: why);
        expect(s.adjustmentTotals[i].amount.value, t[1], reason: why);
      }

      final people = expected['perPerson'] as List<dynamic>;
      expect(s.perPerson, hasLength(people.length), reason: why);
      for (var i = 0; i < people.length; i++) {
        final row = people[i] as List<dynamic>;
        final got = s.perPerson[i];
        expect(got.personId, row[0], reason: why);
        expect(got.subtotal.value, row[1], reason: '$why ${got.personId}');
        expect(got.total.value, row[2], reason: '$why ${got.personId}');

        final itemShares = row[3] as List<dynamic>;
        expect(got.itemShares, hasLength(itemShares.length), reason: why);
        for (var j = 0; j < itemShares.length; j++) {
          final e = itemShares[j] as List<dynamic>;
          expect(got.itemShares[j].itemId, e[0], reason: why);
          expect(got.itemShares[j].share.value, e[1], reason: why);
          expect(got.itemShares[j].assigneeCount, e[2], reason: why);
        }

        final adjShares = row[4] as List<dynamic>;
        expect(got.adjustmentShares, hasLength(adjShares.length), reason: why);
        for (var j = 0; j < adjShares.length; j++) {
          final e = adjShares[j] as List<dynamic>;
          expect(got.adjustmentShares[j].adjustmentId, e[0], reason: why);
          expect(got.adjustmentShares[j].share.value, e[1], reason: why);
        }
      }
    }
  });
}
