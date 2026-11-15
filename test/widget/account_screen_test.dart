import 'package:divvy/core/constants/app_info.dart';
import 'package:divvy/core/utils/currency.dart';
import 'package:divvy/data/repositories/sqlite_bill_repository.dart';
import 'package:divvy/shared/providers/app_providers.dart';
import 'package:divvy/shared/providers/data_providers.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_container.dart';
import '../support/detail_helpers.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('shows the profile, preferences and data controls', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await pumpApp(tester, app, location: '/account');

    expect(find.text('Account'), findsWidgets);
    expect(find.text('Tap to change your name'), findsOneWidget);
    expect(find.text('₹ INR'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Version ${AppInfo.appVersion}'), findsOneWidget);
    expect(find.text('Delete all data'), findsOneWidget);
    await screenshot(tester, 'account');
  });

  testWidgets('changes the preferred currency and remembers it', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await pumpApp(tester, app, location: '/account');

    await tester.tap(find.text('Currency'));
    await settle(tester);
    expect(
      find.text('New bills start in this currency. Saved bills keep theirs.'),
      findsOneWidget,
    );
    await tester.tap(find.text(r'$  US dollar'));
    await settle(tester);

    expect(find.text(r'$ USD'), findsOneWidget);
    expect(app.container.read(currencyProvider), Currency.usd);
    // Stored, not just held in memory.
    final stored = await tester.runAsync(
      () => app.container.read(settingsRepositoryProvider).load(),
    );
    expect(stored!.currency, Currency.usd);
  });

  testWidgets('switches to dark appearance', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await pumpApp(tester, app, location: '/account');

    await tester.tap(find.text('Appearance'));
    await settle(tester);
    await tester.tap(find.text('Dark'));
    await settle(tester);

    expect(find.text('Dark'), findsOneWidget);
    final brightness = Theme.of(tester.element(find.text('Account').first))
        .brightness;
    expect(brightness, Brightness.dark);
    await screenshot(tester, 'account_dark');
  });

  testWidgets('changes the account holder name', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await pumpApp(tester, app, location: '/account');

    await tester.tap(find.text('Tap to change your name'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Krish');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    expect(find.text('Krish'), findsWidgets);
    final me = await tester.runAsync(
      () => app.container.read(peopleRepositoryProvider).self(),
    );
    expect(me!.name, 'Krish');
  });

  testWidgets('opens the privacy page, which says what Divvy does', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    await pumpApp(tester, app, location: '/account');

    await tester.tap(find.text('Privacy'));
    await settle(tester);
    expect(find.text('Everything stays on this phone'), findsOneWidget);
    expect(find.textContaining('does not upload'), findsOneWidget);
    await screenshot(tester, 'privacy');
  });

  testWidgets('opens the about page with the version', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await pumpApp(tester, app, location: '/account');

    await tester.tap(find.text('About Divvy'));
    await settle(tester);
    expect(find.text(AppInfo.tagline), findsOneWidget);
    expect(find.text('Open-source licences'), findsOneWidget);
  });

  testWidgets('deleting all data asks first, then erases everything', (
    tester,
  ) async {
    final app = (await tester.runAsync(makeApp))!;
    final aarav = await addSavedPerson(tester, app, 'Aarav');
    await saveSharedBill(tester, app, aarav);
    await pumpApp(tester, app, location: '/account');
    expect(find.text('1 bill'), findsOneWidget);

    await tester.tap(find.text('Delete all data'));
    await settle(tester);
    expect(find.text('Delete all data?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(
      await tester.runAsync(() => SqliteBillRepository(app.db.db).count()),
      1,
    );

    await tester.tap(find.text('Delete all data'));
    await settle(tester);
    await tester.tap(find.text('Delete everything'));
    await settle(tester);

    expect(find.text('All data deleted'), findsOneWidget);
    expect(
      await tester.runAsync(() => SqliteBillRepository(app.db.db).count()),
      0,
    );
    final people = await tester.runAsync(
      () => app.container.read(peopleRepositoryProvider).all(),
    );
    expect(people, hasLength(1)); // only the account holder is left
    expect(find.text('0 bills'), findsOneWidget);
  });

  test('the version shown matches pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final version = line.substring('version:'.length).trim().split('+').first;
    expect(AppInfo.appVersion, version);
  });
}
