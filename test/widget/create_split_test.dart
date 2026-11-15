import 'package:divvy/features/bills/application/bill_draft_notifier.dart';
import 'package:divvy/features/bills/domain/models/bill_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:divvy/features/bills/presentation/create/split_item_card.dart';

import '../support/app_container.dart';
import '../support/detail_helpers.dart';
import '../support/flow_helpers.dart';
import '../support/pump_app.dart';

/// Two items (400 and 600), three people, on the Split step.
Future<TestApp> openSplitStep(WidgetTester tester) async {
  final app = await appWith(tester);
  await openNewBill(tester, app);
  await tester.tap(find.text('Enter details manually'));
  await settle(tester);
  await addItemByHand(tester, name: 'Paneer', price: '400');
  await addItemByHand(tester, name: 'Biryani', price: '600');
  await tapFooter(tester, 'Continue');
  await addPersonByTyping(tester, 'Aarav');
  await addPersonByTyping(tester, 'Priya');
  await tapFooter(tester, 'Continue');
  return app;
}

/// Taps [name] on the chip row of the [index]th item card, not the Paid by row.
Future<void> tapChip(WidgetTester tester, int index, String name) async {
  final chip = find.descendant(
    of: find.byType(SplitItemCard).at(index),
    matching: find.text(name),
  );
  // The card may be below the fold, as it would be for a user: scroll to it.
  await tester.ensureVisible(chip);
  await tester.pump();
  await tester.tap(chip);
  await tester.pump();
}

bool continueEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'See summary'))
        .onPressed !=
    null;

void main() {
  testWidgets('by item: unassigned items block the summary and are flagged', (
    tester,
  ) async {
    await openSplitStep(tester);

    expect(find.text('By item'), findsOneWidget);
    expect(find.text('Choose who shared this'), findsNWidgets(2));
    expect(find.text('Every item needs at least one person.'), findsOneWidget);
    expect(continueEnabled(tester), isFalse);
    await scrollTo(
      tester,
      find.textContaining('Some items are not assigned yet'),
    );
    expect(
      find.textContaining('Some items are not assigned yet'),
      findsOneWidget,
    );
  });

  testWidgets('assigning each item to someone unlocks the summary', (
    tester,
  ) async {
    final app = await openSplitStep(tester);
    final draft = app.container.read(billDraftProvider);
    final ids = {for (final p in draft.participants) p.name: p.id};

    // Paneer to Aarav; Biryani to You and Priya.
    await tapChip(tester, 0, 'Aarav');
    await settle(tester);
    expect(continueEnabled(tester), isFalse);
    await tapChip(tester, 1, 'You');
    await tapChip(tester, 1, 'Priya');
    await settle(tester);

    expect(continueEnabled(tester), isTrue);
    final after = app.container.read(billDraftProvider);
    expect(after.allocations[after.items.first.id], {ids['Aarav']});
    expect(after.allocations[after.items.last.id], {ids['You'], ids['Priya']});

    // Live totals: Aarav 400.00, You 300.00, Priya 300.00.
    expect(find.text('₹400.00'), findsWidgets);
    expect(find.text('₹300.00'), findsWidgets);
    await screenshot(tester, 'split_assigned');
  });

  testWidgets('the Everyone chip toggles all or none', (tester) async {
    final app = await openSplitStep(tester);
    final first = app.container.read(billDraftProvider).items.first.id;

    await tester.tap(find.text('Everyone').first);
    await settle(tester);
    expect(
      app.container.read(billDraftProvider).allocations[first],
      hasLength(3),
    );

    await tester.tap(find.text('Everyone').first);
    await settle(tester);
    expect(app.container.read(billDraftProvider).allocations[first], isEmpty);
  });

  testWidgets('equally: needs no assignment and shares evenly', (tester) async {
    final app = await openSplitStep(tester);
    await tester.tap(find.text('Equally'));
    await settle(tester);

    expect(app.container.read(billDraftProvider).splitMode, SplitMode.equal);
    expect(continueEnabled(tester), isTrue);
    // 1,000.00 between three: 333.34 / 333.33 / 333.33.
    expect(find.text('₹333.34'), findsOneWidget);
    expect(find.text('₹333.33'), findsNWidgets(2));
    await screenshot(tester, 'split_equal');
  });

  testWidgets('amounts: must add up, and says how far off it is', (
    tester,
  ) async {
    final app = await openSplitStep(tester);
    // A tall screen, so every field and message is on screen at once.
    tester.view.physicalSize = const Size(402, 1700) * 3;
    await tester.tap(find.text('Amounts'));
    await settle(tester);

    // Starts evenly spread, so it already adds up.
    expect(find.text('Everything is accounted for'), findsOneWidget);
    expect(continueEnabled(tester), isTrue);

    final fields = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '500');
    await settle(tester);
    expect(find.textContaining('Over by'), findsOneWidget);
    expect(continueEnabled(tester), isFalse);
    expect(
      find.text('The amounts must add up to the items total.'),
      findsOneWidget,
    );

    await tester.enterText(fields.at(0), '100');
    await settle(tester);
    expect(find.textContaining('Left to assign'), findsOneWidget);

    // "Split evenly" puts it right again.
    await tester.tap(find.text('Split evenly'));
    await settle(tester);
    expect(find.text('Everything is accounted for'), findsOneWidget);
    expect(continueEnabled(tester), isTrue);
    expect(
      app.container
          .read(billDraftProvider)
          .customAmounts
          .values
          .fold(0, (a, v) => a + v.value),
      100000,
    );
    await screenshot(tester, 'split_custom');
  });

  testWidgets('the payer can be changed', (tester) async {
    final semantics = tester.ensureSemantics();
    final app = await openSplitStep(tester);
    final before = app.container.read(billDraftProvider);
    expect(before.payerId, before.participants.first.id);

    await tester.tap(find.bySemanticsLabel('Paid by Priya'));
    await settle(tester);
    final after = app.container.read(billDraftProvider);
    expect(after.payerId, after.participants.last.id);
    semantics.dispose();
  });

  testWidgets('continuing reaches the summary', (tester) async {
    await openSplitStep(tester);
    await tester.tap(find.text('Equally'));
    await settle(tester);
    await tapFooter(tester, 'See summary');
    expect(find.text('Step 5 of 5 · Save'), findsOneWidget);
  });
}
