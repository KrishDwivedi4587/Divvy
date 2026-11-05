import 'saved_person.dart';

/// Storage for saved people. Implemented over SQLite in `data/repositories`.
abstract interface class PeopleRepository {
  /// Active people, account holder first, then alphabetically. Archived people
  /// are included only when asked for.
  Future<List<SavedPerson>> all({bool includeArchived = false});

  Future<SavedPerson?> byId(String id);

  /// The account holder.
  Future<SavedPerson> self();

  /// Adds a person, rejecting empty, over-long and duplicate names.
  Future<PersonResult> add(String name);

  /// Renames a person. Past bills keep the name they were saved with.
  Future<PersonResult> rename(String id, String name);

  /// Removes a person: deleted if they are on no bills, archived if they are.
  Future<RemovalOutcome> remove(String id);

  /// How many bills this person is on.
  Future<int> billCount(String id);
}
