import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/currency.dart';
import '../../features/account/domain/app_settings.dart';
import '../../features/bills/domain/bill_draft.dart';
import '../../features/bills/domain/bill_repository.dart';
import '../../features/bills/domain/models/bill_record.dart';
import '../../features/people/domain/saved_person.dart';
import 'app_providers.dart';

/// Bumped whenever stored data changes. Every provider that reads stored data
/// watches it, so one write refreshes every screen that shows the result: the
/// home screen, history, balances and the person pages all stay in step.
class DataRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dataRevisionProvider = NotifierProvider<DataRevision, int>(
  DataRevision.new,
);

/// What a history list is filtered and ordered by.
class BillQuery {
  const BillQuery({
    this.text = '',
    this.status = BillStatusFilter.all,
    this.sort = BillSort.newest,
    this.period = BillPeriod.anyTime,
  });

  final String text;
  final BillStatusFilter status;
  final BillSort sort;
  final BillPeriod period;

  /// True when the list is narrowed in any way (not merely reordered).
  bool get isFiltering =>
      text.isNotEmpty ||
      status != BillStatusFilter.all ||
      period != BillPeriod.anyTime;

  @override
  bool operator ==(Object other) =>
      other is BillQuery &&
      other.text == text &&
      other.status == status &&
      other.sort == sort &&
      other.period == period;

  @override
  int get hashCode => Object.hash(text, status, sort, period);
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.read(settingsRepositoryProvider).load();

  Future<void> setCurrency(Currency currency) async {
    await ref.read(settingsRepositoryProvider).setCurrency(currency);
    state = AsyncData(
      (state.value ?? const AppSettings()).copyWith(currency: currency),
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await ref.read(settingsRepositoryProvider).setThemeMode(mode);
    state = AsyncData(
      (state.value ?? const AppSettings()).copyWith(themeMode: mode),
    );
  }

  Future<void> setAutoReadReceipts(bool value) async {
    await ref.read(settingsRepositoryProvider).setAutoReadReceipts(value);
    state = AsyncData(
      (state.value ?? const AppSettings()).copyWith(autoReadReceipts: value),
    );
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// The preferred currency, defaulting to rupees while settings load.
final currencyProvider = Provider<Currency>(
  (ref) => ref.watch(settingsProvider).value?.currency ?? Currency.inr,
);

final peopleProvider = FutureProvider<List<SavedPerson>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(peopleRepositoryProvider).all();
});

final selfPersonProvider = FutureProvider<SavedPerson>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(peopleRepositoryProvider).self();
});

final personProvider = FutureProvider.autoDispose.family<SavedPerson?, String>((
  ref,
  id,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(peopleRepositoryProvider).byId(id);
});

/// Net balances keyed by saved-person id.
final balancesProvider = FutureProvider<Map<String, PersonBalance>>((
  ref,
) async {
  ref.watch(dataRevisionProvider);
  final list = await ref.watch(billRepositoryProvider).balances();
  return {for (final b in list) b.personId: b};
});

final billListProvider = FutureProvider.autoDispose
    .family<List<BillSummary>, BillQuery>((ref, query) {
      ref.watch(dataRevisionProvider);
      return ref
          .watch(billRepositoryProvider)
          .list(
            query: query.text,
            status: query.status,
            sort: query.sort,
            since: query.period.since(ref.watch(clockProvider)()),
          );
    });

final recentBillsProvider = FutureProvider<List<BillSummary>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(billRepositoryProvider).list(limit: 5);
});

final recentActivityProvider = FutureProvider<List<ActivityEvent>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(billRepositoryProvider).recentActivity();
});

final billCountProvider = FutureProvider<int>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(billRepositoryProvider).count();
});

final billDetailProvider = FutureProvider.autoDispose
    .family<BillRecord?, String>((ref, id) {
      ref.watch(dataRevisionProvider);
      return ref.watch(billRepositoryProvider).byId(id);
    });

final personBillsProvider = FutureProvider.autoDispose
    .family<List<BillSummary>, String>((ref, personId) {
      ref.watch(dataRevisionProvider);
      return ref.watch(billRepositoryProvider).forPerson(personId);
    });

/// Changes to people. Each one refreshes everything that shows people.
class PeopleActions {
  PeopleActions(this._ref);

  final Ref _ref;

  Future<PersonResult> add(String name) async {
    final result = await _ref.read(peopleRepositoryProvider).add(name);
    _ref.read(dataRevisionProvider.notifier).bump();
    return result;
  }

  Future<PersonResult> rename(String id, String name) async {
    final result = await _ref.read(peopleRepositoryProvider).rename(id, name);
    _ref.read(dataRevisionProvider.notifier).bump();
    return result;
  }

  Future<RemovalOutcome> remove(String id) async {
    final outcome = await _ref.read(peopleRepositoryProvider).remove(id);
    _ref.read(dataRevisionProvider.notifier).bump();
    return outcome;
  }
}

final peopleActionsProvider = Provider<PeopleActions>(PeopleActions.new);

/// Changes to bills. Each one refreshes everything that shows bills.
class BillActions {
  BillActions(this._ref);

  final Ref _ref;

  void _changed() => _ref.read(dataRevisionProvider.notifier).bump();

  Future<BillRecord> save(BillDraft draft) async {
    final record = await _ref.read(billServiceProvider).save(draft);
    _changed();
    return record;
  }

  Future<void> delete(String billId) async {
    await _ref.read(billServiceProvider).delete(billId);
    _changed();
  }

  Future<void> rename(String billId, String title) async {
    await _ref.read(billRepositoryProvider).rename(billId, title);
    _changed();
  }

  Future<void> setSettled(String participantId, {required bool settled}) async {
    await _ref
        .read(billRepositoryProvider)
        .setSettled(
          participantId,
          settled: settled,
          at: _ref.read(clockProvider)(),
        );
    _changed();
  }

  /// Erases every bill, person, photo and setting.
  Future<void> deleteEverything() async {
    await _ref.read(appDatabaseProvider).wipe();
    await _ref.read(receiptStorageProvider).deleteAll();
    _ref.invalidate(settingsProvider);
    _changed();
  }
}

final billActionsProvider = Provider<BillActions>(BillActions.new);
