import 'dart:io';

import 'package:divvy/features/receipt_scanning/domain/receipt_photo_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/flow_helpers.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('a refused camera explains the fix, and gallery still works', (
    tester,
  ) async {
    final app = await appWith(
      tester,
      camera: const PhotoDenied(),
      gallery: PhotoPicked(receiptPhoto, PhotoSource.gallery),
    );
    await openNewBill(tester, app);

    await tester.tap(find.text('Take photo'));
    await settle(tester);

    expect(find.text('Camera access is off'), findsOneWidget);
    expect(find.textContaining('turn on Camera'), findsOneWidget);
    expect(find.text('Check the photo'), findsNothing);
    await screenshot(tester, 'create_camera_denied');

    // The library does not depend on the camera permission.
    await tester.tap(find.text('Upload from gallery'));
    await settle(tester);
    expect(find.text('Check the photo'), findsOneWidget);
  });

  testWidgets('a camera failure shows a plain message and can be retried', (
    tester,
  ) async {
    final app = await appWith(
      tester,
      camera: const PhotoFailed(
        "The camera isn't available on this device. "
        'Choose a photo from your library instead.',
      ),
    );
    await openNewBill(tester, app);

    await tester.tap(find.text('Take photo'));
    await settle(tester);
    expect(find.textContaining("camera isn't available"), findsOneWidget);

    // Not stuck: the buttons work again.
    app.photos.camera = PhotoPicked(receiptPhoto, PhotoSource.camera);
    await tester.tap(find.text('Take photo'));
    await settle(tester);
    expect(find.text('Check the photo'), findsOneWidget);
  });

  testWidgets('retake and replace swap the photo without leaving the step', (
    tester,
  ) async {
    final app = await appWith(
      tester,
      camera: PhotoPicked(receiptPhoto, PhotoSource.camera),
      gallery: PhotoPicked(receiptPhoto, PhotoSource.gallery),
    );
    await openNewBill(tester, app);
    await tester.tap(find.text('Take photo'));
    await settle(tester);

    await tester.tap(find.text('Retake'));
    await settle(tester);
    expect(app.photos.cameraCalls, 2);
    expect(find.text('Check the photo'), findsOneWidget);

    await tester.tap(find.text('Replace'));
    await settle(tester);
    expect(app.photos.galleryCalls, 1);
    expect(find.text('Check the photo'), findsOneWidget);
  });

  testWidgets('a photo that cannot be shown is explained, not blank', (
    tester,
  ) async {
    // A directory of its own, so tests running in parallel never share a file.
    final dir = Directory.systemTemp.createTempSync('divvy_broken_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final broken = File(p.join(dir.path, 'receipt.jpg'))
      ..writeAsBytesSync([1, 2, 3]);
    final app = await appWith(
      tester,
      camera: PhotoPicked(broken.path, PhotoSource.camera),
    );
    await openNewBill(tester, app);

    await tester.tap(find.text('Take photo'));
    await settle(tester);
    await waitUntil(
      tester,
      () => find.text("Couldn't show this photo").evaluate().isNotEmpty,
    );
    expect(find.text("Couldn't show this photo"), findsOneWidget);
    // And the user can still carry on by hand.
    expect(find.text('Skip, enter details by hand'), findsOneWidget);
  });

  testWidgets('a photo chosen then the camera refused later keeps the photo', (
    tester,
  ) async {
    final app = await appWith(
      tester,
      gallery: PhotoPicked(receiptPhoto, PhotoSource.gallery),
      camera: const PhotoDenied(),
    );
    await openNewBill(tester, app);
    await tester.tap(find.text('Upload from gallery'));
    await settle(tester);

    await tester.tap(find.text('Retake'));
    await settle(tester);

    // The first photo is still there and usable.
    expect(find.text('Camera access is off'), findsOneWidget);
    expect(find.text('Read receipt'), findsOneWidget);
  });
}
