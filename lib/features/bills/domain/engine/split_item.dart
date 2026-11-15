/// Splitting one item across its assignees.
///
/// Pure Dart. Imports nothing from Flutter, the database or the UI.
library;

import '../../../../core/errors/domain_error.dart';
import 'money.dart';

/// Total ordering on ids. Every tie-break in the engine, here and in
/// `apportion`, uses this one rule.
int compareIds(String a, String b) => a.compareTo(b);

/// Divides an item's line total equally across k assignees, exactly.
///
/// `base = floor(total / k)`, and the `remainder` leftover paise go one each to
/// the first `remainder` assignees in ascending id order. So Rs 100.00 across
/// three people is 3334 / 3333 / 3333, summing to exactly 10000, with someone
/// paying one extra paisa.
///
/// Two properties matter and are tested:
///  * **Exact**: the shares always sum to the line total. No paisa is created
///    or lost.
///  * **Deterministic**: sorting by id means the same bill always produces the
///    same answer, which is what makes "why did Aarav pay a paisa more?"
///    answerable rather than mysterious.
///
/// An item with no assignees returns an empty map; its value becomes part of
/// the settlement's `unassignedAmount` rather than being silently absorbed by
/// someone.
Map<String, Paise> splitItem(Paise lineTotal, List<String> assigneeIds) {
  final shares = <String, Paise>{};

  if (lineTotal.isNegative) {
    throw DomainError(
      DomainErrorCode.negativeAmount,
      'Item line total cannot be negative: ${lineTotal.value}',
    );
  }

  final k = assigneeIds.length;
  if (k == 0) return shares;

  if (assigneeIds.toSet().length != k) {
    throw DomainError(
      DomainErrorCode.duplicateId,
      'An item cannot be assigned to the same person twice: '
      '${assigneeIds.join(', ')}',
    );
  }

  final base = lineTotal.value ~/ k;
  final remainder = lineTotal.value - base * k; // 0 <= remainder < k

  final ordered = [...assigneeIds]..sort(compareIds);
  for (var index = 0; index < ordered.length; index++) {
    shares[ordered[index]] = toPaise(index < remainder ? base + 1 : base);
  }
  return shares;
}
