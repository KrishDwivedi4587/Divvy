import 'package:divvy/core/utils/currency.dart';
import 'package:divvy/data/repositories/sqlite_bill_repository.dart';
import 'package:divvy/features/bills/domain/bill_draft.dart';
import 'package:divvy/features/bills/domain/models/bill_record.dart';
import 'package:divvy/features/people/domain/saved_person.dart';
import 'package:divvy/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_container.dart';
import 'draft_builders.dart';

/// Saves the worked-example bill as `bill-1`, optionally with a receipt path.
Future<void> saveGolden(
  WidgetTester tester,
  TestApp app, {
  String? receiptPath,
}) async {
  await tester.runAsync(() async {
    await SqliteBillRepository(app.db.db).save(
      goldenDraft().toRecord(id: 'bill-1', now: now, receiptPath: receiptPath),
    );
  });
}

/// Scrolls the first scrollable until [finder] is on screen.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

/// Saves a 100.00 bill split equally between the account holder and [other],
/// who has not paid back yet. [iPaid] says who paid.
Future<void> saveSharedBill(
  WidgetTester tester,
  TestApp app,
  SavedPerson other, {
  bool iPaid = true,
  String id = 'shared-1',
}) async {
  await tester.runAsync(() async {
    final me = await app.container.read(peopleRepositoryProvider).self();
    final draft = BillDraft(
      billDate: DateTime(2026, 11, 5),
      currency: Currency.inr,
      merchant: 'Dinner with ${other.name}',
      items: [draftItem('item-$id', 'Meal', 10000)],
      participants: [
        participant('me-$id', 'You', personId: me.id),
        participant('them-$id', other.name, personId: other.id),
      ],
      splitMode: SplitMode.equal,
      payerId: iPaid ? 'me-$id' : 'them-$id',
    );
    await SqliteBillRepository(app.db.db).save(recordFrom(draft, id: id));
  });
}

/// Adds a saved person straight through the repository.
Future<SavedPerson> addSavedPerson(
  WidgetTester tester,
  TestApp app,
  String name,
) async {
  return (await tester.runAsync(() async {
    final r = await app.container.read(peopleRepositoryProvider).add(name);
    return (r as PersonSaved).person;
  }))!;
}
