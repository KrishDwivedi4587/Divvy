import 'dart:io';

import 'package:divvy/data/repositories/local_receipt_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/test_database.dart';

void main() {
  late Directory root;
  late Directory scratch;
  late LocalReceiptStorage storage;

  setUp(() {
    root = makeTempDir('divvy_root_');
    scratch = makeTempDir('divvy_src_');
    storage = LocalReceiptStorage(root);
  });
  tearDown(() {
    root.deleteSync(recursive: true);
    scratch.deleteSync(recursive: true);
  });

  File photo(String name, [List<int> bytes = const [1, 2, 3, 4]]) {
    final f = File(p.join(scratch.path, name))..writeAsBytesSync(bytes);
    return f;
  }

  test('copies a photo in and returns a relative path', () async {
    final rel = await storage.save(
      sourcePath: photo('IMG_1.JPG', [9, 8, 7]).path,
      billId: 'bill-1',
    );

    expect(rel, 'receipts/bill-1.jpg');
    expect(p.isAbsolute(rel), isFalse);
    final stored = await storage.resolve(rel);
    expect(stored, isNotNull);
    expect(File(stored!).readAsBytesSync(), [9, 8, 7]);
  });

  test('keeps the original when it copies', () async {
    final src = photo('a.png');
    await storage.save(sourcePath: src.path, billId: 'b');
    expect(src.existsSync(), isTrue);
  });

  test('leaves no partial file behind after saving', () async {
    await storage.save(sourcePath: photo('a.jpg').path, billId: 'b');
    final names = Directory(p.join(root.path, 'receipts'))
        .listSync()
        .map((e) => p.basename(e.path))
        .toList();
    expect(names, ['b.jpg']);
  });

  test('defaults to .jpg when the source has no extension', () async {
    final rel = await storage.save(
      sourcePath: photo('noextension').path,
      billId: 'b',
    );
    expect(rel, 'receipts/b.jpg');
  });

  test('fails clearly when the source photo is missing', () async {
    await expectLater(
      storage.save(sourcePath: p.join(scratch.path, 'gone.jpg'), billId: 'b'),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('resolve is null for a file that is not there', () async {
    expect(await storage.resolve('receipts/missing.jpg'), isNull);
  });

  test('deletes a photo, and deleting twice is harmless', () async {
    final rel = await storage.save(
      sourcePath: photo('a.jpg').path,
      billId: 'b',
    );
    expect(await storage.delete(rel), isTrue);
    expect(await storage.resolve(rel), isNull);
    expect(await storage.delete(rel), isFalse);
  });

  group('refuses unsafe paths', () {
    const unsafe = [
      '',
      '/etc/passwd',
      'C:/Windows/win.ini',
      '../outside.jpg',
      'receipts/../../outside.jpg',
      'other/bill.jpg',
      'receipts//bill.jpg',
    ];
    for (final path in unsafe) {
      test('"$path"', () async {
        // A file outside the receipts folder that a bad path must not reach.
        File(p.join(root.path, 'outside.jpg')).writeAsBytesSync([1]);
        expect(await storage.resolve(path), isNull);
        expect(await storage.delete(path), isFalse);
        expect(File(p.join(root.path, 'outside.jpg')).existsSync(), isTrue);
      });
    }
  });

  test('deleteAll removes every photo', () async {
    final a = await storage.save(sourcePath: photo('a.jpg').path, billId: 'a');
    final b = await storage.save(sourcePath: photo('b.jpg').path, billId: 'b');
    await storage.deleteAll();
    expect(await storage.resolve(a), isNull);
    expect(await storage.resolve(b), isNull);
    // And it is fine to call when there is nothing to delete.
    await storage.deleteAll();
  });
}
