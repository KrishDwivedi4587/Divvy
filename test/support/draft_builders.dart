import 'package:divvy/core/utils/currency.dart';
import 'package:divvy/features/bills/domain/bill_draft.dart';
import 'package:divvy/features/bills/domain/engine/money.dart';
import 'package:divvy/features/bills/domain/models/bill.dart';
import 'package:divvy/features/bills/domain/models/bill_record.dart';

final DateTime now = DateTime.utc(2026, 11, 5, 9, 30);

DraftParticipant participant(String id, String name, {String? personId}) =>
    DraftParticipant(id: id, name: name, colorIndex: 0, personId: personId);

DraftItem draftItem(String id, String name, int total, {int quantity = 1}) =>
    DraftItem(
      id: id,
      name: name,
      quantity: quantity,
      unitPrice: Paise(total ~/ quantity),
      lineTotal: Paise(total),
    );

DraftAdjustment charge(
  String id,
  AdjustmentKind kind,
  int amount, {
  AdjustmentMode mode = AdjustmentMode.amount,
  bool isNegative = false,
}) => DraftAdjustment(
  id: id,
  label: id,
  kind: kind,
  mode: mode,
  value: amount,
  isNegative: isNegative,
);

/// The worked example from the original project: 930.00 of food split three
/// ways, 46.50 service charge and 48.83 GST as printed on the receipt.
///
/// Ids are unique per bill in a real database, so tests that save several
/// bills pass a different [suffix] for each.
BillDraft goldenDraft({String suffix = ''}) {
  String id(String base) => '$base$suffix';
  return BillDraft(
    billDate: DateTime(2026, 11, 14),
    currency: Currency.inr,
    merchant: 'The Spice Table',
    items: [
      draftItem(id('paneer'), 'Paneer Tikka', 34000),
      draftItem(id('dal'), 'Dal Makhani', 28000),
      draftItem(id('coffee'), 'Cold Coffee', 15000),
      draftItem(id('naan'), 'Butter Naan', 16000, quantity: 4),
    ],
    adjustments: [
      charge(id('gst'), AdjustmentKind.tax, 4883),
      charge(id('service'), AdjustmentKind.service, 4650),
    ],
    participants: [
      participant(id('aarav'), 'Aarav'),
      participant(id('priya'), 'Priya'),
      participant(id('zoya'), 'Zoya'),
    ],
    allocations: {
      id('paneer'): {id('aarav'), id('priya')},
      id('dal'): {id('aarav'), id('priya'), id('zoya')},
      id('coffee'): {id('zoya')},
      id('naan'): {id('aarav'), id('priya'), id('zoya')},
    },
    payerId: id('aarav'),
    statedTotal: const Paise(102533),
  );
}

/// A saved record for repository tests.
BillRecord recordFrom(BillDraft draft, {String id = 'bill-1'}) =>
    draft.toRecord(id: id, now: now, receiptPath: null);
