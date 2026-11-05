import 'package:divvy/data/database/app_database.dart';
import 'package:divvy/data/repositories/sqlite_bill_repository.dart';
import 'package:divvy/features/bills/domain/models/bill_record.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('is empty before anything has happened', () async {
    expect(await bills.recentActivity(), isEmpty);
  });

  test('lists a saved bill', () async {
    await bills.save(recordFrom(goldenDraft(suffix: '-1'), id: 'b1'));
    final events = await bills.recentActivity();
    expect(events, hasLength(1));
    expect(events.single.kind, ActivityKind.billCreated);
    expect(events.single.billTitle, 'The Spice Table');
    expect(events.single.amount.value, 102533);
    expect(events.single.personName, isNull);
  });

  test('lists people paying back, newest first, but not the payer', () async {
    await bills.save(recordFrom(goldenDraft(suffix: '-1'), id: 'b1'));
    await bills.setSettled(
      'priya-1',
      settled: true,
      at: now.add(const Duration(hours: 1)),
    );
    await bills.setSettled(
      'zoya-1',
      settled: true,
      at: now.add(const Duration(hours: 2)),
    );

    final events = await bills.recentActivity();
    expect(events.map((e) => (e.kind, e.personName)), [
      (ActivityKind.paidBack, 'Zoya'),
      (ActivityKind.paidBack, 'Priya'),
      (ActivityKind.billCreated, null),
    ]);
    expect(events.first.amount.value, 32706);
    // Aarav paid the bill, so he never "paid back".
    expect(events.any((e) => e.personName == 'Aarav'), isFalse);
  });

  test('respects the limit', () async {
    await bills.save(recordFrom(goldenDraft(suffix: '-1'), id: 'b1'));
    await bills.save(recordFrom(goldenDraft(suffix: '-2'), id: 'b2'));
    expect(await bills.recentActivity(limit: 1), hasLength(1));
  });

  test('a deleted bill leaves the feed', () async {
    await bills.save(recordFrom(goldenDraft(suffix: '-1'), id: 'b1'));
    await bills.setSettled('priya-1', settled: true, at: now);
    await bills.delete('b1');
    expect(await bills.recentActivity(), isEmpty);
  });
}
