import 'package:divvy/features/bills/application/bill_draft_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_container.dart';
import '../support/detail_helpers.dart';
import '../support/flow_helpers.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('the four tabs switch and show their own screens', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await pumpApp(tester, app);
    expect(find.text('Split a bill'), findsOneWidget);

    await tester.tap(find.text('Bills'));
    await settle(tester);
    expect(find.text('Past bills'), findsOneWidget);

    await tester.tap(find.text('People'));
    await settle(tester);
    expect(find.text('Saved people'.toUpperCase()), findsOneWidget);

    await tester.tap(find.text('Account'));
    await settle(tester);
    expect(find.text('Preferences'.toUpperCase()), findsOneWidget);

    await tester.tap(find.text('Home'));
    await settle(tester);
    expect(find.text('Split a bill'), findsOneWidget);
  });

  testWidgets('the centre button starts a bill from any tab', (tester) async {
    final app = await appWith(tester);
    await pumpApp(tester, app, location: '/account');

    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await settle(tester);

    expect(find.text('Add the receipt'), findsOneWidget);
    // And it starts clean, with you on the bill.
    expect(app.container.read(billDraftProvider).participants, hasLength(1));
  });

  testWidgets('starting a second bill does not inherit the first', (
    tester,
  ) async {
    final app = await appWith(tester);
    await openNewBill(tester, app);
    await tester.tap(find.text('Enter details manually'));
    await settle(tester);
    await addItemByHand(tester, name: 'Left over', price: '10');
    expect(app.container.read(billDraftProvider).items, hasLength(1));

    // Leave the flow and begin again.
    await tester.pageBack();
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'New bill'));
    await settle(tester);

    expect(app.container.read(billDraftProvider).items, isEmpty);
  });

  testWidgets('a person page opens from the people tab and goes back', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await addSavedPerson(tester, app, 'Aarav');
    await pumpApp(tester, app, location: '/people');

    await tester.tap(find.text('Aarav'));
    await settle(tester);
    expect(find.text('Bills together'.toUpperCase()), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    expect(find.text('Saved people'.toUpperCase()), findsOneWidget);
  });

  testWidgets('an unknown address shows a page not found, with a way home', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await pumpApp(tester, app, location: '/no/such/page');

    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Go home'));
    await settle(tester);
    expect(find.text('Split a bill'), findsOneWidget);
  });

  testWidgets('the summary refuses to show an unfinished bill', (tester) async {
    final app = await appWith(tester);
    await pumpApp(tester, app, location: '/create/summary');

    expect(find.text('This bill is not finished'), findsOneWidget);
    expect(find.text('Save bill'), findsNothing);
  });

  testWidgets('the photo step without a photo explains itself', (tester) async {
    final app = await appWith(tester);
    await pumpApp(tester, app, location: '/create/preview');

    expect(find.text('No photo chosen'), findsOneWidget);
    expect(find.text('Read receipt'), findsNothing);
  });
}
