import 'package:divvy/core/utils/currency.dart';
import 'package:divvy/data/database/app_database.dart';
import 'package:divvy/data/repositories/sqlite_bill_repository.dart';
import 'package:divvy/features/bills/domain/bill_draft.dart';
import 'package:divvy/features/bills/domain/bill_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/builders.dart';
import '../support/draft_builders.dart';
import '../support/test_database.dart';

void main() {
  late AppDatabase app;
  late SqliteBillRepository bills;

  setUp(() async {
    app = await openTestDatabase();
    bills = SqliteBillRepository(app.db);
  });
  tearDown(() => app.close());

  /// Saves one bill whose ids are made unique by the bill id.
  Future<void> add(
    String id,
    String merchant,
    DateTime date, {
    String priya = 'Priya',
  }) {
    final base = goldenDraft(suffix: '-$id');
    final d = base.copyWith(
      merchant: merchant,
      billDate: date,
      participants: [
        for (final x in base.participants)
          x.name == 'Priya'
              ? DraftParticipant(id: x.id, name: priya, colorIndex: 0)
              : x,
      ],
    );
    return bills.save(recordFrom(d, id: id));
  }

  Future<void> seed() async {
    await add('b1', 'The Spice Table', DateTime(2026, 10, 1));
    await add('b2', 'Cafe 50% Off_Day', DateTime(2026, 10, 20), priya: 'Meera');
    await add('b3', 'Biryani House', DateTime(2026, 11, 2));
  }

  Future<List<String>> ids(String q) async =>
      (await bills.list(query: q)).map((x) => x.id).toList();

  test('lists newest first with totals and participant names', () async {
    await seed();
    final all = await bills.list();
    expect(all.map((x) => x.id), ['b3', 'b2', 'b1']);
    expect(all.first.grandTotal, p(102533));
    expect(all.first.participantNames, ['Aarav', 'Priya', 'Zoya']);
    expect(all.first.currency, Currency.inr);
    expect(all.first.hasReceipt, isFalse);
  });

  test('searches the title, merchant and participant names', () async {
    await seed();
    expect(await ids('biryani'), ['b3']);
    expect(await ids('SPICE'), ['b1']);
    expect(await ids('meera'), ['b2']);
    expect(await ids('nothing matches'), isEmpty);
  });

  test('treats % and _ in a search literally', () async {
    await seed();
    expect(await ids('50%'), ['b2']);
    expect(await ids('_'), ['b2']);
    expect(await ids('%'), ['b2']);
  });

  test('filters by whether anyone still owes', () async {
    await seed();
    await bills.setSettled('priya-b1', settled: true, at: now);
    await bills.setSettled('zoya-b1', settled: true, at: now);

    Future<List<String>> byStatus(BillStatusFilter f) async =>
        (await bills.list(status: f)).map((x) => x.id).toList();

    expect(await byStatus(BillStatusFilter.settled), ['b1']);
    expect(await byStatus(BillStatusFilter.unsettled), ['b3', 'b2']);
    final all = await bills.list();
    expect(all.firstWhere((x) => x.id == 'b3').unsettledCount, 2);
    expect(all.firstWhere((x) => x.id == 'b1').isSettled, isTrue);
  });

  test('combines a search with a status filter', () async {
    await seed();
    final r = await bills.list(
      query: 'house',
      status: BillStatusFilter.settled,
    );
    expect(r, isEmpty);
  });

  test('limits the number returned', () async {
    await seed();
    expect(await bills.list(limit: 2), hasLength(2));
  });

  test('an empty database lists nothing', () async {
    expect(await bills.list(), isEmpty);
    expect(await bills.count(), 0);
  });
}
