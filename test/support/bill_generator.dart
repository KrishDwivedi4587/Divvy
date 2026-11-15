import 'package:divvy/features/bills/domain/engine/money.dart';
import 'package:divvy/features/bills/domain/models/bill.dart';

/// Mulberry32: a small, fast, deterministic generator, ported from the
/// original TypeScript property test so the same seeds drive the same stream of
/// numbers. 32-bit arithmetic is emulated explicitly with masks.
class Mulberry32 {
  Mulberry32(int seed) : _a = seed & _mask;

  static const int _mask = 0xFFFFFFFF;
  int _a;

  static int _imul(int a, int b) => ((a & _mask) * (b & _mask)) & _mask;

  /// A double in [0, 1).
  double next() {
    _a = (_a + 0x6D2B79F5) & _mask;
    var t = _a;
    t = _imul(t ^ (t >>> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >>> 7), t | 61)) & _mask)) & _mask;
    return ((t ^ (t >>> 14)) & _mask) / 4294967296;
  }

  /// An integer in [min, max], inclusive.
  int nextInt(int min, int max) => min + (next() * (max - min + 1)).floor();
}

/// Builds a random but valid bill from [seed]: 1-8 people, 1-20 items
/// (deliberately some unassigned, some shared by everyone), and 0-4 adjustments
/// that may be percentages or fixed amounts, discounts or charges.
///
/// The assignment shuffle is a Fisher-Yates driven by the same generator. The
/// TypeScript original shuffled with `sort(() => rng() - 0.5)`, whose result
/// depends on the JavaScript engine's sort algorithm, so a given seed does not
/// produce an identical bill in both languages. The distribution of bills is
/// equivalent; exact cross-language agreement is checked separately by
/// replaying TypeScript-generated bills (see ts_golden_test.dart).
Bill generateBill(int seed) {
  final rng = Mulberry32(seed);

  final peopleCount = rng.nextInt(1, 8);
  final people = [
    for (var i = 0; i < peopleCount; i++)
      Person(
        id: 'person-${i.toString().padLeft(2, '0')}',
        name: 'Person $i',
        colorIndex: i % 8,
        initials: 'P$i',
      ),
  ];

  final itemCount = rng.nextInt(1, 20);
  final items = [
    for (var i = 0; i < itemCount; i++)
      () {
        // 1.00 to 5,000.00 in paise.
        final lineTotal = rng.nextInt(100, 500000);
        return BillItem(
          id: 'item-${i.toString().padLeft(2, '0')}',
          name: 'Item $i',
          quantity: 1,
          unitPrice: Paise(lineTotal),
          lineTotal: Paise(lineTotal),
        );
      }(),
  ];

  final assignments = <String, List<String>>{};
  for (final item in items) {
    final roll = rng.next();
    if (roll < 0.12) {
      assignments[item.id] = []; // deliberately unassigned
    } else if (roll < 0.24) {
      assignments[item.id] = [for (final p in people) p.id]; // shared by all
    } else {
      final count = rng.nextInt(1, peopleCount);
      final shuffled = [...people];
      for (var i = shuffled.length - 1; i > 0; i--) {
        final j = (rng.next() * (i + 1)).floor();
        final tmp = shuffled[i];
        shuffled[i] = shuffled[j];
        shuffled[j] = tmp;
      }
      assignments[item.id] = [for (final p in shuffled.take(count)) p.id];
    }
  }

  final adjustmentCount = rng.nextInt(0, 4);
  final adjustments = [
    for (var i = 0; i < adjustmentCount; i++)
      () {
        final isPercent = rng.next() < 0.7;
        final isNegative = rng.next() < 0.2;
        return Adjustment(
          id: 'adj-${i.toString().padLeft(2, '0')}',
          label: 'Adjustment $i',
          kind: isNegative ? AdjustmentKind.discount : AdjustmentKind.tax,
          mode: isPercent ? AdjustmentMode.percent : AdjustmentMode.amount,
          // percent: 0-30%. amount: Rs 0-500.
          value: isPercent ? rng.nextInt(0, 3000) : rng.nextInt(0, 50000),
          order: i,
          base: rng.next() < 0.5
              ? AdjustmentBase.itemsSubtotal
              : AdjustmentBase.runningTotal,
          isNegative: isNegative,
        );
      }(),
  ];

  return Bill(
    id: 'bill-$seed',
    title: 'Generated $seed',
    createdAt: DateTime.utc(2026, 9, 1),
    people: people,
    items: items,
    assignments: assignments,
    adjustments: adjustments,
  );
}
