// Every main screen, at small and large phone widths, an iPad width and with
// large accessibility text, must lay out without overflow or errors. An
// overflow shows up as a framework exception, which fails the test.

import 'package:divvy/features/bills/application/bill_draft_notifier.dart';
import 'package:divvy/features/receipt_scanning/domain/receipt_parser.dart';
import 'package:divvy/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_container.dart';
import '../support/detail_helpers.dart';
import '../support/flow_helpers.dart';
import '../support/draft_builders.dart';
import '../support/pump_app.dart';
import '../support/receipt_fixtures.dart';

const sizes = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'iPhone mini (375x812)': Size(375, 812),
  'iPhone 17 (402x874)': Size(402, 874),
  'iPhone Pro Max (440x956)': Size(440, 956),
  'iPad (768x1024)': Size(768, 1024),
};

const scales = [1.0, 1.5, 2.0];

/// A bill part-way through the Create flow: photographed, read, two people
/// added, everything assigned. Lets every step be laid out with real content.
Future<void> fillDraft(TestApp app) async {
  final notifier = app.container.read(billDraftProvider.notifier);
  await notifier.startNewBill();
  notifier.setPhoto(receiptPhoto);
  notifier.applyParsed(
    const ReceiptParser().parse(layout(spiceTable), now: now),
  );
  final people = await app.container.read(peopleRepositoryProvider).all();
  for (final person in people.where((p) => !p.isSelf)) {
    notifier.addPerson(person);
  }
  notifier.assignEverythingToEveryone();
}

Future<TestApp> populated(WidgetTester tester) async {
  final app = await appWith(tester);
  final aarav = await addSavedPerson(tester, app, 'Aarav Venkatasubramanian');
  await saveGolden(tester, app);
  await saveSharedBill(tester, app, aarav);
  return app;
}

void main() {
  const locations = <String, String>{
    'home': '/',
    'history': '/history',
    'people': '/people',
    'account': '/account',
    'privacy': '/account/privacy',
    'about': '/account/about',
    'bill': '/bills/bill-1',
    'create source': '/create',
    'create preview': '/create/preview',
    'create review': '/create/review',
    'create people': '/create/people',
    'create split': '/create/split',
    'create summary': '/create/summary',
  };

  for (final size in sizes.entries) {
    for (final scale in scales) {
      for (final location in locations.entries) {
        testWidgets('${location.key} fits at ${size.key}, text x$scale', (
          tester,
        ) async {
          final app = await populated(tester);
          // Database work must run on real time, outside the fake-async zone.
          await tester.runAsync(() => fillDraft(app));
          await pumpApp(
            tester,
            app,
            location: location.value,
            size: size.value,
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
