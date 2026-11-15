import 'package:divvy/features/bills/application/bill_draft_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/detail_helpers.dart';
import '../support/flow_helpers.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('cannot continue until there is an item', (tester) async {
    await openManualReview(tester);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('adds an item by hand and the total follows', (tester) async {
    final app = await openManualReview(tester);

    await addItemByHand(tester, name: 'Masala Dosa', qty: '2', price: '180');

    expect(find.text('Masala Dosa × 2'), findsOneWidget);
    await scrollTo(tester, find.text('Total'));
    expect(find.text('₹180.00'), findsWidgets);
    final draft = app.container.read(billDraftProvider);
    expect(draft.items.single.quantity, 2);
    expect(draft.items.single.unitPrice.value, 9000);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNotNull);
    await screenshot(tester, 'review_manual');
  });

  testWidgets('the item editor explains each invalid entry', (tester) async {
    await openManualReview(tester);

    await tester.tap(find.text('Add item'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add item'));
    await settle(tester);
    expect(find.text('Enter the item name'), findsOneWidget);
    expect(find.text('Enter the price'), findsOneWidget);

    final fields = sheetFields();
    await tester.enterText(fields.at(0), 'Tea');
    await tester.enterText(fields.at(1), '0');
    await tester.enterText(fields.at(2), '12.5');
    await tester.tap(find.widgetWithText(FilledButton, 'Add item'));
    await settle(tester);
    expect(find.text('1 to 99'), findsOneWidget);
  });

  testWidgets('the price field only accepts a well-formed amount', (
    tester,
  ) async {
    await openManualReview(tester);
    await tester.tap(find.text('Add item'));
    await settle(tester);

    final price = sheetFields().at(2);
    await tester.enterText(price, 'abc-1,2.3.4567');
    final field = tester.widget<TextField>(price);
    // Letters and the minus are dropped; a comma is dropped, not guessed;
    // one decimal point and two decimal places survive.
    expect(field.controller!.text, '12.34');
  });

  testWidgets('edits and deletes an item', (tester) async {
    final app = await openManualReview(tester);
    await addItemByHand(tester, name: 'Tea', price: '20');

    await tester.tap(find.text('Tea'));
    await settle(tester);
    await tester.enterText(sheetFields().at(0), 'Masala Tea');
    await tester.enterText(sheetFields().at(2), '25.50');
    await tester.tap(find.widgetWithText(FilledButton, 'Save item'));
    await settle(tester);
    expect(find.text('Masala Tea'), findsOneWidget);
    expect(
      app.container.read(billDraftProvider).items.single.lineTotal.value,
      2550,
    );

    await tester.tap(find.text('Masala Tea'));
    await settle(tester);
    await tester.tap(find.text('Delete item'));
    await settle(tester);
    expect(find.text('Masala Tea'), findsNothing);
    expect(app.container.read(billDraftProvider).items, isEmpty);
  });

  testWidgets('adds a percentage tax and the total recalculates', (
    tester,
  ) async {
    final app = await openManualReview(tester);
    await addItemByHand(tester, name: 'Meal', price: '1000');

    await tester.tap(find.text('Add').last);
    await settle(tester);
    await tester.tap(find.text('Tax'));
    await settle(tester);
    await tester.tap(find.text('Percent (%)'));
    await settle(tester);
    await tester.enterText(sheetFields().at(1), '5');
    await tester.tap(find.widgetWithText(FilledButton, 'Add charge'));
    await settle(tester);

    expect(find.text('Tax · 5%'), findsOneWidget);
    await scrollTo(tester, find.text('Total'));
    expect(find.text('₹1,050.00'), findsWidgets);
    expect(
      app.container.read(billDraftProvider).reviewTotals().grand.value,
      105000,
    );
  });

  testWidgets('the charge editor rejects a zero, negative or huge rate', (
    tester,
  ) async {
    await openManualReview(tester);
    await addItemByHand(tester, name: 'Meal', price: '1000');
    await tester.tap(find.text('Add').last);
    await settle(tester);
    await tester.tap(find.text('Tip'));
    await settle(tester);
    await tester.tap(find.text('Percent (%)'));
    await settle(tester);

    final rate = sheetFields().at(1);
    Future<void> tryRate(String text) async {
      await tester.enterText(rate, text);
      await tester.tap(find.widgetWithText(FilledButton, 'Add charge'));
      await settle(tester);
    }

    await tryRate('0');
    expect(find.text('Enter a rate above 0'), findsOneWidget);
    await tryRate('150');
    expect(find.text('Cannot be more than 100'), findsOneWidget);
    await tryRate('');
    expect(find.text('Enter a percentage'), findsOneWidget);
  });

  testWidgets('a discount lowers the total', (tester) async {
    final app = await openManualReview(tester);
    await addItemByHand(tester, name: 'Meal', price: '1000');
    await tester.tap(find.text('Add').last);
    await settle(tester);
    await tester.tap(find.text('Discount').last);
    await settle(tester);
    await tester.enterText(sheetFields().at(1), '100');
    await tester.tap(find.widgetWithText(FilledButton, 'Add charge'));
    await settle(tester);

    expect(
      app.container.read(billDraftProvider).reviewTotals().grand.value,
      90000,
    );
    await scrollTo(tester, find.text('Total'));
    expect(find.text('₹900.00'), findsWidgets);
  });
}
