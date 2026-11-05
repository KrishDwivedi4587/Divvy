/// Largest-remainder (Hamilton) apportionment.
///
/// Distributing a tax or service charge proportionally is the place where naive
/// code loses paise: each person's exact share is fractional, and rounding them
/// independently produces a total that misses the real charge by a few paise.
///
/// Largest remainder fixes that by construction. Everyone gets their floor, and
/// the leftover paise go to whoever was cut most by flooring. The result sums to
/// the requested amount *exactly*, every time, not approximately.
///
/// Pure Dart. Imports nothing from Flutter, the database or the UI.
library;

import '../../../../core/errors/domain_error.dart';
import 'money.dart';
import 'split_item.dart';

/// A claimant on an amount, and how heavily it weighs.
class Weighted {
  const Weighted(this.id, this.weight);

  final String id;

  /// Non-negative. Typically a person's running subtotal in paise.
  final int weight;
}

/// One claimant's portion of an apportioned amount.
class Share {
  const Share(this.id, this.share);

  final String id;
  final Paise share;

  @override
  bool operator ==(Object other) =>
      other is Share && other.id == id && other.share == share;

  @override
  int get hashCode => Object.hash(id, share.value);

  @override
  String toString() => 'Share($id, ${share.value})';
}

class _Row {
  _Row(this.id, this.floor, this.remainder);
  final String id;
  final int floor;
  final int remainder;
}

/// Distributes [amount] across [entries] in proportion to their weights.
///
/// [amount] must be **non-negative**. Discounts are handled by the caller
/// apportioning the absolute value and negating the result: see
/// [apportionSigned].
///
/// When every weight is zero (charges exist but nobody has been assigned
/// anything yet) it falls back to an equal split, which is the only defensible
/// answer and keeps the invariant intact.
List<Share> apportion(Paise amount, List<Weighted> entries) {
  if (amount.isNegative) {
    throw const DomainError(
      DomainErrorCode.negativeAmount,
      'apportion() requires a non-negative amount; '
      'use apportionSigned() for discounts',
    );
  }
  if (entries.isEmpty) return const [];

  for (final e in entries) {
    if (e.weight < 0) {
      throw DomainError(
        DomainErrorCode.negativeAmount,
        'Weight must be non-negative, got ${e.weight}',
      );
    }
  }

  final totalWeight = entries.fold<int>(0, (sum, e) => sum + e.weight);

  // Nobody has a subtotal but a charge still has to land somewhere.
  final effective = totalWeight == 0
      ? [for (final e in entries) Weighted(e.id, 1)]
      : entries;
  final w = totalWeight == 0 ? effective.length : totalWeight;

  // floor(A x wi / W), with the exact integer remainder kept for the tie-break.
  final rows = <_Row>[];
  for (final e in effective) {
    assertSafeProduct(amount.value, e.weight);
    final product = amount.value * e.weight;
    final floor = product ~/ w;
    rows.add(_Row(e.id, floor, product - floor * w));
  }

  final allocated = rows.fold<int>(0, (sum, r) => sum + r.floor);
  var leftover = amount.value - allocated; // 0 <= leftover < entries.length

  // Largest remainder first; ties broken by id so the result is deterministic.
  final ranked = [...rows]
    ..sort((a, b) {
      final byRemainder = b.remainder.compareTo(a.remainder);
      return byRemainder != 0 ? byRemainder : compareIds(a.id, b.id);
    });

  final bonus = <String>{};
  for (final row in ranked) {
    if (leftover <= 0) break;
    bonus.add(row.id);
    leftover -= 1;
  }

  // Returned in the caller's original order, not ranked order.
  return [
    for (final r in rows)
      Share(r.id, toPaise(r.floor + (bonus.contains(r.id) ? 1 : 0))),
  ];
}

/// Apportions a signed amount.
///
/// **The D7 trap.** A discount must not be pushed through [apportion] as a
/// negative number: floor division of a negative number rounds *away* from
/// zero (floor(-7 / 3) is -3, not -2), so the floors overshoot, `leftover`
/// goes negative, and the totals stop reconciling. The only safe formulation is
/// to apportion the magnitude and negate afterwards, which is exactly what this
/// does.
List<Share> apportionSigned(
  Paise amount,
  List<Weighted> entries,
  bool isNegative,
) {
  final magnitude = toPaise(amount.value.abs());
  final shares = apportion(magnitude, entries);
  if (!isNegative) return shares;
  return [for (final s in shares) Share(s.id, toPaise(-s.share.value))];
}
