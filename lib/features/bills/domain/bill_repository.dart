import '../../people/domain/saved_person.dart';
import 'models/bill_record.dart';

/// Which bills a history list should show.
enum BillStatusFilter { all, unsettled, settled }

/// Storage for saved bills. Implemented over SQLite in `data/repositories`.
abstract interface class BillRepository {
  /// Saves a whole bill atomically: the bill, its participants, items,
  /// allocations and adjustments are written in one transaction, so a failure
  /// can never leave a partial bill behind.
  Future<void> save(BillRecord record);

  Future<BillRecord?> byId(String id);

  /// Newest first. [query] matches the title, merchant and participant names.
  Future<List<BillSummary>> list({
    String query = '',
    BillStatusFilter status = BillStatusFilter.all,
    int? limit,
  });

  /// Bills the given saved person took part in, newest first.
  Future<List<BillSummary>> forPerson(String personId);

  Future<void> rename(String billId, String title);

  /// Marks one participant as having paid (or not yet paid) the payer back.
  Future<void> setSettled(
    String participantId, {
    required bool settled,
    required DateTime at,
  });

  /// Deletes a bill and everything that belongs to it. Returns the receipt
  /// path so the caller can remove the image file, or null if there was none.
  Future<String?> delete(String billId);

  /// Net balances against each saved person, from the account holder's side.
  Future<List<PersonBalance>> balances();

  Future<int> count();

  /// The most recent things that happened, newest first: bills saved and
  /// people paying back.
  Future<List<ActivityEvent>> recentActivity({int limit = 8});
}
