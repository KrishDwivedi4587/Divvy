import 'package:divvy/data/repositories/sqlite_bill_repository.dart';
import 'package:divvy/features/bills/domain/bill_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
