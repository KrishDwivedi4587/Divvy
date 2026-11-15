import 'package:divvy/features/receipt_scanning/domain/receipt_photo_source.dart';
import 'package:divvy/shared/providers/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'app_container.dart';
import 'pump_app.dart';
import 'receipt_fixtures.dart';

/// The sample receipt photo, as an absolute path a picker would return.
final String receiptPhoto = p.absolute(
  'test/fixtures/receipts/spice_table_photo.jpg',
);

/// An app whose camera, gallery and recogniser return what is given. The
/// recogniser reads the Spice Table sample unless told otherwise.
///
/// A photo is read automatically, as in the real app. Pass `autoRead: false`
/// to test the path where the user starts the reading themselves.
Future<TestApp> appWith(
  WidgetTester tester, {
  PhotoResult camera = const PhotoCancelled(),
  PhotoResult gallery = const PhotoCancelled(),
  FakeTextRecognizer? recognizer,
  bool autoRead = true,
}) async {
  return (await tester.runAsync(() async {
    final app = await makeApp(
      photos: FakePhotoSource(camera: camera, gallery: gallery),
      recognizer: recognizer ?? FakeTextRecognizer(result: layout(spiceTable)),
    );
    if (!autoRead) {
      // Wait for the stored settings to load first, or they would replace the
      // change when they arrive.
      await app.container.read(settingsProvider.future);
      await app.container
          .read(settingsProvider.notifier)
          .setAutoReadReceipts(false);
    }
    return app;
  }))!;
}

/// Home, then New bill, as a user gets to the first step.
Future<void> openNewBill(WidgetTester tester, TestApp app) async {
  await pumpApp(tester, app);
  await tester.tap(find.widgetWithText(FilledButton, 'New bill'));
  await settle(tester);
}

/// Types a name into the Add People field and presses Return, as a user does.
Future<void> addPersonByTyping(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextField).first, name);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await settle(tester);
}

/// Taps the bottom action button by its label.
Future<void> tapFooter(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await settle(tester);
}

/// Opens the manual-entry review step directly.
Future<TestApp> openManualReview(WidgetTester tester) async {
  final app = await appWith(tester);
  await openNewBill(tester, app);
  await tester.tap(find.text('Enter details manually'));
  await settle(tester);
  return app;
}

/// Adds an item through the editor sheet.
Future<void> addItemByHand(
  WidgetTester tester, {
  required String name,
  String qty = '1',
  required String price,
}) async {
  await tester.tap(find.text('Add item'));
  await settle(tester);
  final fields = sheetFields();
  await tester.enterText(fields.at(0), name);
  await tester.enterText(fields.at(1), qty);
  await tester.enterText(fields.at(2), price);
  await tester.tap(find.widgetWithText(FilledButton, 'Add item'));
  await settle(tester);
}

/// The text fields inside the open bottom sheet (and not the screen behind it).
Finder sheetFields() => find.descendant(
  of: find.byType(BottomSheet),
  matching: find.byType(TextField),
);
