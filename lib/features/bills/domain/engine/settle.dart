/// Full settlement.
///
/// [computeSettlement] is the engine's single entry point. It takes a plain
/// [Bill] and returns a plain [Settlement]; it knows nothing about Flutter,
/// state management, or the database, which is what lets the whole money model
/// be proven on a laptop with no device.
///
/// Settlements are always recomputed and never trusted from storage: a stored
/// total can go stale, a derived one cannot.
library;

import '../../../../core/errors/domain_error.dart';
import '../models/bill.dart';
import '../models/settlement.dart';
import 'apportion.dart';
import 'money.dart';
import 'split_item.dart';

/// Computes every person's share of a bill.
///
/// Order of operations follows a real Indian restaurant bill: items, then
/// adjustments in their explicit `order`, each applied to either the items
/// subtotal or the running total. That is why GST-on-(items + service charge)
/// comes out right rather than approximately right.
///
/// Throws [DomainError] if the bill is structurally invalid.
Settlement computeSettlement(Bill bill) {
  _validate(bill);

  final people = [...bill.people]..sort((a, b) => compareIds(a.id, b.id));

  // 1: items subtotal, over ALL items, assigned or not.
  final itemsSubtotal = toPaise(
    bill.items.fold<int>(0, (sum, item) => sum + item.lineTotal.value),
  );

  // 2/3: split each item, accumulate per-person subtotals.
  final itemSharesByPerson = <String, List<ItemShare>>{
    for (final p in people) p.id: <ItemShare>[],
  };

  final unassignedItemIds = <String>[];
  var unassignedAmount = 0;

  for (final item in bill.items) {
    final assignees = bill.assignments[item.id] ?? const <String>[];

    if (assignees.isEmpty) {
      unassignedItemIds.add(item.id);
      unassignedAmount += item.lineTotal.value;
      continue;
    }

    final shares = splitItem(item.lineTotal, assignees);
    for (final entry in shares.entries) {
      itemSharesByPerson[entry.key]?.add(
        ItemShare(
          itemId: item.id,
          share: entry.value,
          assigneeCount: assignees.length,
        ),
      );
    }
  }

  final subtotals = <String, int>{
    for (final p in people)
      p.id: (itemSharesByPerson[p.id] ?? const <ItemShare>[]).fold<int>(
        0,
        (sum, s) => sum + s.share.value,
      ),
  };

  // 5: adjustments, in order, each apportioned across the running base.
  final runningBase = <String, int>{...subtotals};
  final adjustmentSharesByPerson = <String, List<AdjustmentShare>>{
    for (final p in people) p.id: <AdjustmentShare>[],
  };
  final adjustmentTotals = <AdjustmentTotal>[];

  final ordered = [...bill.adjustments]
    ..sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : compareIds(a.id, b.id);
    });

  for (final adj in ordered) {
    final runningSum = runningBase.values.fold<int>(0, (s, v) => s + v);
    final pool = adj.base == AdjustmentBase.itemsSubtotal
        ? itemsSubtotal
        : toPaise(runningSum);

    final magnitude = _amountFor(adj, pool);
    final signed = adj.isNegative ? -magnitude.value : magnitude.value;
    adjustmentTotals.add(
      AdjustmentTotal(adjustmentId: adj.id, amount: toPaise(signed)),
    );

    // Weights are clamped at zero. A large discount can push someone's running
    // base negative (their discount share exceeded their subtotal), and a
    // proportional share of a *negative* weight is meaningless: it would hand
    // that person a negative slice of a positive charge. Clamping means such a
    // person simply receives none of the next proportional adjustment.
    //
    // This does not weaken the invariant: apportion still distributes the
    // amount exactly across whatever weights it is given, and if every weight
    // clamps to zero it falls back to an equal split.
    final weights = [
      for (final p in people) Weighted(p.id, _max0(runningBase[p.id] ?? 0)),
    ];

    final shares = apportionSigned(magnitude, weights, adj.isNegative);
    for (final s in shares) {
      adjustmentSharesByPerson[s.id]?.add(
        AdjustmentShare(adjustmentId: adj.id, share: s.share),
      );
      runningBase[s.id] = (runningBase[s.id] ?? 0) + s.share.value;
    }
  }

  // 6: per-person totals.
  final perPerson = <PersonSettlement>[];
  for (final p in people) {
    final itemShares = itemSharesByPerson[p.id] ?? const <ItemShare>[];
    final adjustmentShares =
        adjustmentSharesByPerson[p.id] ?? const <AdjustmentShare>[];
    final subtotal = subtotals[p.id] ?? 0;
    final total =
        subtotal +
        adjustmentShares.fold<int>(0, (sum, a) => sum + a.share.value);

    perPerson.add(
      PersonSettlement(
        personId: p.id,
        itemShares: itemShares,
        subtotal: toPaise(subtotal),
        adjustmentShares: adjustmentShares,
        total: toPaise(total),
      ),
    );
  }

  // 7/8: grand total and the invariant.
  final grandTotal = toPaise(
    itemsSubtotal.value +
        adjustmentTotals.fold<int>(0, (sum, a) => sum + a.amount.value),
  );
  final sumOfPeople = perPerson.fold<int>(0, (sum, p) => sum + p.total.value);
  final reconciles = sumOfPeople == grandTotal.value - unassignedAmount;

  return Settlement(
    perPerson: perPerson,
    itemsSubtotal: itemsSubtotal,
    adjustmentTotals: adjustmentTotals,
    grandTotal: grandTotal,
    unassignedItemIds: unassignedItemIds,
    unassignedAmount: toPaise(unassignedAmount),
    reconciles: reconciles,
  );
}

int _max0(int value) => value < 0 ? 0 : value;

/// Percentage adjustments round once, here, and nowhere else.
Paise _amountFor(Adjustment adj, Paise pool) {
  if (adj.mode == AdjustmentMode.amount) return toPaise(adj.value.abs());
  return percentOf(toPaise(pool.value.abs()), adj.value.abs());
}

/// Rejects structurally invalid bills loudly rather than returning plausible
/// but wrong money. Every check here corresponds to a bug that would otherwise
/// be invisible in the totals.
void _validate(Bill bill) {
  if (bill.people.isEmpty) {
    throw const DomainError(
      DomainErrorCode.noPeople,
      'A bill must have at least one person to settle',
    );
  }

  final personIds = <String>{};
  for (final p in bill.people) {
    if (!personIds.add(p.id)) {
      throw DomainError(
        DomainErrorCode.duplicateId,
        'Duplicate person id: ${p.id}',
      );
    }
  }

  final itemIds = <String>{};
  for (final item in bill.items) {
    if (!itemIds.add(item.id)) {
      throw DomainError(
        DomainErrorCode.duplicateId,
        'Duplicate item id: ${item.id}',
      );
    }
    if (item.lineTotal.isNegative) {
      throw DomainError(
        DomainErrorCode.negativeAmount,
        'Item ${item.id} has a negative line total: ${item.lineTotal.value}',
      );
    }
    if (item.quantity < 1) {
      throw DomainError(
        DomainErrorCode.invalidQuantity,
        'Item ${item.id} quantity must be an integer >= 1, '
        'got ${item.quantity}',
      );
    }
  }

  for (final entry in bill.assignments.entries) {
    if (!itemIds.contains(entry.key)) {
      throw DomainError(
        DomainErrorCode.unknownItem,
        'Assignment refers to unknown item: ${entry.key}',
      );
    }
    for (final personId in entry.value) {
      if (!personIds.contains(personId)) {
        throw DomainError(
          DomainErrorCode.unknownPerson,
          'Item ${entry.key} is assigned to unknown person: $personId',
        );
      }
    }
  }

  final adjustmentIds = <String>{};
  for (final adj in bill.adjustments) {
    if (!adjustmentIds.add(adj.id)) {
      throw DomainError(
        DomainErrorCode.duplicateId,
        'Duplicate adjustment id: ${adj.id}',
      );
    }
  }
}
