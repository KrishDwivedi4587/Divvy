/// Turns recognised receipt text into a structured bill.
///
/// ML Kit only recognises text; it does not understand receipts. This is the
/// part that does, as a pure function of [RecognizedText] with no plugin, so it
/// is tested with fixtures instead of a camera.
///
/// It is honest about what it cannot do. It handles the common layouts
/// (name and price on one row, a quantity prefix or column, a block of
/// subtotal/tax/total underneath), and everything it finds is checked against
/// the receipt's own totals. When something does not add up it says so in
/// [ParsedReceipt.warnings] instead of quietly guessing, and it never fills in
/// a value that is not on the receipt.
library;

import '../../../core/utils/currency.dart';
import '../../bills/domain/engine/money.dart';
import '../../bills/domain/engine/percent.dart';
import '../../bills/domain/models/bill.dart';
import 'amount_reading.dart';
import 'parsed_receipt.dart';
import 'receipt_dates.dart';
import 'receipt_keywords.dart';
import 'recognized_text.dart';

class _Row {
  _Row(this.text, this.words, this.kind);

  final String text;
  final List<RowWord> words;
  final RowKind kind;
}

final RegExp _multiplier = RegExp(r'^[xX×*]$');
final RegExp _attachedQty = RegExp(r'^(\d{1,2})[xX×*]$');
final RegExp _suffixQty = RegExp(r'^[xX×*](\d{1,2})$');
final RegExp _smallInt = RegExp(r'^\d{1,2}$');
final RegExp _rate = RegExp(r'(\d+(?:\.\d+)?)\s*%');

bool _usable(RowWord w, bool usesDecimals) {
  final a = w.amount;
  if (a == null) return false;
  return a.hasDecimals || a.hasCurrency || !usesDecimals;
}

/// Title-cases a name only when the receipt printed it in capitals, so
/// "PANEER TIKKA" reads as "Paneer Tikka" but "KFC Bucket" is left alone.
String _prettyCase(String s) {
  final letters = s.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (letters.length < 4 || letters != letters.toUpperCase()) return s;
  return s
      .split(' ')
      .map(
        (w) =>
            w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase(),
      )
      .join(' ');
}

String _cleanName(Iterable<String> words) {
  var s = words.join(' ');
  s = s.replaceAll(RegExp(r'[₹$€£]'), ' ');
  s = s.replaceAll(RegExp(r'^[^\p{L}\p{N}(]+', unicode: true), '');
  s = s.replaceAll(RegExp(r'[^\p{L}\p{N})%]+$', unicode: true), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return _prettyCase(s);
}

int _letters(String s) => RegExp(r'\p{L}', unicode: true).allMatches(s).length;

ParsedItem? _parseItem(_Row row, bool usesDecimals) {
  final words = row.words;
  // The name starts at the first word with real letters. Numbers before it are
  // a quantity; on a receipt that prints whole rupees they would otherwise be
  // mistaken for the price.
  final nameStart = words.indexWhere(
    (w) => w.amount == null && _letters(w.text) >= 2,
  );
  if (nameStart < 0) return null;
  final usable = [
    for (var i = nameStart + 1; i < words.length; i++)
      if (_usable(words[i], usesDecimals)) i,
  ];
  if (usable.isEmpty) return null;

  final amount = words[usable.last].amount!;
  if (amount.negative) return null;

  final label = [for (var i = 0; i < usable.first; i++) words[i].text];
  if (label.isEmpty) return null;

  final rate = usable.length >= 2
      ? words[usable[usable.length - 2]].amount
      : null;
  final total = amount.value.value;

  var qty = 1;
  var confidence = 0.9;

  // A quantity written in front: "2x Naan", "2 x Naan" or "l x Naan" (the
  // letter l is how recognisers often read a 1).
  final first = label.first;
  final attached = _attachedQty.firstMatch(first);
  if (attached != null && label.length > 1) {
    qty = int.parse(attached.group(1)!);
    label.removeAt(0);
  } else if (label.length > 2 && _multiplier.hasMatch(label[1])) {
    if (_smallInt.hasMatch(first)) {
      qty = int.parse(first);
      label.removeRange(0, 2);
    } else if (first == 'l' || first == 'I' || first == '|') {
      label.removeRange(0, 2);
    }
  } else if (label.length > 1 && _smallInt.hasMatch(first)) {
    // A bare number in front: probably a quantity ("2 Masala Dosa"), but it
    // could be part of a name ("7 Up"). Only believe it if it divides the
    // price, or matches rate x quantity.
    final n = int.parse(first);
    final fits =
        n >= 1 &&
        (rate != null ? rate.value.value * n == total : total % n == 0);
    if (fits && n > 1) {
      qty = n;
      label.removeAt(0);
      confidence -= 0.1;
    }
  }

  // A quantity written after the name: "Naan x2".
  if (label.length > 1) {
    final suffix = _suffixQty.firstMatch(label.last);
    if (suffix != null) {
      qty = int.parse(suffix.group(1)!);
      label.removeLast();
    } else if (label.length > 2 &&
        _multiplier.hasMatch(label[label.length - 2]) &&
        _smallInt.hasMatch(label.last)) {
      qty = int.parse(label.last);
      label.removeRange(label.length - 2, label.length);
    }
  }

  // A quantity column: "Butter Naan  4  40.00  160.00".
  if (qty == 1 &&
      rate != null &&
      label.length > 1 &&
      _smallInt.hasMatch(label.last)) {
    final n = int.parse(label.last);
    if (n >= 1 && rate.value.value * n == total) {
      qty = n;
      label.removeLast();
    }
  }
  // A rate beside a total that is a whole multiple of it.
  if (qty == 1 && rate != null && rate.value.value > 0) {
    final r = rate.value.value;
    if (total > r && total % r == 0 && total ~/ r <= 99) {
      qty = total ~/ r;
      confidence -= 0.05;
    }
  }

  final name = _cleanName(label);
  final letters = _letters(name);
  if (letters < 2) return null;

  if (amount.repaired) confidence -= 0.2;
  if (letters < 3) confidence -= 0.25;
  if (letters / name.length < 0.5) confidence -= 0.2;
  if (RegExp(r'\p{L}\p{N}|\p{N}\p{L}', unicode: true).hasMatch(name)) {
    confidence -= 0.1;
  }
  if (usable.length >= 3) confidence -= 0.1;
  if (qty > 1 && total % qty != 0) confidence -= 0.1;
  if (total == 0) confidence = 0.4;

  return ParsedItem(
    name: name,
    quantity: qty,
    unitPrice: Paise(qty > 1 ? total ~/ qty : total),
    lineTotal: Paise(total),
    confidence: confidence.clamp(0.05, 0.98),
    sourceText: row.text,
  );
}

const Set<RowKind> _summaryKinds = {
  RowKind.subtotal,
  RowKind.total,
  RowKind.tax,
  RowKind.service,
  RowKind.discount,
  RowKind.tip,
  RowKind.roundOff,
  RowKind.otherCharge,
};

String _defaultLabel(RowKind kind) => switch (kind) {
  RowKind.tax => 'Tax',
  RowKind.service => 'Service charge',
  RowKind.discount => 'Discount',
  RowKind.tip => 'Tip',
  RowKind.roundOff => 'Round off',
  _ => 'Charge',
};

AdjustmentKind _adjustmentKind(RowKind kind) => switch (kind) {
  RowKind.tax => AdjustmentKind.tax,
  RowKind.service => AdjustmentKind.service,
  RowKind.discount => AdjustmentKind.discount,
  RowKind.tip => AdjustmentKind.tip,
  _ => AdjustmentKind.other,
};

class ReceiptParser {
  const ReceiptParser();

  /// Parses [recognized]. [now] is only used to reject impossible years.
  ParsedReceipt parse(RecognizedText recognized, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final visualRows = groupIntoRows(recognized);
    final rowsText = visualRows.map((r) => r.text).join('\n');

    if (visualRows.isEmpty) {
      return ParsedReceipt(
        items: const [],
        charges: const [],
        rawText: recognized.rawText,
        rowsText: rowsText,
        warnings: const [ParseWarning.noTextFound],
      );
    }

    final analysed = [for (final r in visualRows) (r.text, analyseRow(r.text))];

    // Does this receipt print cents? Decides whether a bare "340" can be a
    // price, or is more likely a table number or a quantity.
    var decimalRows = 0;
    var integerRows = 0;
    for (final (_, words) in analysed) {
      final last = words.where((w) => w.amount != null).lastOrNull;
      if (last == null) continue;
      last.amount!.hasDecimals ? decimalRows++ : integerRows++;
    }
    final usesDecimals =
        decimalRows >= 2 || (decimalRows >= 1 && integerRows == 0);

    final rows = <_Row>[];
    for (final (text, words) in analysed) {
      final lastUsable = words.lastIndexWhere((w) => _usable(w, usesDecimals));
      final label = lastUsable < 0
          ? text
          : words.take(lastUsable).map((w) => w.text).join(' ');
      rows.add(_Row(text, words, classifyLabel(label)));
    }

    final items = <ParsedItem>[];
    final charges = <ParsedCharge>[];
    Paise? subtotal;
    final totals = <({Paise amount, bool strong})>[];
    var inSummary = false;
    Paise? firstSummaryItemsSum;

    for (final row in rows) {
      final isSummaryRow = _summaryKinds.contains(row.kind);
      final hasAmount = row.words.any((w) => w.amount != null);

      if (!inSummary && isSummaryRow && items.isNotEmpty && hasAmount) {
        inSummary = true;
        firstSummaryItemsSum = sumPaise(items.map((i) => i.lineTotal));
      }

      if (!inSummary) {
        if (row.kind == RowKind.item) {
          final item = _parseItem(row, usesDecimals);
          if (item != null) items.add(item);
        }
        continue;
      }

      _readSummaryRow(
        row,
        usesDecimals,
        charges,
        onSubtotal: (a) => subtotal ??= a,
        onTotal: (a, strong) => totals.add((amount: a, strong: strong)),
        itemsSum: firstSummaryItemsSum!,
      );
    }

    // The printed total: a plainly worded one ("Grand Total", "Amount
    // payable") beats a bare "Total", and the last one wins.
    Paise? total;
    if (totals.isNotEmpty) {
      final strong = totals.where((t) => t.strong).toList();
      total = (strong.isNotEmpty ? strong.last : totals.last).amount;
    }

    final warnings = <ParseWarning>[];
    var finalItems = items;
    final chargesSum = sumPaise(charges.map((c) => c.signed));

    // Do the prices look like line totals or unit prices? If the sum only
    // works out as quantity x price, the receipt listed unit prices.
    if (items.any((i) => i.quantity > 1)) {
      final asListed = sumPaise(items.map((i) => i.lineTotal));
      final multiplied = sumPaise(
        items.map((i) => Paise(i.lineTotal.value * i.quantity)),
      );
      final matchesListed = subtotal != null
          ? asListed == subtotal
          : (total != null && asListed + chargesSum == total);
      final matchesMultiplied = subtotal != null
          ? multiplied == subtotal
          : (total != null && multiplied + chargesSum == total);
      if (!matchesListed && matchesMultiplied) {
        finalItems = [
          for (final i in items)
            ParsedItem(
              name: i.name,
              quantity: i.quantity,
              unitPrice: i.lineTotal,
              lineTotal: Paise(i.lineTotal.value * i.quantity),
              confidence: i.confidence,
              sourceText: i.sourceText,
            ),
        ];
        warnings.add(ParseWarning.amountsTreatedAsUnitPrices);
      }
    }

    final itemsSum = sumPaise(finalItems.map((i) => i.lineTotal));

    // Which printed total is the payable one? A plainly worded label ("Grand
    // Total", "Net Payable") outranks a bare "Total". Among candidates of the
    // same rank, one that equals what the items and charges come to beats the
    // rest, since that is far better evidence than position; failing that, the
    // last printed wins. If the receipt printed several different amounts and
    // nothing settles it, the user is asked rather than guessed for.
    List<Paise> distinct(Iterable<Paise> amounts) {
      // Ordered by last appearance, so `.last` is the bottom-most amount.
      final out = <Paise>[];
      for (final a in amounts) {
        out
          ..remove(a)
          ..add(a);
      }
      return out;
    }

    final candidates = distinct(totals.map((t) => t.amount));
    final strong = distinct(totals.where((t) => t.strong).map((t) => t.amount));
    if (candidates.isNotEmpty) {
      final pool = strong.isNotEmpty ? strong : candidates;
      final computedTotal = itemsSum + chargesSum;
      total = finalItems.isNotEmpty && pool.contains(computedTotal)
          ? computedTotal
          : pool.last;
    }
    final reconciled = finalItems.isNotEmpty && total == itemsSum + chargesSum;
    final unsettled = strong.isNotEmpty
        ? strong.length > 1
        : candidates.length > 1;
    if (unsettled && !reconciled) warnings.add(ParseWarning.multipleTotals);

    if (finalItems.isEmpty) warnings.add(ParseWarning.noItemsFound);
    if (subtotal != null && finalItems.isNotEmpty && itemsSum != subtotal) {
      warnings.add(ParseWarning.itemsDoNotMatchSubtotal);
    }
    if (total == null) {
      warnings.add(ParseWarning.totalNotFound);
    } else if (finalItems.isNotEmpty && itemsSum + chargesSum != total) {
      warnings.add(ParseWarning.totalMismatch);
    }

    final dateReading = _findDate(rows, today.year + 1);
    if (dateReading == null) {
      warnings.add(ParseWarning.dateNotFound);
    } else if (dateReading.ambiguous) {
      warnings.add(ParseWarning.dateAmbiguous);
    }

    final merchant = _findMerchant(rows, usesDecimals);
    if (merchant == null) warnings.add(ParseWarning.merchantNotFound);

    return ParsedReceipt(
      merchant: merchant,
      date: dateReading?.date,
      currency: Currency.detect(
        rows
            .where((r) => r.kind == RowKind.total)
            .map((r) => r.text)
            .followedBy([recognized.rawText])
            .join('\n'),
      ),
      items: finalItems,
      charges: charges,
      subtotal: subtotal,
      total: total,
      totalCandidates: candidates,
      rawText: recognized.rawText,
      rowsText: rowsText,
      warnings: warnings,
    );
  }

  void _readSummaryRow(
    _Row row,
    bool usesDecimals,
    List<ParsedCharge> charges, {
    required void Function(Paise) onSubtotal,
    required void Function(Paise, bool strong) onTotal,
    required Paise itemsSum,
  }) {
    switch (row.kind) {
      case RowKind.subtotal || RowKind.total:
        final last = row.words.where((w) => w.amount != null).lastOrNull;
        if (last == null) return;
        if (row.kind == RowKind.subtotal) {
          onSubtotal(last.amount!.value);
        } else {
          onTotal(last.amount!.value, isStrongTotalLabel(row.text));
        }
      case RowKind.tax ||
          RowKind.service ||
          RowKind.discount ||
          RowKind.tip ||
          RowKind.roundOff ||
          RowKind.otherCharge:
        final idx = row.words.lastIndexWhere((w) => _usable(w, usesDecimals));
        if (idx < 0) return;
        final amount = row.words[idx].amount!;
        final label = _cleanName([
          for (var i = 0; i < idx; i++) row.words[i].text,
        ]);

        int? rate;
        final m = _rate.firstMatch(row.text);
        if (m != null) {
          final parsed = parsePercent(m.group(1)!);
          if (parsed is PercentOk) rate = parsed.basisPoints;
        }

        var confidence = 0.9;
        if (amount.repaired) confidence -= 0.2;
        if (rate != null &&
            (row.kind == RowKind.tax || row.kind == RowKind.service)) {
          // A printed rate lets the amount be sanity-checked against the
          // items (or items plus earlier charges, for tax on service).
          final priorCharges = sumPaise(
            charges.where((c) => !c.isNegative).map((c) => c.amount),
          );
          final priorSigned = sumPaise(charges.map((c) => c.signed));
          final bases = [
            itemsSum,
            itemsSum + priorCharges,
            itemsSum + priorSigned,
          ];
          final plausible = bases.any((base) {
            final expected = percentOf(base, rate!).value;
            final diff = (expected - amount.value.value).abs();
            return diff <= 2 || diff * 100 <= expected;
          });
          if (!plausible) confidence -= 0.25;
        }

        charges.add(
          ParsedCharge(
            label: label.isEmpty ? _defaultLabel(row.kind) : label,
            kind: _adjustmentKind(row.kind),
            amount: amount.value,
            isNegative: amount.negative || row.kind == RowKind.discount,
            rateBasisPoints: rate,
            confidence: confidence.clamp(0.05, 0.98),
            sourceText: row.text,
          ),
        );
      default:
        return;
    }
  }

  DateReading? _findDate(List<_Row> rows, int maxYear) {
    final dated = rows.where((r) => r.text.toLowerCase().contains('date'));
    for (final r in [...dated, ...rows]) {
      final found = findDate(r.text, maxYear: maxYear);
      if (found != null) return found;
    }
    return null;
  }

  /// The first row above the items that reads like a name rather than an
  /// address, number or label.
  String? _findMerchant(List<_Row> rows, bool usesDecimals) {
    final firstPriced = rows.indexWhere(
      (r) => r.words.any((w) => _usable(w, usesDecimals)),
    );
    final limit = firstPriced < 0 ? rows.length : firstPriced;

    for (final r in rows.take(limit)) {
      if (r.kind == RowKind.skip || r.kind == RowKind.header) continue;
      if (_summaryKinds.contains(r.kind)) continue;
      if (findDate(r.text, maxYear: 9999) != null) continue;
      final compact = r.text.replaceAll(RegExp(r'\s'), '');
      if (compact.isEmpty) continue;
      final letters = _letters(compact);
      if (letters < 3 || letters / compact.length < 0.6) continue;
      final name = _cleanName(r.text.split(' '));
      if (name.isNotEmpty) return name;
    }
    return null;
  }
}
