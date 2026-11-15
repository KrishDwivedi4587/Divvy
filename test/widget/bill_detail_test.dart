import 'dart:io';

import 'package:divvy/data/repositories/local_receipt_storage.dart';
import 'package:divvy/data/repositories/sqlite_bill_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/app_container.dart';
import '../support/detail_helpers.dart';
import '../support/draft_builders.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('shows the total, who paid and each person share', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await saveGolden(tester, app);
    await pumpApp(tester, app, location: '/bills/bill-1');

    expect(find.text('₹1,025.33'), findsWidgets);
    expect(
      find.textContaining('Split by item · 3 people · Paid by Aarav'),
      findsOneWidget,
    );
    expect(find.text('2 people have not paid yet'), findsOneWidget);
    expect(find.text('₹349.15'), findsOneWidget);
    expect(find.text('₹349.12'), findsOneWidget);
    expect(find.text('₹327.06'), findsOneWidget);
    await screenshot(tester, 'bill_detail_top');
  });

  testWidgets('a person can be marked paid and unmarked', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await saveGolden(tester, app);
    await pumpApp(tester, app, location: '/bills/bill-1');

    expect(find.text('Mark as paid'), findsNWidgets(2));
    await tester.tap(find.text('Mark as paid').first);
    await settle(tester);
    expect(find.text('Paid back'), findsOneWidget);
    expect(find.text('1 person has not paid yet'), findsOneWidget);

    await tester.tap(find.text('Undo · marked paid'));
    await settle(tester);
    expect(find.text('Paid back'), findsNothing);
    expect(find.text('2 people have not paid yet'), findsOneWidget);
  });

  testWidgets('a person breakdown shows how the total was worked out', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await saveGolden(tester, app);
    await pumpApp(tester, app, location: '/bills/bill-1');

    await tester.tap(find.text('Zoya').first);
    await settle(tester);
    expect(find.text('Cold Coffee'), findsWidgets);
    expect(find.textContaining('Dal Makhani (1 of 3)'), findsOneWidget);
    expect(find.text('Service charge'), findsWidgets);
    await screenshot(tester, 'bill_detail_breakdown');
  });

  testWidgets('shows items, charges and totals', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await saveGolden(tester, app);
    await pumpApp(tester, app, location: '/bills/bill-1');

    await scrollTo(tester, find.text('TOTALS'));
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('₹930.00'), findsWidgets);
    expect(find.text('₹46.50'), findsWidgets);
    expect(find.text('₹48.83'), findsWidgets);
    await screenshot(tester, 'bill_detail_totals');
  });

  testWidgets('a receipt photo that has gone missing is explained', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await saveGolden(tester, app, receiptPath: 'receipts/bill-1.jpg');
    await pumpApp(tester, app, location: '/bills/bill-1');

    expect(find.text('RECEIPT'), findsOneWidget);
    expect(find.text("Couldn't show this photo"), findsOneWidget);
  });

  testWidgets('shows the stored receipt photo', (tester) async {
    final root = Directory.systemTemp.createTempSync('divvy_rec_');
    addTearDown(() => root.deleteSync(recursive: true));
    final app = (await tester.runAsync(() => makeApp(root: root)))!;
    await tester.runAsync(() async {
      final path = await LocalReceiptStorage(root).save(
        sourcePath: p.absolute('test/fixtures/receipts/spice_table_photo.jpg'),
        billId: 'bill-1',
      );
      await SqliteBillRepository(
        app.db.db,
      ).save(goldenDraft().toRecord(id: 'bill-1', now: now, receiptPath: path));
    });
    await pumpApp(tester, app, location: '/bills/bill-1');
    // Wait for the photo to actually decode, not just for the widget to exist.
    await waitUntil(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Image), findsWidgets);
    expect(find.text("Couldn't show this photo"), findsNothing);
    await screenshot(tester, 'bill_detail_receipt');
  });

  testWidgets('warns when the stored total no longer matches the items', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await saveGolden(tester, app);
    await tester.runAsync(
      () => app.db.db.update('bills', {'grand_total': 999}),
    );
    await pumpApp(tester, app, location: '/bills/bill-1');

    expect(find.textContaining("saved total doesn't match"), findsOneWidget);
    // The figures shown are the recalculated, correct ones.
    expect(find.text('₹1,025.33'), findsWidgets);
  });

  testWidgets('an unknown bill says so', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await pumpApp(tester, app, location: '/bills/nope');
    expect(find.text('Bill not found'), findsOneWidget);
  });
}
