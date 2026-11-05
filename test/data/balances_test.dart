import 'package:divvy/core/utils/currency.dart';
import 'package:divvy/data/database/app_database.dart';
import 'package:divvy/data/repositories/sqlite_bill_repository.dart';
import 'package:divvy/data/repositories/sqlite_people_repository.dart';
import 'package:divvy/features/bills/domain/bill_draft.dart';
import 'package:divvy/features/bills/domain/models/bill_record.dart';
import 'package:divvy/features/people/domain/saved_person.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/draft_builders.dart';
import '../support/test_database.dart';

void main() {
  late AppDatabase app;
  late SqliteBillRepository bills;
  late SqlitePeopleRepository people;
  late SavedPerson me;
  late SavedPerson aarav;
  late SavedPerson priya;

  setUp(() async {
    app = await openTestDatabase();
    bills = SqliteBillRepository(app.db);
    people = SqlitePeopleRepository(app.db, newId: sequentialIds('person'));
    me = await people.self();
    aarav = (await people.add('Aarav') as PersonSaved).person;
    priya = (await people.add('Priya') as PersonSaved).person;
  });
  tearDown(() => app.close());

  /// A bill of [amount] paise split equally between me and one other person.
  /// Equal halves: each owes amount / 2.
  BillRecord pair(
    String id,
    SavedPerson other, {
    required bool iPaid,
    int amount = 10000,
    Currency currency = Currency.inr,
  }) {
    final d = BillDraft(
      billDate: DateTime(2026, 11, 5),
      currency: currency,
      merchant: id,
      items: [draftItem('item-$id', 'Meal', amount)],
      participants: [
        participant('me-$id', 'You', personId: me.id),
        participant('them-$id', other.name, personId: other.id),
      ],
      splitMode: SplitMode.equal,
      payerId: iPaid ? 'me-$id' : 'them-$id',
    );
    return recordFrom(d, id: id);
  }

  Future<Map<String, int>> net([Currency c = Currency.inr]) async => {
    for (final b in await bills.balances())
      if (b.net[c] != null) b.personId: b.net[c]!.value,
  };

  test('nobody owes anything on an empty history', () async {
    expect(await bills.balances(), isEmpty);
  });

  test('people owe me for bills I paid', () async {
    await bills.save(pair('b1', aarav, iPaid: true));
    expect(await net(), {aarav.id: 5000});
  });

  test('I owe the people who paid', () async {
    await bills.save(pair('b1', aarav, iPaid: false));
    expect(await net(), {aarav.id: -5000});
  });

  test('bills with the same person net off', () async {
    await bills.save(pair('b1', aarav, iPaid: true, amount: 10000)); // +5000
    await bills.save(pair('b2', aarav, iPaid: false, amount: 6000)); // -3000
    expect(await net(), {aarav.id: 2000});
  });

  test('marking someone paid clears what they owed', () async {
    await bills.save(pair('b1', aarav, iPaid: true));
    await bills.save(pair('b2', priya, iPaid: true));

    await bills.setSettled('them-b1', settled: true, at: now);

    expect(await net(), {priya.id: 5000});
    final aaravBalance = (await bills.balances()).where(
      (b) => b.personId == aarav.id,
    );
    expect(aaravBalance.every((b) => b.isSettled), isTrue);
  });

  test('currencies are kept apart, never added together', () async {
    await bills.save(pair('b1', aarav, iPaid: true));
    await bills.save(
      pair('b2', aarav, iPaid: true, amount: 4000, currency: Currency.usd),
    );
    expect(await net(), {aarav.id: 5000});
    expect(await net(Currency.usd), {aarav.id: 2000});
  });

  test('archived people still appear in balances', () async {
    await bills.save(pair('b1', aarav, iPaid: true));
    await people.remove(aarav.id);
    expect(await net(), {aarav.id: 5000});
  });

  test('a bill with people who were never saved is ignored', () async {
    final d = BillDraft(
      billDate: DateTime(2026, 11, 5),
      currency: Currency.inr,
      items: [draftItem('i', 'Meal', 10000)],
      participants: [
        participant('me', 'You', personId: me.id),
        participant('guest', 'Guest'),
      ],
      splitMode: SplitMode.equal,
      payerId: 'me',
    );
    await bills.save(recordFrom(d));
    expect(await bills.balances(), isEmpty);
  });

  test('history for one person lists only their bills', () async {
    await bills.save(pair('b1', aarav, iPaid: true));
    await bills.save(pair('b2', priya, iPaid: true));
    await bills.save(pair('b3', aarav, iPaid: false));

    final theirs = await bills.forPerson(aarav.id);
    expect(theirs.map((x) => x.id).toSet(), {'b1', 'b3'});
    expect(await bills.forPerson('nobody'), isEmpty);
  });
}
