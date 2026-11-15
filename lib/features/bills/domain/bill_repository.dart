import '../../people/domain/saved_person.dart';
import 'models/bill_record.dart';

/// Which bills a history list should show.
enum BillStatusFilter { all, unsettled, settled }

/// How a history list is ordered.
enum BillSort { newest, oldest, highest }

/// How far back a history list reaches.
enum BillPeriod {
  anyTime,
  last30Days,
  last90Days,
  thisYear;

  /// The earliest bill date included, given today, or null for no limit.
  DateTime? since(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    return switch (this) {
      BillPeriod.anyTime => null,
      BillPeriod.last30Days => DateTime(day.year, day.month, day.day - 30),
      BillPeriod.last90Days => DateTime(day.year, day.month, day.day - 90),
      BillPeriod.thisYear => DateTime(day.year),
    };
  }
}

/// Storage for saved bills. Implemented over SQLite in `data/repositories`.
abstract interface class BillRepository {
  /// Saves a whole bill atomically: the bill, its participants, items,
  /// allocations and adjustments are written in one transaction, so a failure
  /// can never leave a partial bill behind.
  Future<void> save(BillRecord record);

  Future<BillRecord?> byId(String id);

  /// [query] matches the title, merchant and participant names. [since]
  /// drops bills dated before that day. Newest first unless [sort] says
  /// otherwise.
  Future<List<BillSummary>> list({
    String query = '',
    BillStatusFilter status = BillStatusFilter.all,
    BillSort sort = BillSort.newest,
    DateTime? since,
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
