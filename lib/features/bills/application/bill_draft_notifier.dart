import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/providers/data_providers.dart';
import '../../people/domain/saved_person.dart';
import '../../receipt_scanning/domain/parsed_receipt.dart';
import '../domain/bill_draft.dart';
import '../domain/engine/money.dart';
import '../domain/engine/split_item.dart';
import '../domain/models/bill.dart';
import '../domain/models/bill_record.dart';

/// The bill being built across the Create Bill screens. Every edit goes
/// through here so the rules (who is on the bill, who has which item, what is
/// valid) live in one place and not in widgets.
class BillDraftNotifier extends Notifier<BillDraft> {
  @override
  BillDraft build() =>
      BillDraft(billDate: _today(), currency: ref.read(currencyProvider));

  DateTime _today() {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  String _id() => ref.read(idGeneratorProvider)();

  /// Starts a fresh bill with the account holder on it, paying.
  Future<void> startNewBill() async {
    final me = await ref.read(selfPersonProvider.future);
    final participant = _participantFor(me);
    state = BillDraft(
      billDate: _today(),
      currency: ref.read(currencyProvider),
      participants: [participant],
      payerId: participant.id,
    );
  }

  DraftParticipant _participantFor(SavedPerson person) => DraftParticipant(
    id: _id(),
    personId: person.id,
    name: person.name,
    colorIndex: person.colorIndex,
  );

  // ---- photo and receipt ------------------------------------------------

  void setPhoto(String path) => state = state.copyWith(imagePath: path);

  void clearPhoto() =>
      state = state.copyWith(clearImage: true, clearOcrText: true);

  /// Fills the draft from a parsed receipt. Only what the parser actually found
  /// is applied; anything it did not find is left as it was.
  void applyParsed(ParsedReceipt r) {
    state = state.copyWith(
      merchant: r.merchant ?? state.merchant,
      billDate: r.date ?? state.billDate,
      currency: r.currency ?? state.currency,
      ocrText: r.rawText,
      items: [
        for (final i in r.items)
          DraftItem(
            id: _id(),
            name: i.name,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
            lineTotal: i.lineTotal,
            source: ItemSource.ocr,
            ocrConfidence: i.confidence,
            rawText: i.sourceText,
          ),
      ],
      adjustments: [
        for (final c in r.charges)
          DraftAdjustment(
            id: _id(),
            label: c.label,
            kind: c.kind,
            mode: AdjustmentMode.amount,
            value: c.amount.value,
            isNegative: c.isNegative,
            fromReceipt: true,
          ),
      ],
      statedTotal: r.total,
      clearStatedTotal: r.total == null,
      allocations: const {},
      customAmounts: const {},
    );
  }

  void setMerchant(String value) => state = state.copyWith(merchant: value);
  void setDate(DateTime value) => state = state.copyWith(billDate: value);
  void setCurrency(Currency value) => state = state.copyWith(currency: value);

  // ---- items and charges -------------------------------------------------

  DraftItem newItem({
    required String name,
    required int quantity,
    required Paise lineTotal,
  }) => DraftItem(
    id: _id(),
    name: name,
    quantity: quantity,
    unitPrice: Paise(
      quantity > 1 ? lineTotal.value ~/ quantity : lineTotal.value,
    ),
    lineTotal: lineTotal,
  );

  void addItem(DraftItem item) =>
      state = state.copyWith(items: [...state.items, item]);

  void updateItem(DraftItem item) => state = state.copyWith(
    items: [for (final i in state.items) i.id == item.id ? item : i],
  );

  void removeItem(String id) {
    state = state.copyWith(
      items: state.items.where((i) => i.id != id).toList(),
      allocations: {...state.allocations}..remove(id),
    );
  }

  String newAdjustmentId() => _id();

  void addAdjustment(DraftAdjustment a) =>
      state = state.copyWith(adjustments: [...state.adjustments, a]);

  void updateAdjustment(DraftAdjustment a) => state = state.copyWith(
    adjustments: [for (final x in state.adjustments) x.id == a.id ? a : x],
  );

  void removeAdjustment(String id) => state = state.copyWith(
    adjustments: state.adjustments.where((a) => a.id != id).toList(),
  );

  // ---- people ------------------------------------------------------------

  /// Adds a saved person to the bill. Adding someone already on it does
  /// nothing, so a person can never appear twice.
  void addPerson(SavedPerson person) {
    if (state.participants.any((p) => p.personId == person.id)) return;
    state = state.copyWith(
      participants: [...state.participants, _participantFor(person)],
    );
  }

  void removeParticipant(String id) {
    state = state.copyWith(
      participants: state.participants.where((p) => p.id != id).toList(),
      allocations: {
        for (final e in state.allocations.entries)
          e.key: e.value.where((p) => p != id).toSet(),
      },
      customAmounts: {...state.customAmounts}..remove(id),
      clearPayer: state.payerId == id,
    );
  }

  void setPayer(String participantId) =>
      state = state.copyWith(payerId: participantId);

  // ---- splitting ---------------------------------------------------------

  void setSplitMode(SplitMode mode) {
    state = state.copyWith(splitMode: mode);
    if (mode == SplitMode.custom && state.customAmounts.isEmpty) {
      distributeCustomEvenly();
    }
  }

  /// Gives a person an item, or takes it away.
  void toggleAllocation(String itemId, String participantId) {
    final current = {...?state.allocations[itemId]};
    if (!current.remove(participantId)) current.add(participantId);
    state = state.copyWith(
      allocations: {...state.allocations, itemId: current},
    );
  }

  void assignItemToEveryone(String itemId) {
    state = state.copyWith(
      allocations: {
        ...state.allocations,
        itemId: {for (final p in state.participants) p.id},
      },
    );
  }

  void clearItemAssignment(String itemId) => state = state.copyWith(
    allocations: {...state.allocations, itemId: <String>{}},
  );

  void assignEverythingToEveryone() {
    state = state.copyWith(
      allocations: {
        for (final i in state.items)
          i.id: {for (final p in state.participants) p.id},
      },
    );
  }

  void setCustomAmount(String participantId, Paise amount) => state = state
      .copyWith(customAmounts: {...state.customAmounts, participantId: amount});

  /// Splits the items subtotal equally across everyone as a starting point for
  /// custom amounts, using the engine's own exact division.
  void distributeCustomEvenly() {
    if (state.participants.isEmpty) return;
    final shares = splitItem(state.itemsSubtotal, [
      for (final p in state.participants) p.id,
    ]);
    state = state.copyWith(customAmounts: shares);
  }
}

final billDraftProvider = NotifierProvider<BillDraftNotifier, BillDraft>(
  BillDraftNotifier.new,
);
