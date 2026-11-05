import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_container.dart';
import '../support/detail_helpers.dart';
import '../support/pump_app.dart';

Future<void> addViaSheet(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip('Add person'));
  await settle(tester);
  await tester.enterText(find.byType(TextField), name);
  await tester.tap(find.widgetWithText(FilledButton, 'Add person'));
  await settle(tester);
}

void main() {
  testWidgets('with nobody saved it explains and offers to add', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await pumpApp(tester, app, location: '/people');

    expect(find.text('You'), findsWidgets);
    expect(find.text('Your account'), findsOneWidget);
    expect(find.text('No one saved yet'), findsOneWidget);
    await screenshot(tester, 'people_empty');
  });

  testWidgets('adds a person and lists them', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await pumpApp(tester, app, location: '/people');

    await addViaSheet(tester, '  aarav   shah ');
    expect(find.text('aarav shah'), findsOneWidget);
    expect(find.text('Settled up'), findsOneWidget);
    expect(find.text('No one saved yet'), findsNothing);
  });

  testWidgets('rejects an empty or duplicate name with a message', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await addSavedPerson(tester, app, 'Priya');
    await pumpApp(tester, app, location: '/people');

    await addViaSheet(tester, '   ');
    expect(find.text('Enter a name'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'PRIYA');
    await tester.tap(find.widgetWithText(FilledButton, 'Add person'));
    await settle(tester);
    expect(find.text('That name is already on your list'), findsOneWidget);
  });

  testWidgets('shows what a person owes me, and what I owe them', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    final aarav = await addSavedPerson(tester, app, 'Aarav');
    final priya = await addSavedPerson(tester, app, 'Priya');
    await saveSharedBill(tester, app, aarav, id: 'a');
    await saveSharedBill(tester, app, priya, iPaid: false, id: 'b');
    await pumpApp(tester, app, location: '/people');

    expect(find.text('Owes you ₹50.00'), findsOneWidget);
    expect(find.text('You owe ₹50.00'), findsOneWidget);
    await screenshot(tester, 'people_balances');
  });

  testWidgets('a person page lists their bills and balance', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    final aarav = await addSavedPerson(tester, app, 'Aarav');
    await saveSharedBill(tester, app, aarav);
    await pumpApp(tester, app, location: '/people/${aarav.id}');

    expect(find.text('On 1 bill'), findsOneWidget);
    expect(find.text('Owes you ₹50.00'), findsOneWidget);
    expect(find.text('Dinner with Aarav'), findsOneWidget);
    await screenshot(tester, 'person_detail');
  });

  testWidgets('renames a person; past bills keep the old name', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    final aarav = await addSavedPerson(tester, app, 'Aarav');
    await saveSharedBill(tester, app, aarav);
    await pumpApp(tester, app, location: '/people/${aarav.id}');

    await tester.tap(find.text('Edit name'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Aarav Mehta');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(find.text('Aarav Mehta'), findsWidgets);

    // The saved bill still says what it said when it was saved.
    await tester.tap(find.text('Dinner with Aarav'));
    await settle(tester);
    expect(find.text('Aarav'), findsWidgets);
    expect(find.text('Aarav Mehta'), findsNothing);
  });

  testWidgets('removing someone with no bills deletes them', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    final aarav = await addSavedPerson(tester, app, 'Aarav');
    await pumpApp(tester, app, location: '/people');
    await tester.tap(find.text('Aarav'));
    await settle(tester);

    await tester.tap(find.text('Remove from People'));
    await settle(tester);
    expect(find.textContaining('not on any bills'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await settle(tester);

    expect(find.text('Aarav'), findsNothing);
    expect(find.text('No one saved yet'), findsOneWidget);
    expect(aarav.name, 'Aarav');
  });

  testWidgets('removing someone on past bills keeps those bills intact', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    final aarav = await addSavedPerson(tester, app, 'Aarav');
    await saveSharedBill(tester, app, aarav);
    await pumpApp(tester, app, location: '/people');
    await tester.tap(find.text('Aarav'));
    await settle(tester);

    await tester.tap(find.text('Remove from People'));
    await settle(tester);
    expect(find.textContaining('stay on the 1 past bill'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await settle(tester);

    // Hidden from the list, but the bill and its balance are untouched.
    expect(find.text('No one saved yet'), findsOneWidget);
    await tester.tap(find.text('Bills'));
    await settle(tester);
    expect(find.text('Dinner with Aarav'), findsOneWidget);
  });

  testWidgets('the account holder cannot be removed', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await pumpApp(tester, app, location: '/people');
    await tester.tap(find.text('Your account'));
    await settle(tester);
    expect(find.text('Remove from People'), findsNothing);
    expect(find.text('Edit name'), findsOneWidget);
  });
}
