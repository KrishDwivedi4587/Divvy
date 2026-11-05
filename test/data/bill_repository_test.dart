import 'package:divvy/core/utils/currency.dart';
import 'package:divvy/data/database/app_database.dart';
import 'package:divvy/data/repositories/sqlite_bill_repository.dart';
import 'package:divvy/features/bills/domain/engine/settle.dart';
import 'package:divvy/features/bills/domain/models/bill.dart';
import 'package:divvy/features/bills/domain/models/bill_record.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/builders.dart';
import '../support/draft_builders.dart';
import '../support/test_database.dart';

Future<int> rows(AppDatabase app, String table) async =>
    (await app.db.rawQuery('SELECT COUNT(*) AS n FROM $table')).single['n']!
        as int;

void main() {
  late AppDatabase app;
  late SqliteBillRepository bills;

  setUp(() async {
    app = await openTestDatabase();
    bills = SqliteBillRepository(app.db);
  });
  tearDown(() => app.close());

  group('save and read', () {
    test('round-trips every part of a bill', () async {
      final d = goldenDraft().copyWith(ocrText: 'THE SPICE TABLE\n930.00');
      await bills.save(recordFrom(d));

      final back = (await bills.byId('bill-1'))!;
      expect(back.title, 'The Spice Table');
      expect(back.merchant, 'The Spice Table');
      expect(back.billDate, DateTime(2026, 11, 14));
      expect(back.currency, Currency.inr);
      expect(back.splitMode, SplitMode.byItem);
      expect(back.ocrText, contains('THE SPICE TABLE'));
      expect(back.payerParticipantId, 'aarav');
      expect(back.participants.map((x) => x.name), ['Aarav', 'Priya', 'Zoya']);
      expect(back.items.map((x) => x.name), [
        'Paneer Tikka',
        'Dal Makhani',
        'Cold Coffee',
        'Butter Naan',
      ]);
      expect(back.items.last.quantity, 4);
      expect(back.items.last.lineTotal, p(16000));
      expect(back.assignments['paneer'], unorderedEquals(['aarav', 'priya']));
      expect(back.assignments['coffee'], ['zoya']);
      expect(back.adjustments.map((x) => x.kind), [
        AdjustmentKind.service,
        AdjustmentKind.tax,
      ]);
      expect(back.grandTotal, p(102533));
      expect(back.participantTotals['aarav'], p(34915));
    });

    test('the stored bill settles to exactly the snapshotted totals', () async {
      await bills.save(recordFrom(goldenDraft()));
      final back = (await bills.byId('bill-1'))!;

      final s = computeSettlement(back.toEngineBill());
      expect(s.reconciles, isTrue);
      expect(s.grandTotal, back.grandTotal);
      for (final person in s.perPerson) {
        expect(person.total, back.participantTotals[person.personId]);
        expect(person.subtotal, back.participantSubtotals[person.personId]);
      }
    });

    test('returns null for an unknown id', () async {
      expect(await bills.byId('nope'), isNull);
    });

    test('keeps a custom split and its synthetic items', () async {
      final d = goldenDraft().copyWith(
        splitMode: SplitMode.custom,
        allocations: const {},
        customAmounts: {'aarav': p(50000), 'priya': p(30000), 'zoya': p(13000)},
      );
      await bills.save(recordFrom(d));
      final back = (await bills.byId('bill-1'))!;
      expect(back.splitMode, SplitMode.custom);
      expect(back.items.map((x) => x.name), contains("Aarav's share"));
      expect(computeSettlement(back.toEngineBill()).reconciles, isTrue);
    });
  });

  group('atomic save', () {
    test('a failure part-way leaves nothing behind', () async {
      final good = recordFrom(goldenDraft());
      // An allocation to someone who is not on the bill violates a foreign
      // key after the bill, participants and items are already written.
      final bad = BillRecord(
        id: 'bad',
        title: good.title,
        billDate: good.billDate,
        createdAt: good.createdAt,
        currency: good.currency,
        splitMode: good.splitMode,
        participants: good.participants,
        items: good.items,
        assignments: {
          ...good.assignments,
          'paneer': ['aarav', 'not-on-the-bill'],
        },
        adjustments: good.adjustments,
        payerParticipantId: good.payerParticipantId,
        itemsSubtotal: good.itemsSubtotal,
        grandTotal: good.grandTotal,
        unassignedTotal: good.unassignedTotal,
        participantSubtotals: good.participantSubtotals,
        participantTotals: good.participantTotals,
      );

      await expectLater(bills.save(bad), throwsA(anything));

      for (final table in [
        'bills',
        'bill_participants',
        'bill_items',
        'item_allocations',
        'bill_adjustments',
      ]) {
        expect(await rows(app, table), 0, reason: table);
      }
    });

    test('saving the same id twice fails without damaging the first', () async {
      await bills.save(recordFrom(goldenDraft()));
      await expectLater(
        bills.save(recordFrom(goldenDraft())),
        throwsA(anything),
      );

      expect(await bills.count(), 1);
      expect(await rows(app, 'bill_items'), 4);
      expect(await rows(app, 'bill_participants'), 3);
      expect((await bills.byId('bill-1'))!.grandTotal, p(102533));
    });
  });

  group('update', () {
    test('renames a bill', () async {
      await bills.save(recordFrom(goldenDraft()));
      await bills.rename('bill-1', 'Anniversary dinner');
      expect((await bills.byId('bill-1'))!.title, 'Anniversary dinner');
    });

    test('marks a person as paid and back again', () async {
      await bills.save(recordFrom(goldenDraft()));
      Future<bool> zoyaSettled() async =>
          (await bills.byId('bill-1'))!.participants
              .firstWhere((x) => x.id == 'zoya')
              .isSettled;

      expect(await zoyaSettled(), isFalse);
      await bills.setSettled('zoya', settled: true, at: now);
      expect(await zoyaSettled(), isTrue);
      await bills.setSettled('zoya', settled: false, at: now);
      expect(await zoyaSettled(), isFalse);
    });
  });

  group('delete', () {
    test('removes the bill and everything that belongs to it', () async {
      final first = goldenDraft(suffix: '-1')
          .toRecord(id: 'bill-1', now: now, receiptPath: 'receipts/bill-1.jpg');
      await bills.save(first);
      await bills.save(recordFrom(goldenDraft(suffix: '-2'), id: 'bill-2'));

      expect(await bills.delete('bill-1'), 'receipts/bill-1.jpg');

      expect(await bills.byId('bill-1'), isNull);
      expect(await bills.count(), 1);
      // Only bill-2's rows remain.
      expect(await rows(app, 'bill_participants'), 3);
      expect(await rows(app, 'bill_items'), 4);
      expect(await rows(app, 'item_allocations'), 9);
      expect(await rows(app, 'bill_adjustments'), 2);
    });

    test('deleting an unknown bill is harmless', () async {
      expect(await bills.delete('nope'), isNull);
    });
  });
}
