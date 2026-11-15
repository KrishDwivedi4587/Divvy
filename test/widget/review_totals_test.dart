import 'package:divvy/features/bills/application/bill_draft_notifier.dart';
import 'package:divvy/features/bills/domain/engine/money.dart';
import 'package:divvy/features/bills/domain/models/bill.dart';
import 'package:divvy/features/receipt_scanning/domain/receipt_photo_source.dart';
import 'package:divvy/features/receipt_scanning/domain/recognized_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_container.dart';
import '../support/detail_helpers.dart';
import '../support/flow_helpers.dart';
import '../support/pump_app.dart';

Future<TestApp> readReceipt(WidgetTester tester, List<String> lines) async {
  final app = await appWith(
    tester,
    camera: PhotoPicked(receiptPhoto, PhotoSource.camera),
    recognizer: FakeTextRecognizer(
      result: RecognizedText.fromPlainText(lines.join('\n')),
    ),
  );
  await openNewBill(tester, app);
  await tester.tap(find.text('Take photo'));
  await waitForText(tester, 'Review');
  await settle(tester);
  return app;
}

Paise paise(int v) => Paise(v);

/// Correcting the total on the review step: the receipt's own total is
/// compared with the items, and the user decides what to do about a gap.
void main() {
  testWidgets('a matching total shows a tick and no warning', (tester) async {
    await readReceipt(tester, [
      'Dhaba',
      'Thali 500.00',
      'Lassi 100.00',
      'Total 600.00',
    ]);

    expect(find.text('Total does not match'), findsNothing);
    expect(find.text('More than one total found'), findsNothing);
    await scrollTo(tester, find.text('Printed on receipt'));
    expect(find.text('Printed on receipt'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsWidgets);
  });

  testWidgets('a gap can be added as a charge, and the warning clears', (
    tester,
  ) async {
    final app = await readReceipt(tester, [
      'Dhaba',
      'Thali 500.00',
      'Lassi 100.00',
      'Total 650.00',
    ]);
    expect(find.text('Total does not match'), findsOneWidget);
    expect(find.text('Add ₹50.00 as a charge'), findsOneWidget);
    await screenshot(tester, 'review_total_mismatch');

    await tester.tap(find.text('Add ₹50.00 as a charge'));
    await settle(tester);

    expect(find.text('Total does not match'), findsNothing);
    final draft = app.container.read(billDraftProvider);
    expect(draft.adjustments, hasLength(1));
    expect(draft.adjustments.single.value, 5000);
    expect(draft.adjustments.single.isNegative, isFalse);
    expect(draft.reviewTotals().grand, paise(65000));
  });

  testWidgets(
    'an overshoot is offered as a discount, never a negative charge',
    (tester) async {
      final app = await readReceipt(tester, [
        'Dhaba',
        'Thali 500.00',
        'Lassi 100.00',
        'Total 540.00',
      ]);
      expect(find.text('Add ₹60.00 as a discount'), findsOneWidget);

      await tester.tap(find.text('Add ₹60.00 as a discount'));
      await settle(tester);

      final a = app.container.read(billDraftProvider).adjustments.single;
      expect(a.kind, AdjustmentKind.discount);
      expect(a.isNegative, isTrue);
      expect(a.value, 6000);
    },
  );

  testWidgets('a small gap is labelled as a round off', (tester) async {
    final app = await readReceipt(tester, [
      'Dhaba',
      'Thali 500.00',
      'Lassi 100.00',
      'Total 600.40',
    ]);
    await tester.tap(find.text('Add ₹0.40 as a charge'));
    await settle(tester);

    expect(
      app.container.read(billDraftProvider).adjustments.single.label,
      'Round off',
    );
  });

  testWidgets('the receipt total can be corrected by hand', (tester) async {
    final app = await readReceipt(tester, [
      'Dhaba',
      'Thali 500.00',
      'Lassi 100.00',
      'Total 650.00',
    ]);

    await tester.tap(find.text('Correct receipt total'));
    await settle(tester);
    await tester.enterText(sheetFields().first, '600');
    await tester.tap(find.widgetWithText(FilledButton, 'Save total'));
    await settle(tester);

    expect(app.container.read(billDraftProvider).statedTotal, paise(60000));
    expect(find.text('Total does not match'), findsNothing);
  });

  testWidgets('a bad total is explained and nothing is saved', (tester) async {
    final app = await readReceipt(tester, [
      'Dhaba',
      'Thali 500.00',
      'Total 650.00',
    ]);
    await tester.tap(find.text('Correct receipt total'));
    await settle(tester);
    await tester.enterText(sheetFields().first, '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Save total'));
    await settle(tester);

    expect(find.text('Enter an amount above zero'), findsOneWidget);
    expect(app.container.read(billDraftProvider).statedTotal, paise(65000));
  });

  testWidgets('with two possible totals the user chooses', (tester) async {
    final app = await readReceipt(tester, [
      'Dhaba',
      'Thali 500.00',
      'Total 700.00',
      'Total 900.00',
    ]);
    expect(find.text('More than one total found'), findsOneWidget);
    expect(find.text('₹700.00'), findsOneWidget);
    await screenshot(tester, 'review_multiple_totals');

    await tester.tap(find.widgetWithText(InkWell, '₹700.00').first);
    await settle(tester);

    // Asked once: the choice is kept and the question goes away.
    expect(find.text('More than one total found'), findsNothing);
    expect(app.container.read(billDraftProvider).statedTotal, paise(70000));
  });

  testWidgets('with no total on the receipt, one can be entered', (
    tester,
  ) async {
    final app = await readReceipt(tester, [
      'Dhaba',
      'Thali 500.00',
      'Lassi 100.00',
    ]);
    expect(find.text('Enter receipt total'), findsOneWidget);
    expect(app.container.read(billDraftProvider).statedTotal, isNull);

    await tester.tap(find.text('Enter receipt total'));
    await settle(tester);
    await tester.enterText(sheetFields().first, '600.00');
    await tester.tap(find.widgetWithText(FilledButton, 'Save total'));
    await settle(tester);

    expect(app.container.read(billDraftProvider).statedTotal, paise(60000));
    expect(find.text('Total does not match'), findsNothing);
  });

  testWidgets('the notices and the total sheet fit a small phone at 2x text', (
    tester,
  ) async {
    final app = await appWith(
      tester,
      camera: PhotoPicked(receiptPhoto, PhotoSource.camera),
      recognizer: FakeTextRecognizer(
        result: RecognizedText.fromPlainText(
          ['Thali 500.00', 'Total 700.00', 'Total 900.00'].join('\n'),
        ),
      ),
    );
    // An overflow is a framework exception, which fails the test.
    await pumpApp(
      tester,
      app,
      location: '/create',
      size: const Size(320, 568),
      textScale: 2,
    );
    // At this size the option sits below the fold.
    await scrollTo(tester, find.text('Take photo'));
    await tester.tap(find.text('Take photo'));
    await waitForText(tester, 'Review');
    await settle(tester);
    await scrollTo(tester, find.text('More than one total found'));
    expect(find.text('More than one total found'), findsOneWidget);

    await scrollTo(tester, find.widgetWithText(InkWell, '₹700.00').first);
    await tester.tap(find.widgetWithText(InkWell, '₹700.00').first);
    await settle(tester);
    await scrollTo(tester, find.text('Correct receipt total'));
    await tester.tap(find.text('Correct receipt total'));
    await settle(tester);
    expect(find.text('Receipt total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing merchant and date are named, not invented', (
    tester,
  ) async {
    await readReceipt(tester, ['Thali 500.00', 'Lassi 100.00', 'Total 600.00']);
    expect(
      find.textContaining("couldn't find the merchant or the date"),
      findsOneWidget,
    );
  });
}
