import 'package:divvy/features/bills/application/bill_draft_notifier.dart';
import 'package:divvy/features/receipt_scanning/domain/receipt_photo_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/flow_helpers.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('the first step offers camera, gallery and manual entry', (
    tester,
  ) async {
    final app = await appWith(tester);
    await openNewBill(tester, app);

    expect(find.text('Add the receipt'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Upload from gallery'), findsOneWidget);
    expect(find.text('Enter details manually'), findsOneWidget);
    expect(find.text('Step 1 of 5 · Receipt'), findsOneWidget);
    await screenshot(tester, 'create_source');
  });

  testWidgets('with auto-read off, a camera photo waits on the preview', (
    tester,
  ) async {
    final app = await appWith(
      tester,
      camera: PhotoPicked(receiptPhoto, PhotoSource.camera),
      autoRead: false,
    );
    await openNewBill(tester, app);

    await tester.tap(find.text('Take photo'));
    await settle(tester);

    expect(app.photos.cameraCalls, 1);
    expect(find.text('Check the photo'), findsOneWidget);
    expect(find.text('Read receipt'), findsOneWidget);
    expect(app.recognizer.requested, isEmpty);
    expect(find.text('Retake'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
    expect(app.container.read(billDraftProvider).imagePath, receiptPhoto);
    await waitUntil(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
    );
    await screenshot(tester, 'create_preview');
  });

  testWidgets('a photo from the gallery follows the same path', (tester) async {
    final app = await appWith(
      tester,
      gallery: PhotoPicked(receiptPhoto, PhotoSource.gallery),
      autoRead: false,
    );
    await openNewBill(tester, app);

    await tester.tap(find.text('Upload from gallery'));
    await settle(tester);

    expect(app.photos.galleryCalls, 1);
    expect(find.text('Check the photo'), findsOneWidget);
  });

  testWidgets('cancelling the camera stays put, quietly', (tester) async {
    final app = await appWith(tester);
    await openNewBill(tester, app);

    await tester.tap(find.text('Take photo'));
    await settle(tester);

    expect(find.text('Add the receipt'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    expect(find.text('Camera access is off'), findsNothing);
    expect(app.container.read(billDraftProvider).imagePath, isNull);
  });

  testWidgets('manual entry skips the photo and goes straight to review', (
    tester,
  ) async {
    final app = await appWith(tester);
    await openNewBill(tester, app);

    await tester.tap(find.text('Enter details manually'));
    await settle(tester);

    expect(find.text('Review'), findsWidgets);
    expect(find.text('Step 2 of 5 · Details'), findsOneWidget);
    expect(find.text('Receipt photo'), findsNothing);
    expect(find.textContaining('No items yet'), findsOneWidget);
  });
}
