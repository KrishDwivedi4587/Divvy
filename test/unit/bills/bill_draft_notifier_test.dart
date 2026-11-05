import 'package:divvy/features/bills/application/bill_draft_notifier.dart';
import 'package:divvy/features/bills/domain/bill_draft.dart';
import 'package:divvy/features/bills/domain/models/bill.dart';
import 'package:divvy/features/bills/domain/models/bill_record.dart';
import 'package:divvy/features/people/domain/saved_person.dart';
import 'package:divvy/features/receipt_scanning/domain/receipt_parser.dart';
import 'package:divvy/features/receipt_scanning/domain/recognized_text.dart';
import 'package:divvy/shared/providers/data_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_container.dart';
import '../../support/builders.dart';
import '../../support/draft_builders.dart';
import '../../support/receipt_fixtures.dart';

void main() {
  late TestApp app;
  late BillDraftNotifier notifier;

  BillDraft draft() => app.container.read(billDraftProvider);

  Future<SavedPerson> addSaved(String name) async {
    final r = await app.container.read(peopleActionsProvider).add(name);
    return (r as PersonSaved).person;
  }

  setUp(() async {
    app = await makeApp();
    notifier = app.container.read(billDraftProvider.notifier);
    await notifier.startNewBill();
  });

  test('a new bill starts with the account holder on it, paying', () {
    expect(draft().participants, hasLength(1));
    expect(draft().participants.single.name, 'You');
    expect(draft().payerId, draft().participants.single.id);
    expect(draft().items, isEmpty);
    expect(draft().billDate, DateTime(now.year, now.month, now.day));
  });

  group('people', () {
    test('adds a saved person once, never twice', () async {
      final aarav = await addSaved('Aarav');
      notifier.addPerson(aarav);
      notifier.addPerson(aarav);
      expect(draft().participants.map((x) => x.name), ['You', 'Aarav']);
      expect(draft().participants.last.personId, aarav.id);
    });

    test('removing someone prunes their allocations and amounts', () async {
      final aarav = await addSaved('Aarav');
      notifier.addPerson(aarav);
      notifier.addItem(
        notifier.newItem(name: 'Tea', quantity: 1, lineTotal: p(2000)),
      );
      final item = draft().items.single;
      final aaravId = draft().participants.last.id;
      notifier.toggleAllocation(item.id, aaravId);
      notifier.setCustomAmount(aaravId, p(500));

      notifier.removeParticipant(aaravId);

      expect(draft().allocations[item.id], isEmpty);
      expect(draft().customAmounts.containsKey(aaravId), isFalse);
    });

    test('removing the payer leaves the bill without one', () {
      final me = draft().participants.single.id;
      notifier.removeParticipant(me);
      expect(draft().payerId, isNull);
      expect(draft().problems(now), contains(BillProblem.noPayer));
    });
  });

  group('items', () {
    test('an item added by hand has its unit price worked out', () {
      notifier.addItem(
        notifier.newItem(name: 'Naan', quantity: 4, lineTotal: p(16000)),
      );
      expect(draft().items.single.unitPrice, p(4000));
      expect(draft().itemsSubtotal, p(16000));
    });

    test('items can be edited and removed', () {
      notifier.addItem(
        notifier.newItem(name: 'Tea', quantity: 1, lineTotal: p(2000)),
      );
      final item = draft().items.single;
      notifier.updateItem(
        DraftItem(
          id: item.id,
          name: 'Masala Tea',
          quantity: 1,
          unitPrice: p(2500),
          lineTotal: p(2500),
        ),
      );
      expect(draft().items.single.name, 'Masala Tea');
      notifier.removeItem(item.id);
      expect(draft().items, isEmpty);
    });
  });

  group('splitting', () {
    Future<void> fillFromReceipt() async {
      final parsed = const ReceiptParser().parse(layout(spiceTable), now: now);
      notifier.applyParsed(parsed);
      notifier.addPerson(await addSaved('Aarav'));
      notifier.addPerson(await addSaved('Priya'));
    }

    test('reading a receipt fills the draft with what was found', () async {
      await fillFromReceipt();
      expect(draft().merchant, 'The Spice Table');
      expect(draft().billDate, DateTime(2026, 11, 14));
      expect(draft().items, hasLength(4));
      expect(draft().items.every((i) => i.source == ItemSource.ocr), isTrue);
      expect(draft().adjustments.map((a) => a.value), [4650, 4883]);
      expect(draft().statedTotal, p(102533));
      expect(draft().ocrText, contains('Paneer Tikka'));
      // Nothing is assigned yet: that is the user's job.
      expect(draft().problems(now), contains(BillProblem.unassignedItems));
    });

    test('assigning everything to everyone makes the bill valid', () async {
      await fillFromReceipt();
      notifier.assignEverythingToEveryone();
      expect(draft().problems(now), isEmpty);
      expect(draft().totalMismatch(now), isNull);
    });

    test('toggling gives an item to a person and takes it back', () async {
      await fillFromReceipt();
      final item = draft().items.first.id;
      final aarav = draft().participants[1].id;
      notifier.toggleAllocation(item, aarav);
      expect(draft().allocations[item], {aarav});
      notifier.toggleAllocation(item, aarav);
      expect(draft().allocations[item], isEmpty);
    });

    test('custom amounts start evenly spread and add up exactly', () async {
      await fillFromReceipt();
      notifier.setSplitMode(SplitMode.custom);
      final sum = draft().customAmounts.values.fold(0, (a, v) => a + v.value);
      expect(sum, draft().itemsSubtotal.value);
      expect(draft().problems(now), isEmpty);
    });

    test(
      'a second receipt replaces the first rather than adding to it',
      () async {
        await fillFromReceipt();
        notifier.applyParsed(
          const ReceiptParser().parse(
            RecognizedText.fromPlainText('Cafe\nTea 20.00\nTotal 20.00'),
            now: now,
          ),
        );
        expect(draft().items.map((i) => i.name), ['Tea']);
        expect(draft().merchant, 'Cafe');
      },
    );

    test('a receipt that finds nothing leaves what was typed alone', () {
      notifier.setMerchant('My dinner');
      notifier.applyParsed(
        const ReceiptParser().parse(RecognizedText.fromPlainText(''), now: now),
      );
      expect(draft().merchant, 'My dinner');
    });
  });
}
