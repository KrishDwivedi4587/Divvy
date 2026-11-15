import 'dart:io';

import 'package:divvy/core/utils/ids.dart';
import 'package:divvy/data/database/app_database.dart';
import 'package:divvy/data/database/schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Hands out `id-1`, `id-2`, ... so tests can assert on exact ids.
IdGenerator sequentialIds([String prefix = 'id']) {
  var n = 0;
  return () => '$prefix-${++n}';
}

/// A fixed clock for tests.
Clock fixedClock([DateTime? at]) {
  final now = at ?? DateTime.utc(2026, 11, 5, 9, 30);
  return () => now;
}

bool _ffiReady = false;

/// Opens a real SQLite database on the development machine via FFI, so the
/// schema, foreign keys and transactions are exercised for real. With no
/// [path] the database is in memory and disappears when closed.
Future<AppDatabase> openTestDatabase({
  String? path,
  IdGenerator? newId,
  Clock? clock,
  int version = currentSchemaVersion,
  List<Migration> migrationList = migrations,
}) {
  if (!_ffiReady) {
    sqfliteFfiInit();
    _ffiReady = true;
  }
  return AppDatabase.open(
    path: path ?? inMemoryDatabasePath,
    factory: databaseFactoryFfi,
    newId: newId ?? sequentialIds('seed'),
    clock: clock ?? fixedClock(),
    version: version,
    migrationList: migrationList,
  );
}

/// A scratch directory that the caller should delete when done.
Directory makeTempDir(String prefix) =>
    Directory.systemTemp.createTempSync(prefix);
