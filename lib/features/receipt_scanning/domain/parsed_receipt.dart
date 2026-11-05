/// The structured result of parsing a receipt, before the user has reviewed it.
///
/// Every value here is something the parser actually found in the recognised
/// text. Anything it could not find is null or absent, never invented, and the
/// [warnings] say what the user should double-check.
library;

import '../../../core/utils/currency.dart';
import '../../bills/domain/engine/money.dart';
import '../../bills/domain/models/bill.dart';

/// Things the user should look at on the review screen.
enum ParseWarning {
  /// The recogniser returned no text at all.
  noTextFound,

  /// Text was found but no purchased items could be identified in it.
  noItemsFound,

  /// No total was found on the receipt.
  totalNotFound,

  /// The items do not add up to the printed subtotal.
  itemsDoNotMatchSubtotal,

  /// Items plus charges do not add up to the printed total.
  totalMismatch,

  /// The date could be read as day-first or month-first.
  dateAmbiguous,

  /// No date was found.
  dateNotFound,

  /// No merchant name could be picked out.
  merchantNotFound,

  /// The listed prices were unit prices, not line totals, and were multiplied
  /// by the quantity to match the printed subtotal.
  amountsTreatedAsUnitPrices,
}

class ParsedItem {
  const ParsedItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.confidence,
    required this.sourceText,
  });

  final String name;
  final int quantity;
  final Paise unitPrice;
  final Paise lineTotal;

  /// The parser's own confidence, 0..1. Below about 0.7 the review screen
  /// highlights the line for checking.
  final double confidence;

  /// The receipt row this came from, exactly as read.
  final String sourceText;
}

/// A tax, service charge, discount, tip or similar line under the items.
class ParsedCharge {
  const ParsedCharge({
    required this.label,
    required this.kind,
    required this.amount,
    required this.isNegative,
    required this.confidence,
    required this.sourceText,
    this.rateBasisPoints,
  });

  final String label;
  final AdjustmentKind kind;

  /// Always non-negative; [isNegative] carries the sign.
  final Paise amount;
  final bool isNegative;

  /// A rate printed beside the label (for example 5% GST), for display only.
  /// The printed amount, not the rate, is what is used.
  final int? rateBasisPoints;
  final double confidence;
  final String sourceText;

  Paise get signed => isNegative ? -amount : amount;
}

class ParsedReceipt {
  const ParsedReceipt({
    required this.items,
    required this.charges,
    required this.rawText,
    required this.rowsText,
    required this.warnings,
    this.merchant,
    this.date,
    this.currency,
    this.subtotal,
    this.total,
  });

  final String? merchant;
  final DateTime? date;
  final Currency? currency;
  final List<ParsedItem> items;
  final List<ParsedCharge> charges;

  /// The subtotal printed on the receipt, if there was one.
  final Paise? subtotal;

  /// The grand total printed on the receipt, if there was one.
  final Paise? total;

  /// What the recogniser returned, untouched.
  final String rawText;

  /// The same text after lines were put back into visual rows. This is what
  /// the parser actually read, and what the review screen shows for debugging.
  final String rowsText;
  final List<ParseWarning> warnings;

  Paise get itemsSum => sumPaise(items.map((i) => i.lineTotal));

  Paise get chargesSum => sumPaise(charges.map((c) => c.signed));

  /// True when nothing usable was found, so the screen should offer manual
  /// entry rather than an empty review.
  bool get isEmpty =>
      items.isEmpty && charges.isEmpty && total == null && merchant == null;
}
