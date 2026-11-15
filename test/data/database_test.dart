import 'dart:io';

import 'package:divvy/data/database/schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/test_database.dart';

Future<List<String>> tableNames(dynamic db) async {
  final rows = await (db as dynamic).rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' "
    "AND name NOT LIKE 'sqlite_%' ORDER BY name",
  ) as List<Map<String, Object?>>;
  return [for (final r in rows) r['name']! as String];
}

void main() {
  group('schema', () {
    test('creates every table and seeds the account holder', () async {
      final app = await openTestDatabase();
      expect(await tableNames(app.db), [
        'bill_adjustments',
        'bill_items',
        'bill_participants',
        'bills',
        'item_allocations',
        'people',
        'settings',
      ]);

      final people = await app.db.query('people');
      expect(people, hasLength(1));
      expect(people.single['name'], 'You');
      expect(people.single['is_self'], 1);
      await app.close();
    });

    test('enforces foreign keys', () async {
      final app = await openTestDatabase();
      expect(
        () => app.db.insert('bill_participants', {
          'id': 'x',
          'bill_id': 'no-such-bill',
          'name': 'Ghost',
          'initials': 'G',
          'color_index': 0,
          'position': 0,
          'subtotal': 0,
          'total': 0,
        }),
        throwsA(isA<DatabaseException>()),
      );
      await app.close();
    });

    test('allows only one account holder', () async {
      final app = await openTestDatabase();
      expect(
        () => app.db.insert('people', {
          'id': 'second-self',
          'name': 'Me too',
          'color_index': 0,
          'is_self': 1,
          'created_at': '2026-11-05T00:00:00.000Z',
        }),
        throwsA(isA<DatabaseException>()),
      );
      await app.close();
    });
  });

  group('persistence', () {
    late Directory dir;
    setUp(() => dir = makeTempDir('divvy_db_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('data survives closing and reopening the database', () async {
      final path = p.join(dir.path, 'divvy.db');

      final first = await openTestDatabase(path: path);
      await first.db.insert('settings', {'key': 'currency', 'value': 'USD'});
      final selfId = (await first.db.query('people')).single['id'];
      await first.close();

      final second = await openTestDatabase(path: path);
      final settings = await second.db.query('settings');
      expect(settings.single['value'], 'USD');
      // Reopening must not seed a second account holder.
      final people = await second.db.query('people');
      expect(people, hasLength(1));
      expect(people.single['id'], selfId);
      await second.close();
    });
  });

  group('migrations', () {
    late Directory dir;
    setUp(() => dir = makeTempDir('divvy_mig_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('apply in order and keep existing data', () async {
      final path = p.join(dir.path, 'divvy.db');

      final v1 = await openTestDatabase(path: path);
      await v1.db.insert('settings', {'key': 'keep', 'value': 'me'});
      await v1.close();

      final v3 = await openTestDatabase(
        path: path,
        version: 3,
        migrationList: const [
          Migration(2, ['ALTER TABLE settings ADD COLUMN note TEXT']),
          Migration(3, ['CREATE TABLE extra (id TEXT PRIMARY KEY, note TEXT)']),
        ],
      );
      final kept = await v3.db.query('settings');
      expect(kept.single['value'], 'me');
      expect(kept.single.containsKey('note'), isTrue);
      expect(await tableNames(v3.db), contains('extra'));
      // The account holder is still the only person.
      expect(await v3.db.query('people'), hasLength(1));
      await v3.close();
    });

    test('a missing step fails loudly instead of being skipped', () async {
      final path = p.join(dir.path, 'divvy.db');
      await (await openTestDatabase(path: path)).close();

      expect(
        () => openTestDatabase(
          path: path,
          version: 3,
          migrationList: const [
            Migration(3, ['SELECT 1']),
          ],
        ),
        throwsA(anything),
      );
    });

    test(
      'a failing migration rolls back, leaving the old schema intact',
      () async {
        final path = p.join(dir.path, 'divvy.db');
        final v1 = await openTestDatabase(path: path);
        await v1.db.insert('settings', {'key': 'keep', 'value': 'me'});
        await v1.close();

        await expectLater(
          openTestDatabase(
            path: path,
            version: 2,
            migrationList: const [
              Migration(2, [
                'CREATE TABLE half_done (id TEXT)',
                'THIS IS NOT SQL',
              ]),
            ],
          ),
          throwsA(anything),
        );

        // Reopen at the old version: the data is there and the half-applied
        // table is not.
        final again = await openTestDatabase(path: path);
        expect(await tableNames(again.db), isNot(contains('half_done')));
        expect((await again.db.query('settings')).single['value'], 'me');
        await again.close();
      },
    );
  });

  test('wipe erases everything and re-creates the account holder', () async {
    final app = await openTestDatabase();
    await app.db.insert('settings', {'key': 'currency', 'value': 'GBP'});
    await app.db.insert('people', {
      'id': 'friend',
      'name': 'Friend',
      'color_index': 1,
      'is_self': 0,
      'created_at': '2026-11-05T00:00:00.000Z',
    });

    await app.wipe();

    expect(await app.db.query('settings'), isEmpty);
    final people = await app.db.query('people');
    expect(people, hasLength(1));
    expect(people.single['is_self'], 1);
    expect(people.single['name'], 'You');
    await app.close();
  });
}
