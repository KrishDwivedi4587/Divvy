/// The calculation engine's input model.
///
/// Pure value types. No Flutter, database or UI imports.
library;

import '../engine/money.dart';

/// Who is splitting the bill.
class Person {
  const Person({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.initials,
  });

  final String id;
  final String name;

  /// Index into the fixed 8-tone avatar palette.
  final int colorIndex;

  /// 1-2 characters, derived from the name at creation.
  final String initials;
}

/// Where a line item came from.
enum ItemSource {
  manual('manual'),
  ocr('ocr');

  const ItemSource(this.wireName);
  final String wireName;

  static ItemSource fromWire(String value) =>
      values.firstWhere((s) => s.wireName == value, orElse: () => manual);
}

class BillItem {
  const BillItem({
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

  /// >= 1. Display only: splitting is always by value.
  final int quantity;
  final Paise unitPrice;

  /// AUTHORITATIVE for all splitting. Equals unitPrice x quantity unless the
  /// receipt says otherwise.
  final Paise lineTotal;
  final ItemSource source;

  /// 0..1; drives the "check this" highlight on the review screen.
  final double? ocrConfidence;

  /// The original OCR text, kept for debugging.
  final String? rawText;
}

enum AdjustmentKind {
  service('service'),
  tax('tax'),
  discount('discount'),
  tip('tip'),
  other('other');

  const AdjustmentKind(this.wireName);
  final String wireName;

  static AdjustmentKind fromWire(String value) =>
      values.firstWhere((k) => k.wireName == value, orElse: () => other);
}

enum AdjustmentMode {
  percent('percent'),
  amount('amount');

  const AdjustmentMode(this.wireName);
  final String wireName;

  static AdjustmentMode fromWire(String value) =>
      values.firstWhere((m) => m.wireName == value, orElse: () => amount);
}

enum AdjustmentBase {
  /// A percentage of the items only.
  itemsSubtotal('itemsSubtotal'),

  /// A percentage of the items plus all preceding adjustments.
  runningTotal('runningTotal');

  const AdjustmentBase(this.wireName);
  final String wireName;

  static AdjustmentBase fromWire(String value) => values.firstWhere(
    (b) => b.wireName == value,
    orElse: () => itemsSubtotal,
  );
}

class Adjustment {
  const Adjustment({
    required this.id,
    required this.label,
    required this.kind,
    required this.mode,
    required this.value,
    required this.order,
    required this.base,
    required this.isNegative,
  });

  final String id;

  /// "GST", "Service Charge", "Loyalty discount".
  final String label;
  final AdjustmentKind kind;
  final AdjustmentMode mode;

  /// percent -> BASIS POINTS (500 = 5.00%). amount -> minor units.
  /// An integer either way. Never a double.
  final int value;

  /// Ascending; defines application order. Service charge before GST.
  final int order;
  final AdjustmentBase base;

  /// True for discounts. The engine apportions |amount| then negates.
  final bool isNegative;
}

class Bill {
  const Bill({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.people,
    required this.items,
    required this.assignments,
    required this.adjustments,
    this.settledAt,
    this.receiptImagePath,
    this.payerId,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime? settledAt;
  final List<Person> people;
  final List<BillItem> items;

  /// itemId -> personIds. An empty list means unassigned.
  final Map<String, List<String>> assignments;
  final List<Adjustment> adjustments;
  final String? receiptImagePath;

  /// Who physically paid the bill.
  final String? payerId;
}
