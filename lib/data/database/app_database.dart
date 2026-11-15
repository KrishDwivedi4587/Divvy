import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/utils/ids.dart';
import 'schema.dart';

/// Owns the SQLite connection: opening it, creating and migrating the schema,
/// and seeding the account holder.
///
/// The [DatabaseFactory] is a parameter so the same code runs on a phone
/// (sqflite) and in tests on a development machine (sqflite_common_ffi).
class AppDatabase {
  AppDatabase._(this.db, this._newId, this._clock);

  final Database db;
  final IdGenerator _newId;
  final Clock _clock;

  /// The name given to the account holder until they change it.
  static const String defaultSelfName = 'You';

  /// Where the database lives on a device.
  static Future<String> defaultPath() async =>
      p.join(await getDatabasesPath(), 'divvy.db');

  /// Opens (creating if needed) the database at [path].
  ///
  /// Pass `inMemoryDatabasePath` for a throwaway database. [version] and
  /// [migrationList] exist so tests can exercise the upgrade path.
  static Future<AppDatabase> open({
    required String path,
    DatabaseFactory? factory,
    IdGenerator? newId,
    Clock? clock,
    int version = currentSchemaVersion,
    List<Migration> migrationList = migrations,
  }) async {
    final ids = newId ?? _defaultId;
    final now = clock ?? systemClock;
    final db = await (factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, v) async {
          await db.transaction((txn) async {
            for (final statement in schemaV1) {
              await txn.execute(statement);
            }
            await runMigrations(
              txn,
              from: 1,
              to: v,
              migrationList: migrationList,
            );
            await _seedSelf(txn, ids, now);
          });
        },
        onUpgrade: (db, from, to) async {
          await db.transaction((txn) async {
            await runMigrations(
              txn,
              from: from,
              to: to,
              migrationList: migrationList,
            );
          });
        },
      ),
    );
    return AppDatabase._(db, ids, now);
  }

  static String _defaultId() => newId();

  static Future<void> _seedSelf(
    DatabaseExecutor db,
    IdGenerator ids,
    Clock now,
  ) {
    return db.insert('people', {
      'id': ids(),
      'name': defaultSelfName,
      'color_index': 0,
      'is_self': 1,
      'created_at': now().toUtc().toIso8601String(),
    });
  }

  /// Applies each migration after [from], up to and including [to], in order.
  ///
  /// A missing step throws instead of being skipped: silently jumping a
  /// version is how an upgrade ends up with a half-migrated schema.
  static Future<void> runMigrations(
    DatabaseExecutor db, {
    required int from,
    required int to,
    required List<Migration> migrationList,
  }) async {
    for (var v = from + 1; v <= to; v++) {
      final matching = migrationList.where((m) => m.version == v).toList();
      if (matching.length != 1) {
        throw StateError(
          'Expected exactly one migration to schema version $v, '
          'found ${matching.length}.',
        );
      }
      for (final statement in matching.single.statements) {
        await db.execute(statement);
      }
    }
  }

  /// Erases every bill, person and setting, then re-creates the account holder
  /// with the default name. Used by "Delete all data".
  Future<void> wipe() async {
    await db.transaction((txn) async {
      // Children first; the foreign keys would cascade anyway, but this keeps
      // the intent obvious and does not rely on the pragma.
      for (final table in const [
        'item_allocations',
        'bill_adjustments',
        'bill_items',
        'bill_participants',
        'bills',
        'people',
        'settings',
      ]) {
        await txn.delete(table);
      }
      await _seedSelf(txn, _newId, _clock);
    });
  }

  Future<void> close() => db.close();
}
