/// Reading money off a receipt.
///
/// Receipt amounts are messier than typed ones: currency prefixes, thousands
/// separators ("1,234.50" or "1,00,000"), European decimal commas ("9,50"),
/// discounts shown as "-50.00", "(50.00)" or "50.00-", a stray tax-code letter
/// after the number, and recognisers that mistake the letter O for a zero.
///
/// Amounts are read as digit strings and handed to the engine's [parseAmount],
/// so no double touches a money value here either.
library;

import '../../bills/domain/engine/money.dart';

/// A number found on a receipt row that could be an amount.
class AmountToken {
  const AmountToken({
    required this.value,
    required this.negative,
    required this.hasDecimals,
    required this.repaired,
    required this.hasCurrency,
  });

  /// Always non-negative; [negative] carries the sign.
  final Paise value;
  final bool negative;

  /// Printed with a decimal part ("340.00"), as opposed to a bare "340".
  final bool hasDecimals;

  /// Letters such as O or l were read as digits to make sense of it.
  final bool repaired;

  /// Preceded by a currency sign such as Rs or the rupee symbol.
  final bool hasCurrency;

  Paise get signed => negative ? -value : value;
}

final RegExp _currencyWord = RegExp(
  r'^(?:₹|rs\.?|inr|\$|€|£)$',
  caseSensitive: false,
);
final RegExp _currencyPrefix = RegExp(
  r'^(?:₹|rs\.?|inr|\$|€|£)',
  caseSensitive: false,
);
final RegExp _dotDecimal = RegExp(r'^(?:\d{1,3}(?:,\d{2,3})+|\d+)\.\d{1,2}$');
final RegExp _commaDecimal = RegExp(r'^(?:\d{1,3}(?:\.\d{3})+|\d+),\d{2}$');
final RegExp _groupedInteger = RegExp(r'^\d{1,3}(?:,\d{2,3})+$');
final RegExp _plainInteger = RegExp(r'^\d+$');
final RegExp _lookalikes = RegExp(r'^[0-9OoIl,.]+$');

String _stripSigns(String s, {required void Function() onNegative}) {
  var out = s;
  var changed = true;
  while (changed) {
    changed = false;
    if (out.startsWith('-') || out.startsWith('−') || out.startsWith('–')) {
      onNegative();
      out = out.substring(1);
      changed = true;
    } else if (out.startsWith('+')) {
      out = out.substring(1);
      changed = true;
    }
    if (out.endsWith('-') || out.endsWith('−')) {
      onNegative();
      out = out.substring(0, out.length - 1);
      changed = true;
    }
  }
  return out.trim();
}

/// Reads one whitespace-free token as an amount, or returns null if it is not
/// one. [afterCurrency] says a currency sign came just before it as its own
/// word ("Rs 1025.33").
AmountToken? readAmount(String raw, {bool afterCurrency = false}) {
  var s = raw.trim();
  if (s.isEmpty) return null;

  var negative = false;
  var hasCurrency = afterCurrency;

  if (s.startsWith('(') && s.endsWith(')') && s.length > 2) {
    negative = true;
    s = s.substring(1, s.length - 1);
  }
  s = _stripSigns(s, onNegative: () => negative = true);
  final prefix = _currencyPrefix.firstMatch(s);
  if (prefix != null) {
    hasCurrency = true;
    s = s.substring(prefix.end);
  }
  s = _stripSigns(s, onNegative: () => negative = true);

  // A lone trailing * or tax-category letter after a decimal amount.
  s = s.replaceFirst(RegExp(r'(?<=\d)[*A-Z]$'), '');
  if (s.isEmpty) return null;

  var repaired = false;
  if (_lookalikes.hasMatch(s) && RegExp(r'[0-9]').hasMatch(s)) {
    final fixed = s
        .replaceAll('O', '0')
        .replaceAll('o', '0')
        .replaceAll('I', '1')
        .replaceAll('l', '1');
    if (fixed != s) {
      repaired = true;
      s = fixed;
    }
  }

  String? canonical;
  var hasDecimals = false;
  if (_dotDecimal.hasMatch(s)) {
    canonical = s.replaceAll(',', '');
    hasDecimals = true;
  } else if (_commaDecimal.hasMatch(s)) {
    canonical = s.replaceAll('.', '').replaceFirst(',', '.');
    hasDecimals = true;
  } else if (_groupedInteger.hasMatch(s)) {
    canonical = s.replaceAll(',', '');
  } else if (_plainInteger.hasMatch(s)) {
    canonical = s;
  }
  if (canonical == null) return null;

  // Long runs of digits are phone numbers, GSTINs and invoice numbers.
  final integerDigits = canonical.split('.').first.length;
  if (integerDigits > (hasDecimals ? 9 : 7)) return null;

  final parsed = parseAmount(canonical);
  if (parsed is! ParseOk) return null;

  return AmountToken(
    value: parsed.value,
    negative: negative,
    hasDecimals: hasDecimals,
    repaired: repaired,
    hasCurrency: hasCurrency,
  );
}

/// One word of a receipt row, with its amount reading if it has one.
class RowWord {
  const RowWord(this.text, this.amount);

  final String text;
  final AmountToken? amount;
}

/// Splits a row into words, reading each as an amount where it can be one. A
/// currency sign standing alone ("Rs", "₹") is folded into the amount after it.
List<RowWord> analyseRow(String row) {
  final words = <RowWord>[];
  var pendingCurrency = false;
  for (final text in row.trim().split(RegExp(r'\s+'))) {
    if (text.isEmpty) continue;
    if (_currencyWord.hasMatch(text)) {
      pendingCurrency = true;
      continue;
    }
    words.add(RowWord(text, readAmount(text, afterCurrency: pendingCurrency)));
    pendingCurrency = false;
  }
  return words;
}
