import 'dart:io';

import 'package:divvy/data/database/app_database.dart';
import 'package:divvy/features/receipt_scanning/application/scan_notifier.dart';
import 'package:divvy/features/receipt_scanning/domain/receipt_photo_source.dart';
import 'package:divvy/features/receipt_scanning/domain/recognized_text.dart';
import 'package:divvy/features/receipt_scanning/domain/text_recognizer.dart';
import 'package:divvy/shared/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'draft_builders.dart';
import 'test_database.dart';

/// A recogniser that returns what it is told, or throws what it is told.
class FakeTextRecognizer implements ReceiptTextRecognizer {
  FakeTextRecognizer({this.result, this.error, this.delay});

  RecognizedText? result;
  Object? error;
  Duration? delay;
  final List<String> requested = [];

  @override
  Future<RecognizedText> recognize(String imagePath) async {
    requested.add(imagePath);
    if (delay != null) await Future<void>.delayed(delay!);
    if (error != null) throw error!;
    return result ?? RecognizedText.fromPlainText('');
  }

  @override
  Future<void> dispose() async {}
}

/// A camera/gallery that returns queued results.
class FakePhotoSource implements ReceiptPhotoSource {
  FakePhotoSource({
    this.camera = const PhotoCancelled(),
    this.gallery = const PhotoCancelled(),
  });

  PhotoResult camera;
  PhotoResult gallery;
  int cameraCalls = 0;
  int galleryCalls = 0;

  @override
  Future<PhotoResult> takePhoto() async {
    cameraCalls++;
    return camera;
  }

  @override
  Future<PhotoResult> pickFromGallery() async {
    galleryCalls++;
    return gallery;
  }
}

class TestApp {
  TestApp(this.db, this.root, this.container, this.recognizer, this.photos);

  final AppDatabase db;
  final Directory root;
  final ProviderContainer container;
  final FakeTextRecognizer recognizer;
  final FakePhotoSource photos;
}

/// Builds the whole app's providers over a real in-memory database, a temp
/// folder for photos, and fakes for the camera and recogniser.
Future<TestApp> makeApp({
  FakeTextRecognizer? recognizer,
  FakePhotoSource? photos,
  String? databasePath,
  Directory? root,
  Duration? scanTimeout,
}) async {
  final db = await openTestDatabase(path: databasePath);
  final dir = root ?? makeTempDir('divvy_app_');
  final fakeRecognizer = recognizer ?? FakeTextRecognizer();
  final fakePhotos = photos ?? FakePhotoSource();

  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      receiptRootProvider.overrideWithValue(dir),
      clockProvider.overrideWithValue(fixedClock(now)),
      idGeneratorProvider.overrideWithValue(sequentialIds('id')),
      textRecognizerProvider.overrideWithValue(fakeRecognizer),
      photoSourceProvider.overrideWithValue(fakePhotos),
      if (scanTimeout != null)
        scanTimeoutProvider.overrideWithValue(scanTimeout),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await db.close();
    if (root == null && dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return TestApp(db, dir, container, fakeRecognizer, fakePhotos);
}
