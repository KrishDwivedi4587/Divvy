import 'package:divvy/features/account/domain/app_settings.dart';
import 'package:divvy/features/bills/application/bill_draft_notifier.dart';
import 'package:divvy/features/receipt_scanning/application/scan_notifier.dart';
import 'package:divvy/features/receipt_scanning/domain/receipt_photo_source.dart';
import 'package:divvy/features/receipt_scanning/domain/text_recognizer.dart';
import 'package:divvy/shared/providers/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_container.dart';
import '../support/flow_helpers.dart';
import '../support/pump_app.dart';
import '../support/receipt_fixtures.dart';

/// A photo is read as soon as it is chosen, and the screen moves on by itself.
void main() {
  testWidgets('a photo is read on its own and lands on the review', (
    tester,
  ) async {
    final app = await appWith(
      tester,
      camera: PhotoPicked(receiptPhoto, PhotoSource.camera),
    );
    await openNewBill(tester, app);

    await tester.tap(find.text('Take photo'));
    await waitForText(tester, 'Paneer Tikka');

    // No "Read receipt" tap, no total typed: the items and the total are there.
    expect(app.recognizer.requested, [receiptPhoto]);
    expect(find.text('Step 2 of 5 · Details'), findsOneWidget);
    expect(find.text('Butter Naan × 4'), findsOneWidget);
    final draft = app.container.read(billDraftProvider);
    expect(draft.items, isNotEmpty);
    expect(draft.statedTotal, isNotNull);
    expect(app.container.read(scanProvider), isA<ScanDone>());
  });

  testWidgets('while reading, the photo shows progress and cannot be changed', (
    tester,
  ) async {
    final app = await appWith(
      tester,
      camera: PhotoPicked(receiptPhoto, PhotoSource.camera),
      recognizer: FakeTextRecognizer(
        result: layout(spiceTable),
        delay: const Duration(seconds: 2),
      ),
    );
    await openNewBill(tester, app);

    await tester.tap(find.text('Take photo'));
    await settle(tester);

    // Still reading: the photo screen says so and the buttons are held.
    expect(find.text('Check the photo'), findsOneWidget);
    expect(find.text('Reading your receipt…'), findsOneWidget);
    expect(find.text('Reading the items, prices and totals…'), findsOneWidget);
    expect(app.container.read(scanProvider), isA<Scanning>());
    expect(
      tester
          .widget<OutlinedButton>(
            find.ancestor(
              of: find.text('Retake'),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await screenshot(tester, 'create_reading');

    // It finishes on its own and moves on.
    await tester.pump(const Duration(seconds: 3));
    await waitForText(tester, 'Paneer Tikka');
    expect(find.text('Step 2 of 5 · Details'), findsOneWidget);
  });

  testWidgets('going back to the photo does not read it a second time', (
    tester,
  ) async {
    final app = await appWith(
      tester,
      camera: PhotoPicked(receiptPhoto, PhotoSource.camera),
    );
    await openNewBill(tester, app);
    await tester.tap(find.text('Take photo'));
    await waitForText(tester, 'Paneer Tikka');

    await tester.pageBack();
    await settle(tester);

    expect(find.text('Check the photo'), findsOneWidget);
    // The button now offers a deliberate re-read instead.
    expect(find.text('Read again'), findsOneWidget);
    expect(app.recognizer.requested, hasLength(1));
  });

  testWidgets('a retake is read too, after confirming the replacement', (
    tester,
  ) async {
    final app = await appWith(
      tester,
      camera: PhotoPicked(receiptPhoto, PhotoSource.camera),
    );
    await openNewBill(tester, app);
    await tester.tap(find.text('Take photo'));
    await waitForText(tester, 'Paneer Tikka');
    await tester.pageBack();
    await settle(tester);

    // A different photo, so the reader has something new to look at.
    app.photos.camera = PhotoPicked('$receiptPhoto.retake', PhotoSource.camera);
    await tester.tap(find.text('Retake'));
    await settle(tester);

    // The earlier items would be replaced, so the user is asked first.
    expect(find.text('Read the receipt again?'), findsOneWidget);
    expect(app.recognizer.requested, hasLength(1));
    await tester.tap(find.widgetWithText(TextButton, 'Read again'));
    await waitUntil(tester, () => app.recognizer.requested.length == 2);
    await settle(tester);

    expect(app.recognizer.requested, [receiptPhoto, '$receiptPhoto.retake']);
  });

  testWidgets('when reading fails the bill can still be entered by hand', (
    tester,
  ) async {
    final app = await appWith(
      tester,
      camera: PhotoPicked(receiptPhoto, PhotoSource.camera),
      recognizer: FakeTextRecognizer(
        error: const TextRecognitionException('boom'),
      ),
    );
    await openNewBill(tester, app);

    await tester.tap(find.text('Take photo'));
    await waitForText(tester, 'Review');
    await settle(tester);

    // Not stuck on the photo and not thrown out of the bill.
    expect(find.text('Step 2 of 5 · Details'), findsOneWidget);
    expect(find.textContaining("couldn't read this photo"), findsOneWidget);
    expect(find.text('Add item'), findsOneWidget);
    expect(app.container.read(billDraftProvider).imagePath, receiptPhoto);
  });

  testWidgets('items the user already entered are not replaced silently', (
    tester,
  ) async {
    final app = await appWith(
      tester,
      camera: PhotoPicked(receiptPhoto, PhotoSource.camera),
    );
    await openNewBill(tester, app);
    // Enter something by hand first, then come back and add a photo.
    await tester.tap(find.text('Enter details manually'));
    await settle(tester);
    await addItemByHand(tester, name: 'Chai', price: '40');
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.text('Take photo'));
    await settle(tester);

    // Asked, and declined: the photo waits and the typed item is untouched.
    expect(find.text('Read the receipt again?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await settle(tester);
    expect(find.text('Check the photo'), findsOneWidget);
    expect(find.text('Read receipt'), findsOneWidget);
    expect(app.recognizer.requested, isEmpty);
    expect(app.container.read(billDraftProvider).items.single.name, 'Chai');
  });

  testWidgets('the Account switch turns automatic reading off and on', (
    tester,
  ) async {
    final app = await appWith(tester);
    await pumpApp(tester, app, location: '/account');
    expect(find.text('Read receipts automatically'), findsOneWidget);
    expect(
      (await tester.runAsync(
        () => app.container.read(settingsProvider.future),
      ))!.autoReadReceipts,
      isTrue,
    );

    await tester.tap(find.text('Read receipts automatically'));
    await settle(tester);

    expect(
      app.container.read(settingsProvider).value!,
      isA<AppSettings>().having((s) => s.autoReadReceipts, 'on', isFalse),
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });
}
