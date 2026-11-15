import 'package:divvy/features/bills/application/bill_draft_notifier.dart';
import 'package:divvy/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_container.dart';
import '../support/detail_helpers.dart';
import '../support/flow_helpers.dart';
import '../support/pump_app.dart';

/// Review with one item, on to the People step.
Future<TestApp> openPeopleStep(
  WidgetTester tester, {
  List<String> saved = const [],
}) async {
  final app = await appWith(tester);
  for (final name in saved) {
    await addSavedPerson(tester, app, name);
  }
  await openNewBill(tester, app);
  await tester.tap(find.text('Enter details manually'));
  await settle(tester);
  await addItemByHand(tester, name: 'Meal', price: '1000');
  await tapFooter(tester, 'Continue');
  return app;
}

void main() {
  testWidgets('starts with you on the bill and needs one more person', (
    tester,
  ) async {
    await openPeopleStep(tester);
    expect(find.text("Who's splitting?"), findsOneWidget);
    expect(find.text('1 of 12'), findsOneWidget);
    expect(
      find.text('Add at least 2 people to split the bill'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Return adds the name, clears the field and keeps going', (
    tester,
  ) async {
    final app = await openPeopleStep(tester);
    await addPersonByTyping(tester, '  aarav  shah ');

    expect(find.text('aarav shah'), findsOneWidget);
    expect(find.text('2 of 12'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, isEmpty);
    expect(app.container.read(billDraftProvider).participants, hasLength(2));
    // Two people: the bill can now be split.
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('the Add button does the same as Return', (tester) async {
    await openPeopleStep(tester);
    await tester.enterText(find.byType(TextField).first, 'Priya');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);
    expect(find.text('Priya'), findsOneWidget);
  });

  testWidgets('an empty name, a duplicate and a long name are refused', (
    tester,
  ) async {
    await openPeopleStep(tester);

    await addPersonByTyping(tester, '   ');
    expect(find.text('Enter a name'), findsOneWidget);

    await addPersonByTyping(tester, 'YOU');
    expect(find.text('That person is already on this bill'), findsOneWidget);

    await addPersonByTyping(tester, 'x' * 26);
    expect(find.text('Names can be up to 24 characters'), findsOneWidget);
    // Nothing was added by any of them.
    expect(find.text('1 of 12'), findsOneWidget);
  });

  testWidgets('typing a saved name adds that person, not a second copy', (
    tester,
  ) async {
    final app = await openPeopleStep(tester, saved: ['Priya']);
    await addPersonByTyping(tester, 'priya');

    final draft = app.container.read(billDraftProvider);
    expect(draft.participants.map((p) => p.name), ['You', 'Priya']);
    // Only one Priya exists in the People list.
    final people = await tester.runAsync(
      () => app.container.read(peopleRepositoryProvider).all(),
    );
    expect(people!.where((p) => p.name == 'Priya'), hasLength(1));
  });

  testWidgets('saved people can be added in one tap', (tester) async {
    final semantics = tester.ensureSemantics();
    await openPeopleStep(tester, saved: ['Aarav', 'Priya']);

    expect(find.text('FROM YOUR PEOPLE'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Add Aarav'));
    await settle(tester);
    expect(find.text('2 of 12'), findsOneWidget);
    // Once on the bill they are no longer offered.
    expect(find.bySemanticsLabel('Add Aarav'), findsNothing);
    expect(find.bySemanticsLabel('Add Priya'), findsOneWidget);
    await screenshot(tester, 'create_people_suggestions');
    semantics.dispose();
  });

  testWidgets('removing someone takes them off the bill', (tester) async {
    final app = await openPeopleStep(tester);
    await addPersonByTyping(tester, 'Aarav');
    await tester.tap(find.byTooltip('Remove Aarav'));
    await settle(tester);

    expect(find.byTooltip('Remove Aarav'), findsNothing);
    expect(find.text('1 of 12'), findsOneWidget);
    expect(app.container.read(billDraftProvider).participants, hasLength(1));
  });

  testWidgets('stops at twelve people', (tester) async {
    await openPeopleStep(tester);
    for (var i = 1; i < 12; i++) {
      await addPersonByTyping(tester, 'Person $i');
    }
    expect(find.text('12 of 12'), findsOneWidget);

    final add = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add'),
    );
    expect(add.onPressed, isNull);
    await addPersonByTyping(tester, 'One more');
    expect(find.text('You can split between up to 12 people'), findsOneWidget);
  });
}
