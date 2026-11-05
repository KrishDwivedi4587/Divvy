import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_container.dart';
import '../support/detail_helpers.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('copies a summary to the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final app = (await tester.runAsync(makeApp))!;
    await saveGolden(tester, app);
    await pumpApp(tester, app, location: '/bills/bill-1');

    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.text('Copy summary'));
    await settle(tester);

    expect(copied, contains('Divvy · The Spice Table'));
    expect(copied, contains('Zoya: ₹327.06'));
    expect(find.text('Summary copied'), findsOneWidget);
  });

  testWidgets('renames a bill', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await saveGolden(tester, app);
    await pumpApp(tester, app, location: '/bills/bill-1');

    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.text('Rename'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Anniversary dinner');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('Anniversary dinner'), findsWidgets);
  });

  testWidgets('renaming to nothing keeps the old name', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await saveGolden(tester, app);
    await pumpApp(tester, app, location: '/bills/bill-1');

    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.text('Rename'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('The Spice Table'), findsWidgets);
  });

  testWidgets('deleting asks first, then removes the bill', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await saveGolden(tester, app);
    await pumpApp(tester, app, location: '/history');
    await tester.tap(find.text('The Spice Table'));
    await settle(tester);

    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(find.text('Delete this bill?'), findsOneWidget);

    // Cancelling keeps it.
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('WHO OWES WHAT'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await settle(tester);

    expect(find.text('WHO OWES WHAT'), findsNothing);
    expect(find.text('No bills yet'), findsOneWidget);
  });
}
