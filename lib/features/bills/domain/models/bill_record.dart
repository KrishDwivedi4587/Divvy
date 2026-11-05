/// A saved bill, as stored and as shown in history.
library;

import '../../../../core/utils/currency.dart';
import '../engine/money.dart';
import 'bill.dart';

/// How the people on a bill share its items.
enum SplitMode {
  /// Every item is shared by everyone.
  equal('equal'),

  /// Each item is assigned to the people who had it.
  byItem('by_item'),

  /// Each person is given an explicit amount.
  custom('custom');

  const SplitMode(this.wireName);
  final String wireName;

  static SplitMode fromWire(String value) =>
      values.firstWhere((m) => m.wireName == value, orElse: () => byItem);
}

/// One person's place on one bill.
///
/// This is a snapshot: the name and initials are copied from the saved person
/// when the bill is saved, so renaming or archiving that person later can never
/// change a historical bill. [personId] only links back for balances and the
/// person's history, and is null if the person was removed.
class BillParticipant {
  const BillParticipant({
    required this.id,
    required this.name,
    required this.initials,
    required this.colorIndex,
    this.personId,
    this.settledAt,
  });

  /// Unique to this bill. This is the id the calculation engine sees.
  final String id;
  final String? personId;
  final String name;
  final String initials;
  final int colorIndex;

  /// When this person paid the payer back. Null while they still owe.
  final DateTime? settledAt;

  bool get isSettled => settledAt != null;

  BillParticipant copyWith({DateTime? settledAt, bool clearSettled = false}) {
    return BillParticipant(
      id: id,
      personId: personId,
      name: name,
      initials: initials,
      colorIndex: colorIndex,
      settledAt: clearSettled ? null : (settledAt ?? this.settledAt),
    );
  }

  Person toEnginePerson() =>
      Person(id: id, name: name, colorIndex: colorIndex, initials: initials);
}

/// Everything saved about a bill.
class BillRecord {
  const BillRecord({
    required this.id,
    required this.title,
    required this.billDate,
    required this.createdAt,
    required this.currency,
    required this.splitMode,
    required this.participants,
    required this.items,
    required this.assignments,
    required this.adjustments,
    required this.itemsSubtotal,
    required this.grandTotal,
    required this.unassignedTotal,
    required this.participantSubtotals,
    required this.participantTotals,
    this.merchant,
    this.receiptPath,
    this.ocrText,
    this.payerParticipantId,
  });

  final String id;
  final String title;
  final String? merchant;

  /// The date printed on the receipt (or entered by the user).
  final DateTime billDate;
  final DateTime createdAt;
  final Currency currency;
  final SplitMode splitMode;
  final List<BillParticipant> participants;
  final List<BillItem> items;

  /// itemId -> participant ids.
  final Map<String, List<String>> assignments;
  final List<Adjustment> adjustments;

  /// Relative to the app's documents directory, never absolute: the absolute
  /// path of an iOS app container changes between installs and updates.
  final String? receiptPath;

  /// The raw text recognised from the receipt, kept for correction and debugging.
  final String? ocrText;
  final String? payerParticipantId;

  /// Snapshots taken at save time.
  final Paise itemsSubtotal;
  final Paise grandTotal;
  final Paise unassignedTotal;

  /// participant id -> their item subtotal when the bill was saved.
  final Map<String, Paise> participantSubtotals;

  /// participant id -> the total they owed when the bill was saved.
  final Map<String, Paise> participantTotals;

  BillParticipant? get payer {
    final id = payerParticipantId;
    if (id == null) return null;
    for (final p in participants) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// People who still owe the payer money, i.e. unsettled non-payers.
  List<BillParticipant> get unsettledDebtors => [
    for (final p in participants)
      if (p.id != payerParticipantId && !p.isSettled) p,
  ];

  /// The engine's view of this bill.
  Bill toEngineBill() => Bill(
    id: id,
    title: title,
    createdAt: createdAt,
    people: [for (final p in participants) p.toEnginePerson()],
    items: items,
    assignments: assignments,
    adjustments: adjustments,
    receiptImagePath: receiptPath,
    payerId: payerParticipantId,
  );

  BillRecord copyWith({String? title, List<BillParticipant>? participants}) {
    return BillRecord(
      id: id,
      title: title ?? this.title,
      merchant: merchant,
      billDate: billDate,
      createdAt: createdAt,
      currency: currency,
      splitMode: splitMode,
      participants: participants ?? this.participants,
      items: items,
      assignments: assignments,
      adjustments: adjustments,
      receiptPath: receiptPath,
      ocrText: ocrText,
      payerParticipantId: payerParticipantId,
      itemsSubtotal: itemsSubtotal,
      grandTotal: grandTotal,
      unassignedTotal: unassignedTotal,
      participantSubtotals: participantSubtotals,
      participantTotals: participantTotals,
    );
  }
}

/// The lightweight view of a bill used by lists.
class BillSummary {
  const BillSummary({
    required this.id,
    required this.title,
    required this.billDate,
    required this.currency,
    required this.grandTotal,
    required this.participantNames,
    required this.unsettledCount,
    required this.hasReceipt,
    this.merchant,
  });

  final String id;
  final String title;
  final String? merchant;
  final DateTime billDate;
  final Currency currency;
  final Paise grandTotal;
  final List<String> participantNames;

  /// How many people still owe the payer.
  final int unsettledCount;
  final bool hasReceipt;

  bool get isSettled => unsettledCount == 0;
}

enum ActivityKind { billCreated, paidBack }

/// One entry in the recent-activity feed: a bill was saved, or someone paid the
/// payer back.
class ActivityEvent {
  const ActivityEvent({
    required this.kind,
    required this.billId,
    required this.billTitle,
    required this.currency,
    required this.amount,
    required this.at,
    this.personName,
  });

  final ActivityKind kind;
  final String billId;
  final String billTitle;
  final Currency currency;

  /// The bill's total for [ActivityKind.billCreated]; the amount paid back for
  /// [ActivityKind.paidBack].
  final Paise amount;
  final DateTime at;

  /// Who paid back, for [ActivityKind.paidBack].
  final String? personName;
}
