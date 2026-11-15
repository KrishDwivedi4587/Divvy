import 'package:divvy/data/repositories/sqlite_bill_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_container.dart';
import '../support/draft_builders.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('shows a welcome and an empty state with no bills', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await pumpApp(tester, app);

    expect(find.text('Split a bill'), findsOneWidget);
    expect(find.text('New bill'), findsWidgets);
    expect(find.text('No bills yet'), findsOneWidget);
    expect(find.text('Create your first bill'), findsOneWidget);
    // No fake data: nothing about balances or activity until there is some.
    expect(find.text('Owed to you'), findsNothing);
    expect(find.text('RECENT ACTIVITY'), findsNothing);
    await screenshot(tester, 'home_empty');
  });

  testWidgets('lists saved bills and opens one', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await tester.runAsync(() async {
      final bills = SqliteBillRepository(app.db.db);
      await bills.save(recordFrom(goldenDraft()));
    });
    await pumpApp(tester, app);

    expect(find.text('The Spice Table'), findsWidgets);
    expect(find.text('RECENT BILLS'), findsOneWidget);
    expect(find.text('RECENT ACTIVITY'), findsOneWidget);
    await screenshot(tester, 'home_populated');

    await tester.tap(find.text('The Spice Table').first);
    await settle(tester);
    expect(find.text('WHO OWES WHAT'), findsOneWidget);
  });
}
