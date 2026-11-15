import 'dart:io';

import 'package:divvy/data/repositories/local_receipt_storage.dart';
import 'package:divvy/data/repositories/sqlite_bill_repository.dart';
import 'package:divvy/features/bills/domain/bill_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/app_container.dart';
import '../support/draft_builders.dart';
import '../support/pump_app.dart';

Future<void> seed(WidgetTester tester, TestApp app) async {
  await tester.runAsync(() async {
    final bills = SqliteBillRepository(app.db.db);
    Future<void> add(String id, String merchant, DateTime date, String who) {
      final base = goldenDraft(suffix: '-$id');
      return bills.save(
        recordFrom(
          base.copyWith(
            merchant: merchant,
            billDate: date,
            participants: [
              for (final x in base.participants)
                x.name == 'Priya'
                    ? DraftParticipant(id: x.id, name: who, colorIndex: 0)
                    : x,
            ],
          ),
          id: id,
        ),
      );
    }

    await add('b1', 'The Spice Table', DateTime(2026, 10, 1), 'Priya');
    await add('b2', 'Cafe Mocha', DateTime(2026, 10, 20), 'Meera');
    await add('b3', 'Biryani House', DateTime(2026, 11, 2), 'Priya');
    await bills.setSettled('priya-b1', settled: true, at: now);
    await bills.setSettled('zoya-b1', settled: true, at: now);
  });
}

void main() {
  testWidgets('empty history offers to create a bill', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await pumpApp(tester, app, location: '/history');

    expect(find.text('Past bills'), findsOneWidget);
    expect(find.text('No bills yet'), findsOneWidget);
    // Search and filters only appear once there is something to search.
    expect(find.byType(TextField), findsNothing);
    await screenshot(tester, 'history_empty');
  });

  testWidgets('lists every bill, newest first', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await seed(tester, app);
    await pumpApp(tester, app, location: '/history');

    final order = ['Biryani House', 'Cafe Mocha', 'The Spice Table'];
    final tops = [
      for (final name in order) tester.getTopLeft(find.text(name)).dy,
    ];
    expect(tops, [...tops]..sort());
    // One on the filter chip, one on the settled bill.
    expect(find.text('Settled'), findsNWidgets(2));
    expect(find.text('2 unpaid'), findsNWidgets(2));
    await screenshot(tester, 'history_populated');
  });

  testWidgets('searches by merchant and by person', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await seed(tester, app);
    await pumpApp(tester, app, location: '/history');

    await tester.enterText(find.byType(TextField), 'biryani');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.text('Biryani House'), findsOneWidget);
    expect(find.text('Cafe Mocha'), findsNothing);

    await tester.enterText(find.byType(TextField), 'meera');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.text('Cafe Mocha'), findsOneWidget);
    expect(find.text('Biryani House'), findsNothing);
  });

  testWidgets('says so when nothing matches, and clearing restores', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await seed(tester, app);
    await pumpApp(tester, app, location: '/history');

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.text('No bills match'), findsOneWidget);
    await screenshot(tester, 'history_no_match');

    await tester.tap(find.byTooltip('Clear search'));
    await settle(tester);
    expect(find.text('No bills match'), findsNothing);
    expect(find.text('Biryani House'), findsOneWidget);
  });

  testWidgets('filters by settled and unsettled', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    final semantics = tester.ensureSemantics();
    await seed(tester, app);
    await pumpApp(tester, app, location: '/history');

    await tester.tap(find.bySemanticsLabel('Settled bills'));
    await settle(tester);
    expect(find.text('The Spice Table'), findsOneWidget);
    expect(find.text('Biryani House'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Unsettled bills'));
    await settle(tester);
    expect(find.text('The Spice Table'), findsNothing);
    expect(find.text('Biryani House'), findsOneWidget);
    expect(find.text('Cafe Mocha'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('sort and date range narrow and reorder the list', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await seed(tester, app);
    await pumpApp(tester, app, location: '/history');
    expect(find.byTooltip('Clear search'), findsNothing);

    Future<void> choose(List<String> options) async {
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await settle(tester);
      for (final o in options) {
        await tester.tap(find.text(o));
        await settle(tester);
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Show bills'));
      await settle(tester);
    }

    double top(String name) => tester.getTopLeft(find.text(name)).dy;

    // Oldest first reverses the order.
    await choose(['Oldest first']);
    expect(top('The Spice Table'), lessThan(top('Cafe Mocha')));
    expect(top('Cafe Mocha'), lessThan(top('Biryani House')));

    // The clock is 5 Nov, so 30 days reaches back to 6 Oct: the 1 Oct bill
    // drops out while the other two stay.
    await choose(['Last 30 days']);
    expect(find.text('The Spice Table'), findsNothing);
    expect(find.text('Cafe Mocha'), findsOneWidget);
    expect(find.text('Biryani House'), findsOneWidget);
    await screenshot(tester, 'history_filtered');

    // Nothing in range is explained, with a way back.
    await tester.enterText(find.byType(TextField), 'spice');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.text('No bills match'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await settle(tester);
    expect(find.text('The Spice Table'), findsOneWidget);
    expect(find.text('Biryani House'), findsOneWidget);
  });

  testWidgets('the filter sheet fits a small phone at 2x text', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await seed(tester, app);
    await pumpApp(
      tester,
      app,
      location: '/history',
      size: const Size(320, 568),
      textScale: 2,
    );
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await settle(tester);
    expect(find.text('Sort and filter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sheet can be reset to the default order', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await seed(tester, app);
    await pumpApp(tester, app, location: '/history');

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await settle(tester);
    expect(find.text('Reset'), findsNothing);
    await tester.tap(find.text('Highest amount'));
    await settle(tester);
    expect(find.text('Reset'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await settle(tester);
    expect(find.text('Reset'), findsNothing);
  });

  testWidgets('a bill with no photo gets a quiet placeholder, not a gap', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await seed(tester, app);
    await pumpApp(tester, app, location: '/history');

    // One placeholder per saved bill, none showing an error.
    expect(find.byIcon(Icons.receipt_long_outlined), findsNWidgets(3));
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
  });

  testWidgets('a bill with a receipt shows its photo as a thumbnail', (
    tester,
  ) async {
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
    await pumpApp(tester, app, location: '/history');
    // Wait for the photo to be decoded and painted, not merely for the widget.
    bool decoded() {
      final raw = find.byType(RawImage).evaluate();
      return raw.isNotEmpty &&
          (raw.single.renderObject! as RenderImage).image != null;
    }

    await waitUntil(tester, decoded);
    await tester.pump(const Duration(milliseconds: 100));
    expect(decoded(), isTrue, reason: 'the thumbnail should show the photo');
    // Give the decoder time to close the file before teardown deletes the
    // folder (Windows will not delete an open file).
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('Receipt saved'), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    await screenshot(tester, 'history_thumbnail');
  });

  testWidgets('a receipt that has gone missing falls back quietly', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await tester.runAsync(
      () => SqliteBillRepository(app.db.db).save(
        goldenDraft().toRecord(
          id: 'bill-1',
          now: now,
          receiptPath: 'receipts/gone.jpg',
        ),
      ),
    );
    await pumpApp(tester, app, location: '/history');

    // The row still opens and shows no error box at thumbnail size.
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    expect(find.text("Couldn't show this photo"), findsNothing);
  });

  testWidgets('tapping a bill opens it', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await seed(tester, app);
    await pumpApp(tester, app, location: '/history');

    await tester.tap(find.text('Cafe Mocha'));
    await settle(tester);
    expect(find.text('WHO OWES WHAT'), findsOneWidget);
    expect(find.text('Meera'), findsWidgets);
  });
}
