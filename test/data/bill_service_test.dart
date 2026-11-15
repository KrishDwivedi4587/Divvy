import 'dart:io';

import 'package:divvy/data/database/app_database.dart';
import 'package:divvy/data/repositories/local_receipt_storage.dart';
import 'package:divvy/data/repositories/sqlite_bill_repository.dart';
import 'package:divvy/features/bills/application/bill_service.dart';
import 'package:divvy/features/bills/domain/bill_draft.dart';
import 'package:divvy/features/bills/domain/bill_repository.dart';
import 'package:divvy/features/bills/domain/models/bill_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/draft_builders.dart';
import '../support/test_database.dart';

/// A repository whose save always fails, to prove the photo is cleaned up.
class FailingRepository extends SqliteBillRepository {
  FailingRepository(super.db);

  @override
  Future<void> save(BillRecord record) async {
    throw StateError('disk full');
  }
}

void main() {
  late AppDatabase app;
  late Directory root;
  late Directory scratch;
  late LocalReceiptStorage storage;
  late File photo;

  setUp(() async {
    app = await openTestDatabase();
    root = makeTempDir('divvy_root_');
    scratch = makeTempDir('divvy_src_');
    storage = LocalReceiptStorage(root);
    photo = File(p.join(scratch.path, 'receipt.jpg'))
      ..writeAsBytesSync([1, 2, 3]);
  });
  tearDown(() async {
    await app.close();
    root.deleteSync(recursive: true);
    scratch.deleteSync(recursive: true);
  });

  BillService service(BillRepository repo) => BillService(
    bills: repo,
    storage: storage,
    clock: fixedClock(now),
    newId: sequentialIds('bill'),
  );

  List<String> storedFiles() {
    final dir = Directory(p.join(root.path, 'receipts'));
    return dir.existsSync()
        ? dir.listSync().map((e) => p.basename(e.path)).toList()
        : [];
  }

  test('saves the bill and keeps its photo', () async {
    final bills = SqliteBillRepository(app.db);
    final saved = await service(bills)
        .save(goldenDraft().copyWith(imagePath: photo.path));

    expect(saved.id, 'bill-1');
    expect(saved.receiptPath, 'receipts/bill-1.jpg');
    expect(storedFiles(), ['bill-1.jpg']);

    final back = (await bills.byId('bill-1'))!;
    expect(back.receiptPath, 'receipts/bill-1.jpg');
    expect(await storage.resolve(back.receiptPath!), isNotNull);
  });

  test('saves a bill that has no photo', () async {
    final bills = SqliteBillRepository(app.db);
    final saved = await service(bills).save(goldenDraft());
    expect(saved.receiptPath, isNull);
    expect(storedFiles(), isEmpty);
  });

  test('refuses an incomplete bill without touching storage', () async {
    final bills = SqliteBillRepository(app.db);
    final incomplete = goldenDraft().copyWith(
      imagePath: photo.path,
      clearPayer: true,
    );

    await expectLater(
      service(bills).save(incomplete),
      throwsA(
        isA<BillNotSavable>().having(
          (e) => e.problems,
          'problems',
          contains(BillProblem.noPayer),
        ),
      ),
    );
    expect(await bills.count(), 0);
    expect(storedFiles(), isEmpty);
  });

  test('a failed save removes the photo it had already copied', () async {
    final failing = FailingRepository(app.db);
    await expectLater(
      service(failing).save(goldenDraft().copyWith(imagePath: photo.path)),
      throwsStateError,
    );
    expect(storedFiles(), isEmpty);
    expect(await SqliteBillRepository(app.db).count(), 0);
  });

  test('deleting a bill deletes its photo too', () async {
    final bills = SqliteBillRepository(app.db);
    final svc = service(bills);
    await svc.save(goldenDraft().copyWith(imagePath: photo.path));
    expect(storedFiles(), hasLength(1));

    await svc.delete('bill-1');
    expect(await bills.byId('bill-1'), isNull);
    expect(storedFiles(), isEmpty);
  });

  test('deleting a bill that does not exist is harmless', () async {
    await service(SqliteBillRepository(app.db)).delete('nope');
  });
}
