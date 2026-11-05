/// The bill being built in the Create Bill flow, as pure data.
///
/// A draft knows how to turn itself into the calculation engine's [Bill], and
/// how to say what is still wrong with it. It has no Flutter or database
/// imports, so all of this is unit-tested without a screen.
library;

import '../../../core/utils/currency.dart';
import '../../people/domain/person_rules.dart';
import 'engine/money.dart';
import 'engine/settle.dart';
import 'models/bill.dart';
import 'models/bill_record.dart';
import 'models/settlement.dart';

/// A line on the receipt while it is being reviewed.
class DraftItem {
  const DraftItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.source = ItemSource.manual,
    this.ocrConfidence,
    this.rawText,
  });

  final String id;
  final String name;
  final int quantity;
  final Paise unitPrice;
  final Paise lineTotal;
  final ItemSource source;
  final double? ocrConfidence;
  final String? rawText;

  /// Low-confidence recognised lines are highlighted so the user checks them.
  bool get needsReview =>
      source == ItemSource.ocr && (ocrConfidence ?? 1) < 0.7;

  BillItem toBillItem() => BillItem(
    id: id,
    name: name,
    quantity: quantity,
    unitPrice: unitPrice,
    lineTotal: lineTotal,
    source: source,
    ocrConfidence: ocrConfidence,
    rawText: rawText,
  );
}

/// A tax, charge, discount or tip while it is being reviewed.
class DraftAdjustment {
  const DraftAdjustment({
    required this.id,
    required this.label,
    required this.kind,
    required this.mode,
    required this.value,
    this.isNegative = false,
    this.fromReceipt = false,
  });

  final String id;
  final String label;
  final AdjustmentKind kind;
  final AdjustmentMode mode;

  /// Basis points for a percentage, minor units for an amount.
  final int value;
  final bool isNegative;

  /// True when it was read from the receipt rather than typed in.
  final bool fromReceipt;
}

/// Someone on the bill being built.
class DraftParticipant {
  const DraftParticipant({
    required this.id,
    required this.name,
    required this.colorIndex,
    this.personId,
  });

  /// Unique to this bill; becomes the participant id.
  final String id;

  /// The saved person this is, if any.
  final String? personId;
  final String name;
  final int colorIndex;

  String get initials => initialsFor(name);
}

/// Everything that can stop a bill being saved.
enum BillProblem {
  noItems,
  zeroTotal,
  tooFewPeople,
  unassignedItems,
  noPayer,
  customAmountsMismatch,
  notReconciled,
}

class BillDraft {
  const BillDraft({
    required this.billDate,
    required this.currency,
    this.imagePath,
    this.ocrText,
    this.merchant = '',
    this.items = const [],
    this.adjustments = const [],
    this.statedTotal,
    this.participants = const [],
    this.splitMode = SplitMode.byItem,
    this.allocations = const {},
    this.customAmounts = const {},
    this.payerId,
  });

  /// The photo as picked (a temporary file); copied into app storage on save.
  final String? imagePath;
  final String? ocrText;
  final String merchant;
  final DateTime billDate;
  final Currency currency;
  final List<DraftItem> items;
  final List<DraftAdjustment> adjustments;

  /// The total printed on the receipt, if it was read. Used only to warn when
  /// it does not match what the items and charges add up to.
  final Paise? statedTotal;
  final List<DraftParticipant> participants;
  final SplitMode splitMode;

  /// itemId -> participant ids, for [SplitMode.byItem].
  final Map<String, Set<String>> allocations;

  /// participant id -> amount, for [SplitMode.custom].
  final Map<String, Paise> customAmounts;
  final String? payerId;

  /// The title shown in lists: the merchant, or a dated fallback.
  String get title {
    final m = merchant.trim();
    if (m.isNotEmpty) return m;
    return 'Bill ${billDate.day}/${billDate.month}/${billDate.year}';
  }

  Paise get itemsSubtotal => sumPaise(items.map((i) => i.lineTotal));

  /// The sum of the explicit per-person amounts.
  Paise get customTotal => sumPaise(participants.map(_customFor));

  Paise _customFor(DraftParticipant p) => customAmounts[p.id] ?? Paise.zero;

  BillDraft copyWith({
    String? imagePath,
    bool clearImage = false,
    String? ocrText,
    bool clearOcrText = false,
    String? merchant,
    DateTime? billDate,
    Currency? currency,
    List<DraftItem>? items,
    List<DraftAdjustment>? adjustments,
    Paise? statedTotal,
    bool clearStatedTotal = false,
    List<DraftParticipant>? participants,
    SplitMode? splitMode,
    Map<String, Set<String>>? allocations,
    Map<String, Paise>? customAmounts,
    String? payerId,
    bool clearPayer = false,
  }) {
    return BillDraft(
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      ocrText: clearOcrText ? null : (ocrText ?? this.ocrText),
      merchant: merchant ?? this.merchant,
      billDate: billDate ?? this.billDate,
      currency: currency ?? this.currency,
      items: items ?? this.items,
      adjustments: adjustments ?? this.adjustments,
      statedTotal: clearStatedTotal ? null : (statedTotal ?? this.statedTotal),
      participants: participants ?? this.participants,
      splitMode: splitMode ?? this.splitMode,
      allocations: allocations ?? this.allocations,
      customAmounts: customAmounts ?? this.customAmounts,
      payerId: clearPayer ? null : (payerId ?? this.payerId),
    );
  }

  /// Charges are applied in a fixed order, as on an Indian restaurant bill:
  /// discounts, then service and other charges, then tax (which is charged on
  /// the items plus those charges), then tip. Within a kind, entry order holds.
  static int _priority(AdjustmentKind kind) => switch (kind) {
    AdjustmentKind.discount => 0,
    AdjustmentKind.service => 1,
    AdjustmentKind.other => 2,
    AdjustmentKind.tax => 3,
    AdjustmentKind.tip => 4,
  };

  List<Adjustment> _engineAdjustments() {
    final indexed =
        [for (var i = 0; i < adjustments.length; i++) (i, adjustments[i])]
          ..sort((a, b) {
            final byKind = _priority(a.$2.kind).compareTo(_priority(b.$2.kind));
            return byKind != 0 ? byKind : a.$1.compareTo(b.$1);
          });

    return [
      for (var order = 0; order < indexed.length; order++)
        Adjustment(
          id: indexed[order].$2.id,
          label: indexed[order].$2.label,
          kind: indexed[order].$2.kind,
          mode: indexed[order].$2.mode,
          value: indexed[order].$2.value,
          order: order + 1,
          // Tax compounds on whatever came before it; everything else is a
          // percentage of the items alone.
          base: indexed[order].$2.kind == AdjustmentKind.tax
              ? AdjustmentBase.runningTotal
              : AdjustmentBase.itemsSubtotal,
          isNegative: indexed[order].$2.isNegative,
        ),
    ];
  }

  /// The items and who shares each, according to the split mode.
  (List<BillItem>, Map<String, List<String>>) _allocate() {
    final everyone = [for (final p in participants) p.id];
    switch (splitMode) {
      case SplitMode.equal:
        return (
          [for (final i in items) i.toBillItem()],
          {for (final i in items) i.id: everyone},
        );
      case SplitMode.byItem:
        return (
          [for (final i in items) i.toBillItem()],
          {
            for (final i in items) i.id: [...?allocations[i.id]]..sort(),
          },
        );
      case SplitMode.custom:
        // Each person's amount becomes one item that only they share, so the
        // engine needs no special case and charges still apportion fairly.
        return (
          [
            for (final p in participants)
              BillItem(
                id: 'share-${p.id}',
                name: "${p.name}'s share",
                quantity: 1,
                unitPrice: _customFor(p),
                lineTotal: _customFor(p),
              ),
          ],
          {
            for (final p in participants) 'share-${p.id}': [p.id],
          },
        );
    }
  }

  /// The engine's view of this draft.
  Bill toEngineBill({required DateTime createdAt, String id = 'draft'}) {
    final (billItems, assignments) = _allocate();
    return Bill(
      id: id,
      title: title,
      createdAt: createdAt,
      people: [
        for (final p in participants)
          Person(
            id: p.id,
            name: p.name,
            colorIndex: p.colorIndex,
            initials: p.initials,
          ),
      ],
      items: billItems,
      assignments: assignments,
      adjustments: _engineAdjustments(),
      payerId: payerId,
    );
  }

  /// Each person's share, or null while there is nobody to split between.
  Settlement? settle(DateTime now) {
    if (participants.isEmpty) return null;
    return computeSettlement(toEngineBill(createdAt: now));
  }

  /// What is still wrong with this bill. Empty means it can be saved.
  List<BillProblem> problems(DateTime now) {
    final found = <BillProblem>[];

    if (participants.length < 2) found.add(BillProblem.tooFewPeople);
    if (items.isEmpty) {
      found.add(BillProblem.noItems);
    } else if (itemsSubtotal.isZero) {
      found.add(BillProblem.zeroTotal);
    }
    if (payerId == null || !participants.any((p) => p.id == payerId)) {
      found.add(BillProblem.noPayer);
    }

    switch (splitMode) {
      case SplitMode.equal:
        break;
      case SplitMode.byItem:
        final unassigned = items.any(
          (i) => (allocations[i.id] ?? const <String>{}).isEmpty,
        );
        if (unassigned) found.add(BillProblem.unassignedItems);
      case SplitMode.custom:
        if (customTotal != itemsSubtotal) {
          found.add(BillProblem.customAmountsMismatch);
        }
    }

    if (found.isEmpty) {
      final s = settle(now);
      if (s == null || !s.reconciles || !s.unassignedAmount.isZero) {
        found.add(BillProblem.notReconciled);
      }
    }
    return found;
  }

  /// The grand total, items plus every charge, or null if it cannot be worked
  /// out yet.
  Paise? grandTotal(DateTime now) {
    if (participants.isEmpty) return null;
    return settle(now)?.grandTotal;
  }

  /// How far the receipt's printed total is from what Divvy computed. Null when
  /// no total was read or they agree.
  Paise? totalMismatch(DateTime now) {
    final stated = statedTotal;
    final computed = grandTotal(now);
    if (stated == null || computed == null || stated == computed) return null;
    return stated - computed;
  }

  /// Turns a valid draft into the record that is saved. Throws if the draft
  /// still has [problems]: an incomplete bill must never reach storage.
  BillRecord toRecord({
    required String id,
    required DateTime now,
    String? receiptPath,
  }) {
    final remaining = problems(now);
    if (remaining.isNotEmpty) {
      throw StateError(
        'Cannot save a bill that still has problems: $remaining',
      );
    }
    final settlement = settle(now)!;
    final (billItems, assignments) = _allocate();

    return BillRecord(
      id: id,
      title: title,
      merchant: merchant.trim().isEmpty ? null : merchant.trim(),
      billDate: DateTime(billDate.year, billDate.month, billDate.day),
      createdAt: now,
      currency: currency,
      splitMode: splitMode,
      receiptPath: receiptPath,
      ocrText: ocrText,
      payerParticipantId: payerId,
      participants: [
        for (final p in participants)
          BillParticipant(
            id: p.id,
            personId: p.personId,
            name: p.name,
            initials: p.initials,
            colorIndex: p.colorIndex,
            // Whoever paid has nothing to pay back.
            settledAt: p.id == payerId ? now : null,
          ),
      ],
      items: billItems,
      assignments: assignments,
      adjustments: _engineAdjustments(),
      itemsSubtotal: settlement.itemsSubtotal,
      grandTotal: settlement.grandTotal,
      unassignedTotal: settlement.unassignedAmount,
      participantSubtotals: {
        for (final p in settlement.perPerson) p.personId: p.subtotal,
      },
      participantTotals: {
        for (final p in settlement.perPerson) p.personId: p.total,
      },
    );
  }
}
