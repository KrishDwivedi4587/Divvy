import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/ids.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/local_receipt_storage.dart';
import '../../data/repositories/sqlite_bill_repository.dart';
import '../../data/repositories/sqlite_people_repository.dart';
import '../../data/repositories/sqlite_settings_repository.dart';
import '../../features/account/domain/app_settings.dart';
import '../../features/bills/application/bill_service.dart';
import '../../features/bills/domain/bill_repository.dart';
import '../../features/bills/domain/receipt_storage.dart';
import '../../features/people/domain/people_repository.dart';
import '../../features/receipt_scanning/data/image_picker_photo_source.dart';
import '../../features/receipt_scanning/data/mlkit_text_recognizer.dart';
import '../../features/receipt_scanning/domain/receipt_parser.dart';
import '../../features/receipt_scanning/domain/receipt_photo_source.dart';
import '../../features/receipt_scanning/domain/text_recognizer.dart';

/// The opened database. `main` overrides this with the real one; tests
/// override it with an in-memory database.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider must be overridden'),
);

/// The folder bill photos live under.
final receiptRootProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('receiptRootProvider must be overridden'),
);

final clockProvider = Provider<Clock>((ref) => systemClock);
final idGeneratorProvider = Provider<IdGenerator>((ref) => newId);

final billRepositoryProvider = Provider<BillRepository>(
  (ref) => SqliteBillRepository(ref.watch(appDatabaseProvider).db),
);

final peopleRepositoryProvider = Provider<PeopleRepository>(
  (ref) => SqlitePeopleRepository(
    ref.watch(appDatabaseProvider).db,
    newId: ref.watch(idGeneratorProvider),
    clock: ref.watch(clockProvider),
  ),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SqliteSettingsRepository(ref.watch(appDatabaseProvider).db),
);

final receiptStorageProvider = Provider<ReceiptStorage>(
  (ref) => LocalReceiptStorage(ref.watch(receiptRootProvider)),
);

final billServiceProvider = Provider<BillService>(
  (ref) => BillService(
    bills: ref.watch(billRepositoryProvider),
    storage: ref.watch(receiptStorageProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final photoSourceProvider = Provider<ReceiptPhotoSource>(
  (ref) => ImagePickerPhotoSource(),
);

final textRecognizerProvider = Provider<ReceiptTextRecognizer>((ref) {
  final recognizer = MlKitTextRecognizer();
  ref.onDispose(recognizer.dispose);
  return recognizer;
});

final receiptParserProvider = Provider<ReceiptParser>(
  (ref) => const ReceiptParser(),
);
