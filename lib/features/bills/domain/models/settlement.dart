/// The calculation engine's output model.
///
/// Always derived, never trusted from storage: a settlement is recomputed from
/// the bill, so a stored total can never go stale.
library;

import '../engine/money.dart';

class ItemShare {
  const ItemShare({
    required this.itemId,
    required this.share,
    required this.assigneeCount,
  });

  final String itemId;
  final Paise share;
  final int assigneeCount;
}

/// Negative for discounts.
class AdjustmentShare {
  const AdjustmentShare({required this.adjustmentId, required this.share});

  final String adjustmentId;
  final Paise share;
}

class AdjustmentTotal {
  const AdjustmentTotal({required this.adjustmentId, required this.amount});

  final String adjustmentId;
  final Paise amount;
}

class PersonSettlement {
  const PersonSettlement({
    required this.personId,
    required this.itemShares,
    required this.subtotal,
    required this.adjustmentShares,
    required this.total,
  });

  final String personId;
  final List<ItemShare> itemShares;

  /// The sum of the item shares.
  final Paise subtotal;
  final List<AdjustmentShare> adjustmentShares;

  /// The subtotal plus the sum of the adjustment shares.
  final Paise total;
}

class Settlement {
  const Settlement({
    required this.perPerson,
    required this.itemsSubtotal,
    required this.adjustmentTotals,
    required this.grandTotal,
    required this.unassignedItemIds,
    required this.unassignedAmount,
    required this.reconciles,
  });

  final List<PersonSettlement> perPerson;

  /// Every item's line total, assigned or not.
  final Paise itemsSubtotal;
  final List<AdjustmentTotal> adjustmentTotals;

  /// The items subtotal plus every adjustment.
  final Paise grandTotal;
  final List<String> unassignedItemIds;
  final Paise unassignedAmount;

  /// MUST be true: the people's totals sum to the grand total minus whatever
  /// is unassigned. Surfaced as an error state rather than ignored.
  final bool reconciles;
}
