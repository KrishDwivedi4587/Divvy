import '../../../core/utils/currency.dart';
import '../../bills/domain/engine/money.dart';
import 'person_rules.dart';

/// Someone saved in the People list, available to add to future bills.
class SavedPerson {
  const SavedPerson({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.isSelf,
    required this.createdAt,
    this.archivedAt,
  });

  final String id;
  final String name;

  /// Picks one of the neutral avatar tones. Never carries meaning by itself.
  final int colorIndex;

  /// True for the account holder. There is exactly one, and it cannot be
  /// removed.
  final bool isSelf;
  final DateTime createdAt;

  /// Set when the person was removed but still appears on past bills. They are
  /// hidden from pickers but kept so history and balances stay intact.
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;
  String get initials => initialsFor(name);
}

/// What happened when a person was removed.
enum RemovalOutcome {
  /// The person was on no bills, so the record was deleted.
  deleted,

  /// The person is on past bills, so the record was archived instead.
  archived,

  /// The account holder cannot be removed.
  refused,
}

/// The result of adding or renaming a person.
sealed class PersonResult {
  const PersonResult();
}

final class PersonSaved extends PersonResult {
  const PersonSaved(this.person);
  final SavedPerson person;
}

final class PersonRejected extends PersonResult {
  const PersonRejected(this.reason);
  final NameCheckFailure reason;
}

/// What a person owes, or is owed, per currency, from the account holder's
/// point of view. Positive means they owe the account holder.
class PersonBalance {
  const PersonBalance(this.personId, this.net);

  final String personId;
  final Map<Currency, Paise> net;

  bool get isSettled => net.values.every((v) => v.isZero);
}
