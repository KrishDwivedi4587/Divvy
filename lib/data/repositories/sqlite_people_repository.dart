import 'package:sqflite/sqflite.dart';

import '../../core/utils/ids.dart';
import '../../features/people/domain/people_repository.dart';
import '../../features/people/domain/person_rules.dart';
import '../../features/people/domain/saved_person.dart';

/// How many neutral avatar tones exist. People are given tones in rotation.
const int avatarToneCount = 8;

class SqlitePeopleRepository implements PeopleRepository {
  SqlitePeopleRepository(this._db, {IdGenerator? newId, Clock? clock})
    : _newId = newId ?? newIdDefault,
      _clock = clock ?? systemClock;

  final Database _db;
  final IdGenerator _newId;
  final Clock _clock;

  static String newIdDefault() => newId();

  SavedPerson _fromRow(Map<String, Object?> row) {
    return SavedPerson(
      id: row['id']! as String,
      name: row['name']! as String,
      colorIndex: row['color_index']! as int,
      isSelf: (row['is_self']! as int) == 1,
      createdAt: DateTime.parse(row['created_at']! as String),
      archivedAt: row['archived_at'] == null
          ? null
          : DateTime.parse(row['archived_at']! as String),
    );
  }

  @override
  Future<List<SavedPerson>> all({bool includeArchived = false}) async {
    final rows = await _db.query(
      'people',
      where: includeArchived ? null : 'archived_at IS NULL',
      orderBy: 'is_self DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<SavedPerson?> byId(String id) async {
    final rows = await _db.query('people', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  @override
  Future<SavedPerson> self() async {
    final rows = await _db.query('people', where: 'is_self = 1');
    return _fromRow(rows.single);
  }

  /// Names already taken by active people, optionally ignoring one person.
  Future<List<String>> _activeNames({String? except}) async {
    final rows = await _db.query(
      'people',
      columns: ['name'],
      where: except == null
          ? 'archived_at IS NULL'
          : 'archived_at IS NULL AND id != ?',
      whereArgs: except == null ? null : [except],
    );
    return rows.map((r) => r['name']! as String).toList();
  }

  @override
  Future<PersonResult> add(String name) async {
    final existing = await _activeNames();
    // The People list has no size limit; only a single bill does.
    final check = checkPersonName(name, existing, max: 1 << 20);
    if (check is NameRejected) return PersonRejected(check.reason);
    final tidy = (check as NameOk).name;

    // Re-adding someone who was archived restores them, so their history
    // stays linked rather than starting a second person with the same name.
    final archived = await _db.query(
      'people',
      where: 'archived_at IS NOT NULL AND name = ? COLLATE NOCASE',
      whereArgs: [tidy],
    );
    if (archived.isNotEmpty) {
      final id = archived.first['id']! as String;
      await _db.update(
        'people',
        {'archived_at': null, 'name': tidy},
        where: 'id = ?',
        whereArgs: [id],
      );
      return PersonSaved((await byId(id))!);
    }

    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM people'),
    )!;
    final id = _newId();
    await _db.insert('people', {
      'id': id,
      'name': tidy,
      'color_index': count % avatarToneCount,
      'is_self': 0,
      'created_at': _clock().toUtc().toIso8601String(),
    });
    return PersonSaved((await byId(id))!);
  }

  @override
  Future<PersonResult> rename(String id, String name) async {
    final existing = await _activeNames(except: id);
    final check = checkPersonName(name, existing, max: 1 << 20);
    if (check is NameRejected) return PersonRejected(check.reason);
    await _db.update(
      'people',
      {'name': (check as NameOk).name},
      where: 'id = ?',
      whereArgs: [id],
    );
    return PersonSaved((await byId(id))!);
  }

  @override
  Future<RemovalOutcome> remove(String id) async {
    final person = await byId(id);
    if (person == null) return RemovalOutcome.deleted;
    if (person.isSelf) return RemovalOutcome.refused;

    final bills = await billCount(id);
    if (bills == 0) {
      await _db.delete('people', where: 'id = ?', whereArgs: [id]);
      return RemovalOutcome.deleted;
    }
    await _db.update(
      'people',
      {'archived_at': _clock().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    return RemovalOutcome.archived;
  }

  @override
  Future<int> billCount(String id) async {
    return Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COUNT(DISTINCT bill_id) FROM bill_participants '
            'WHERE person_id = ?',
            [id],
          ),
        ) ??
        0;
  }
}
