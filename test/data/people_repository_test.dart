import 'package:divvy/data/database/app_database.dart';
import 'package:divvy/data/repositories/sqlite_bill_repository.dart';
import 'package:divvy/data/repositories/sqlite_people_repository.dart';
import 'package:divvy/features/people/domain/person_rules.dart';
import 'package:divvy/features/people/domain/saved_person.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/draft_builders.dart';
import '../support/test_database.dart';

void main() {
  late AppDatabase app;
  late SqlitePeopleRepository people;

  setUp(() async {
    app = await openTestDatabase();
    people = SqlitePeopleRepository(
      app.db,
      newId: sequentialIds('person'),
      clock: fixedClock(),
    );
  });
  tearDown(() => app.close());

  Future<SavedPerson> add(String name) async =>
      (await people.add(name) as PersonSaved).person;

  test('starts with only the account holder', () async {
    final all = await people.all();
    expect(all, hasLength(1));
    expect(all.single.isSelf, isTrue);
    expect(all.single.name, 'You');
    expect((await people.self()).id, all.single.id);
  });

  group('add', () {
    test(
      'saves a tidied name and lists people alphabetically after you',
      () async {
        await add('  Zoya   Khan ');
        await add('aarav');
        final names = (await people.all()).map((x) => x.name).toList();
        expect(names, ['You', 'aarav', 'Zoya Khan']);
      },
    );

    test('rejects empty, over-long and duplicate names', () async {
      await add('Priya');
      Future<NameCheckFailure> why(String n) async =>
          (await people.add(n) as PersonRejected).reason;

      expect(await why('   '), NameCheckFailure.empty);
      expect(await why('x' * 25), NameCheckFailure.tooLong);
      expect(await why('PRIYA'), NameCheckFailure.duplicate);
      expect(await why('you'), NameCheckFailure.duplicate);
    });

    test('gives people avatar tones in rotation', () async {
      final tones = <int>[];
      for (var i = 0; i < 9; i++) {
        tones.add((await add('P$i')).colorIndex);
      }
      expect(tones.every((t) => t >= 0 && t < avatarToneCount), isTrue);
      expect(tones.toSet().length, greaterThan(1));
    });
  });

  group('rename', () {
    test('changes the name but rejects a name already taken', () async {
      final a = await add('Aarav');
      await add('Priya');

      final ok = await people.rename(a.id, 'Aarav Shah');
      expect((ok as PersonSaved).person.name, 'Aarav Shah');

      final dup = await people.rename(a.id, 'priya');
      expect((dup as PersonRejected).reason, NameCheckFailure.duplicate);
    });

    test('lets someone change only the case of their own name', () async {
      final a = await add('aarav');
      final r = await people.rename(a.id, 'Aarav');
      expect((r as PersonSaved).person.name, 'Aarav');
    });

    test('lets the account holder rename themselves', () async {
      final me = await people.self();
      await people.rename(me.id, 'Krish');
      expect((await people.self()).name, 'Krish');
    });
  });

  group('remove', () {
    test('deletes someone who is on no bills', () async {
      final a = await add('Aarav');
      expect(await people.remove(a.id), RemovalOutcome.deleted);
      expect(await people.byId(a.id), isNull);
    });

    test('archives someone on past bills, keeping history linked', () async {
      final me = await people.self();
      final a = await add('Aarav');
      final bills = SqliteBillRepository(app.db);
      await bills.save(
        recordFrom(
          goldenDraft().copyWith(
            participants: [
              participant('me', 'You', personId: me.id),
              participant('a', 'Aarav', personId: a.id),
            ],
            allocations: {
              for (final k in ['paneer', 'dal', 'coffee', 'naan'])
                k: {'me', 'a'},
            },
            payerId: 'me',
          ),
        ),
      );

      expect(await people.billCount(a.id), 1);
      expect(await people.remove(a.id), RemovalOutcome.archived);

      // Hidden from pickers, but still there for history.
      expect((await people.all()).map((x) => x.id), isNot(contains(a.id)));
      final archived = await people.byId(a.id);
      expect(archived!.isArchived, isTrue);
      expect(
        (await people.all(includeArchived: true)).map((x) => x.id),
        contains(a.id),
      );

      // The saved bill still names them and still links to them.
      final saved = await bills.byId('bill-1');
      final onBill = saved!.participants.firstWhere((x) => x.name == 'Aarav');
      expect(onBill.personId, a.id);
    });

    test('re-adding an archived person restores them', () async {
      final me = await people.self();
      final a = await add('Aarav');
      await SqliteBillRepository(app.db).save(
        recordFrom(
          goldenDraft().copyWith(
            participants: [
              participant('me', 'You', personId: me.id),
              participant('a', 'Aarav', personId: a.id),
            ],
            allocations: {
              for (final k in ['paneer', 'dal', 'coffee', 'naan'])
                k: {'me', 'a'},
            },
            payerId: 'me',
          ),
        ),
      );
      await people.remove(a.id);

      final again = await add('aarav');
      expect(again.id, a.id);
      expect(again.isArchived, isFalse);
    });

    test('refuses to remove the account holder', () async {
      final me = await people.self();
      expect(await people.remove(me.id), RemovalOutcome.refused);
      expect(await people.byId(me.id), isNotNull);
    });
  });
}
