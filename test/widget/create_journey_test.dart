import 'dart:io';

import 'package:divvy/data/repositories/sqlite_bill_repository.dart';
import 'package:divvy/features/bills/application/bill_draft_notifier.dart';
import 'package:divvy/features/bills/domain/engine/settle.dart';
import 'package:divvy/features/receipt_scanning/domain/receipt_photo_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/app_container.dart';
import '../support/detail_helpers.dart';
import '../support/draft_builders.dart';
import '../support/flow_helpers.dart';
import '../support/pump_app.dart';
import '../support/receipt_fixtures.dart';

void main() {
  testWidgets('photo to saved bill, and it is still there after a restart', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('divvy_journey_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final dbPath = p.join(dir.path, 'divvy.db');
    final photos = FakePhotoSource(
      camera: PhotoPicked(receiptPhoto, PhotoSource.camera),
    );

    // ---- first run ------------------------------------------------------
    final app = (await tester.runAsync(
      () => makeApp(
        databasePath: dbPath,
        root: dir,
        photos: photos,
        recognizer: FakeTextRecognizer(result: layout(spiceTable)),
      ),
    ))!;
    await openNewBill(tester, app);

    // 1. Take a photo.
    await tester.tap(find.text('Take photo'));
    await settle(tester);
    expect(find.text('Check the photo'), findsOneWidget);

    // 2. Read it.
    await tester.tap(find.widgetWithText(FilledButton, 'Read receipt'));
    await waitForText(tester, 'Paneer Tikka');
    expect(find.text('Review'), findsWidgets);
    expect(find.text('Paneer Tikka'), findsOneWidget);
    expect(find.text('Butter Naan × 4'), findsOneWidget);
    await screenshot(tester, 'create_review');
    expect(find.text('Total does not match'), findsNothing);
    await scrollTo(tester, find.text('Total'));
    expect(find.text('₹1,025.33'), findsWidgets);
    await screenshot(tester, 'create_review_totals');

    // 3. Review is fine; continue to people.
    await tapFooter(tester, 'Continue');
    expect(find.text("Who's splitting?"), findsOneWidget);
    expect(find.text('You'), findsWidgets);
    await addPersonByTyping(tester, 'Aarav');
    await addPersonByTyping(tester, 'Priya');
    expect(find.text('3 of 12'), findsOneWidget);
    await screenshot(tester, 'create_people');

    // 4. Split by item: everyone shares everything.
    await tapFooter(tester, 'Continue');
    expect(find.text('Split the bill'), findsOneWidget);
    expect(find.text('Choose who shared this'), findsNWidgets(4));
    await tester.tap(find.text('Everyone shares all'));
    await settle(tester);
    expect(find.text('Choose who shared this'), findsNothing);
    await screenshot(tester, 'create_split');

    // 5. Summary, then save.
    await tapFooter(tester, 'See summary');
    expect(find.text('Summary'), findsWidgets);
    expect(find.text('₹1,025.33'), findsWidgets);
    await screenshot(tester, 'create_summary');

    final draft = app.container.read(billDraftProvider);
    final expected = computeSettlement(
      draft.toRecord(id: 'x', now: now).toEngineBill(),
    );
    final totalOfPeople = expected.perPerson.fold(
      0,
      (a, x) => a + x.total.value,
    );
    expect(totalOfPeople, 102533);

    await tester.tap(find.widgetWithText(FilledButton, 'Save bill'));
    await waitForText(tester, 'WHO OWES WHAT');

    // 6. We land on the saved bill, with the receipt and everyone's share.
    expect(find.text('WHO OWES WHAT'), findsOneWidget);
    expect(find.text('Bill saved'), findsOneWidget);
    expect(find.text('The Spice Table'), findsWidgets);
    expect(find.text('Aarav'), findsWidgets);

    final bills = SqliteBillRepository(app.db.db);
    final saved = await tester.runAsync(() => bills.list());
    expect(saved, hasLength(1));
    final record = await tester.runAsync(() => bills.byId(saved!.single.id));
    expect(record!.grandTotal.value, 102533);
    expect(record.participants.map((x) => x.name), ['You', 'Aarav', 'Priya']);
    expect(record.items, hasLength(4));
    expect(record.receiptPath, startsWith('receipts/'));
    expect(File(p.join(dir.path, record.receiptPath!)).existsSync(), isTrue);
    expect(record.ocrText, contains('Paneer Tikka'));

    // ---- "restart": close everything and open the same files again -------
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(app.db.close);
    app.container.dispose();

    final again = (await tester.runAsync(
      () => makeApp(databasePath: dbPath, root: dir),
    ))!;
    await pumpApp(tester, again, location: '/history');
    await waitForText(tester, 'The Spice Table');

    expect(find.text('The Spice Table'), findsOneWidget);
    expect(find.text('₹1,025.33'), findsOneWidget);
    await tester.tap(find.text('The Spice Table'));
    await waitForText(tester, 'WHO OWES WHAT');
    expect(find.text('RECEIPT'), findsOneWidget);
    await waitUntil(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
    );
    expect(find.text("Couldn't show this photo"), findsNothing);
  });
}
